#------------------------------------------------------------------------------
# Copyright (c) 2020, 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# connection.pyx
#   Cython file defining the connection class (embedded in driver.pyx).
#------------------------------------------------------------------------------

ctypedef int (*dpiConnSetTextAttrFunc)(dpiConn*, const char*, uint32_t) nogil

cdef class ConnectionParams:
    cdef:
        bytes dsn
        bytes username
        bytes password
        bytes cclass
        bytes new_password
        bytes edition
        bytes tag

        const char *dsn_ptr
        const char *username_ptr
        const char *password_ptr
        const char *cclass_ptr
        const char *new_password_ptr
        const char *edition_ptr
        const char *tag_ptr

        uint32_t dsn_len
        uint32_t username_len
        uint32_t password_len
        uint32_t cclass_len
        uint32_t new_password_len
        uint32_t edition_len
        uint32_t tag_len

        uint32_t num_app_context
        list app_context_bytes
        dpiAppContext *app_context

        uint32_t num_sharding_key_columns
        dpiShardingKeyColumn *sharding_key_columns
        uint32_t num_super_sharding_key_columns
        dpiShardingKeyColumn *super_sharding_key_columns

    def __dealloc__(self):
        if self.app_context is not NULL:
            cpython.PyMem_Free(self.app_context)
        if self.sharding_key_columns is not NULL:
            cpython.PyMem_Free(self.sharding_key_columns)
        if self.super_sharding_key_columns is not NULL:
            cpython.PyMem_Free(self.super_sharding_key_columns)

    cdef int _process_context_str(self, str value, const char **ptr,
                                  uint32_t *length) except -1:
        cdef bytes temp
        temp = value.encode()
        self.app_context_bytes.append(temp)
        ptr[0] = temp
        length[0] = <uint32_t> len(temp)

    cdef process_appcontext(self, list entries):
        cdef:
            object namespace, name, value
            dpiAppContext *entry
            ssize_t num_bytes
            bytes temp
            uint32_t i
        self.app_context_bytes = []
        self.num_app_context = <uint32_t> len(entries)
        num_bytes = self.num_app_context * sizeof(dpiAppContext)
        self.app_context = <dpiAppContext*> cpython.PyMem_Malloc(num_bytes)
        for i in range(self.num_app_context):
            if not isinstance(entries[i], tuple) or len(entries[i]) != 3:
                raise TypeError("appcontext should be a list of 3-tuples")
            namespace, name, value = entries[i]
            entry = &self.app_context[i]
            self._process_context_str(namespace, &entry.namespaceName,
                                      &entry.namespaceNameLength)
            self._process_context_str(name, &entry.name, &entry.nameLength)
            self._process_context_str(value, &entry.value, &entry.valueLength)


cdef class ThickConnImpl(BaseConnImpl):
    cdef:
        dpiConn *_handle
        bint _is_external
        public str tag

    def __dealloc__(self):
        if self._handle != NULL:
            dpiConn_release(self._handle)

    def _connect(self, str password=None, uint32_t mode=0, uint64_t handle=0,
                 ThickPoolImpl pool_impl=None, bint threaded=False, bint
                 events=False, str cclass=None, uint32_t purity=0,
                 str newpassword=None, str edition=None, list appcontext=None,
                 str tag=None, bint matchanytag=False, list shardingkey=None,
                 list supershardingkey=None):
        cdef:
            dpiCommonCreateParams common_params
            dpiConnCreateParams conn_params
            ConnectionParams params
            int status

        # ensure that the Oracle Client library is initialized
        if driver_context == NULL:
            init_oracle_client()

        # set up connection parameters
        params = ConnectionParams()
        if self.username is not None:
            params.username = self.username.encode()
            params.username_ptr = params.username
            params.username_len = <uint32_t> len(params.username)
        if password is not None:
            params.password = password.encode()
            params.password_ptr = params.password
            params.password_len = <uint32_t> len(params.password)
        if self.dsn is not None:
            params.dsn = self.dsn.encode()
            params.dsn_ptr = params.dsn
            params.dsn_len = <uint32_t> len(params.dsn)
        if cclass is not None:
            params.cclass = cclass.encode()
            params.cclass_ptr = params.cclass
            params.cclass_len = <uint32_t> len(params.cclass)
        if newpassword is not None:
            params.new_password = newpassword.decode()
            params.new_password_ptr = params.new_password
            params.new_password_len = <uint32_t> len(params.new_password)
        if edition is not None:
            params.edition = edition.encode()
            params.edition_ptr = params.edition
            params.edition_len = <uint32_t> len(params.edition)
        if tag is not None:
            params.tag = tag.encode()
            params.tag_ptr = params.tag
            params.tag_len = <uint32_t> len(params.tag)
        if appcontext:
            params.process_appcontext(appcontext)

        # set up common creation parameters
        if dpiContext_initCommonCreateParams(driver_context,
                                             &common_params) < 0:
            _raise_from_odpi()
        if threaded:
            common_params.createMode |= DPI_MODE_CREATE_THREADED
        if events:
            common_params.createMode |= DPI_MODE_CREATE_EVENTS
        if edition is not None:
            common_params.edition = params.edition_ptr
            common_params.editionLength = params.edition_len

        # set up connection specific creation parameters
        if dpiContext_initConnCreateParams(driver_context, &conn_params) < 0:
            _raise_from_odpi()
        if params.username_len == 0 and params.password_len == 0:
            conn_params.externalAuth = 1
        if cclass is not None:
            conn_params.connectionClass = params.cclass_ptr
            conn_params.connectionClassLength = params.cclass_len
        if newpassword is not None:
            conn_params.newPassword = params.new_password_ptr
            conn_params.newPasswordLength = params.new_password_len
        if appcontext:
            conn_params.appContext = params.app_context
            conn_params.numAppContext = params.num_app_context
        if tag is not None:
            conn_params.tag = params.tag_ptr
            conn_params.tagLength = params.tag_len
        if handle:
            conn_params.externalHandle = <void*> (<uint64_t> handle)
            self._is_external = True
        if pool_impl is not None:
            conn_params.pool = pool_impl._handle
        conn_params.matchAnyTag = matchanytag
        conn_params.purity = purity

        # perform connection
        with nogil:
            status = dpiConn_create(driver_context, params.username_ptr,
                                    params.username_len, params.password_ptr,
                                    params.password_len, params.dsn_ptr,
                                    params.dsn_len, &common_params,
                                    &conn_params, &self._handle)
        if status < 0:
            _raise_from_odpi()

        # set tag property, if applicable
        if conn_params.outTagLength > 0:
            self.tag = conn_params.outTag[:conn_params.outTagLength].decode()

    cdef BaseQueue _create_queue(self):
        return Queue.__new__(Queue)

    cdef int _set_text_attr(self, dpiConnSetTextAttrFunc func,
                            str value) except -1:
        cdef:
            uint32_t value_length
            const char *value_ptr
            bytes value_bytes
        value_bytes = value.encode()
        value_ptr = value_bytes
        value_length = len(value_bytes)
        if func(self._handle, value_ptr, value_length) < 0:
            _raise_from_odpi()

    def begin(self, long format_id, str transaction_id, str branch_id):
        cdef:
            bytes transaction_id_bytes, branch_id_bytes
            uint32_t transaction_id_len, branch_id_len
            const char *transaction_id_ptr
            const char *branch_id_ptr
            int status
        transaction_id_bytes = transaction_id.encode()
        transaction_id_ptr = transaction_id_bytes
        transaction_id_len = <uint32_t> len(transaction_id_bytes)
        branch_id_bytes = branch_id.encode()
        branch_id_ptr = branch_id_bytes
        branch_id_len = <uint32_t> len(branch_id_bytes)
        with nogil:
            status = dpiConn_beginDistribTrans(self._handle, format_id,
                                               transaction_id_ptr,
                                               transaction_id_len,
                                               branch_id_ptr, branch_id_len)
        if status < 0:
            _raise_from_odpi()

    def cancel(self):
        cdef int status
        with nogil:
            status = dpiConn_breakExecution(self._handle)
        if status < 0:
            _raise_from_odpi()

    def change_password(self, str old_password, str new_password):
        cdef:
            bytes username_bytes, old_password_bytes, new_password_bytes
            uint32_t username_len = 0, old_password_len = 0
            const char *old_password_ptr = NULL
            const char *new_password_ptr = NULL
            const char *username_ptr = NULL
            uint32_t new_password_len = 0
            int status
        if self.username is not None:
            username_bytes = self.username.encode()
            username_ptr = username_bytes
            username_len = <uint32_t> len(username_bytes)
        old_password_bytes = old_password.encode()
        old_password_ptr = old_password_bytes
        old_password_len = <uint32_t> len(old_password_bytes)
        new_password_bytes = new_password.encode()
        new_password_ptr = new_password_bytes
        new_password_len = <uint32_t> len(new_password_bytes)
        with nogil:
            status = dpiConn_changePassword(self._handle, username_ptr,
                                            username_len, old_password_ptr,
                                            old_password_len, new_password_ptr,
                                            new_password_len)
        if status < 0:
            _raise_from_odpi()

    def close(self, bint in_del=False):
        cdef:
            uint32_t mode = DPI_MODE_CONN_CLOSE_DEFAULT
            const char *tag_ptr = NULL
            uint32_t tag_length = 0
            bytes tag_bytes
            int status
        if in_del and self._is_external:
            return 0
        if self.tag is not None:
            mode = DPI_MODE_CONN_CLOSE_RETAG
            tag_bytes = self.tag.encode()
            tag_ptr = tag_bytes
            tag_length = <uint32_t> len(tag_bytes)
        with nogil:
            status = dpiConn_close(self._handle, mode, tag_ptr, tag_length)
            if status == DPI_SUCCESS:
                dpiConn_release(self._handle)
                self._handle = NULL
        if status < 0 and not in_del:
            _raise_from_odpi()

    def commit(self):
        cdef int status
        with nogil:
            status = dpiConn_commit(self._handle)
        if status < 0:
            _raise_from_odpi()

    def create_cursor_impl(self):
        return ThickCursorImpl.__new__(ThickCursorImpl, self)

    def create_msg_props(self):
        cdef MsgProps props = MsgProps.__new__(MsgProps)
        if dpiConn_newMsgProps(self._handle, &props._handle) < 0:
            _raise_from_odpi()
        return props

    def create_subscription(self, connection, callback, namespace, name,
                            protocol, ip_address, port, timeout, operations,
                            qos, grouping_class, grouping_value, grouping_type,
                            client_initiated):
        cdef Subscription subscr = Subscription.__new__(Subscription)
        subscr.connection = connection
        subscr.callback = callback
        subscr.namespace = namespace
        subscr.name = name
        subscr.protocol = protocol
        subscr.ip_address = ip_address
        subscr.port = port
        subscr.timeout = timeout
        subscr.operations = operations
        subscr.qos = qos
        subscr.grouping_class = grouping_class
        subscr.grouping_value = grouping_value
        subscr.grouping_type = grouping_type
        subscr.client_initiated = client_initiated
        return subscr

    def create_temp_lob_impl(self, DbType dbtype):
        return ThickLobImpl._create(self, dbtype, NULL)

    def get_call_timeout(self):
        cdef uint32_t value
        if dpiConn_getCallTimeout(self._handle, &value) < 0:
            _raise_from_odpi()
        return value

    def get_current_schema(self):
        cdef:
            uint32_t value_length
            const char *value
        if dpiConn_getCurrentSchema(self._handle, &value, &value_length) < 0:
            _raise_from_odpi()
        if value is not NULL:
            return value[:value_length].decode()

    def get_edition(self):
        cdef:
            uint32_t value_length
            const char *value
        if dpiConn_getEdition(self._handle, &value, &value_length) < 0:
            _raise_from_odpi()
        if value is not NULL:
            return value[:value_length].decode()

    def get_external_name(self):
        cdef:
            uint32_t value_length
            const char *value
        if dpiConn_getExternalName(self._handle, &value, &value_length) < 0:
            _raise_from_odpi()
        if value is not NULL:
            return value[:value_length].decode()

    def get_handle(self):
        cdef void* handle
        if dpiConn_getHandle(self._handle, &handle) < 0:
            _raise_from_odpi()
        return <uint64_t> handle

    def get_internal_name(self):
        cdef:
            uint32_t value_length
            const char *value
        if dpiConn_getInternalName(self._handle, &value, &value_length) < 0:
            _raise_from_odpi()
        if value is not NULL:
            return value[:value_length].decode()

    def get_ltxid(self):
        cdef:
            uint32_t value_length
            const char *value
        if dpiConn_getLTXID(self._handle, &value, &value_length) < 0:
            _raise_from_odpi()
        return value[:value_length]

    def get_soda_database(self, conn):
        cdef SodaDatabase db = SodaDatabase.__new__(SodaDatabase)
        db._conn = conn
        if dpiConn_getSodaDb(self._handle, &db._handle) < 0:
            _raise_from_odpi()
        return db

    def get_stmt_cache_size(self):
        cdef uint32_t value
        if dpiConn_getStmtCacheSize(self._handle, &value) < 0:
            _raise_from_odpi()
        return value

    def get_type(self, object conn, str name):
        cdef:
            BaseDbObjectType objtype
            dpiObjectType *handle
            const char *name_ptr
            uint32_t name_len
            bytes name_bytes
            int status
        name_bytes = name.encode()
        name_ptr = name_bytes
        name_len = <uint32_t> len(name_bytes)
        with nogil:
            status = dpiConn_getObjectType(self._handle, name_ptr, name_len,
                                           &handle)
        if status < 0:
            _raise_from_odpi()
        objtype = DbObjectType._new_type(conn, handle)
        dpiObjectType_release(handle)
        return objtype

    def get_version(self):
        cdef:
            dpiVersionInfo version_info
            int status
        with nogil:
            status = dpiConn_getServerVersion(self._handle, NULL, NULL,
                                              &version_info)
        if status < 0:
            _raise_from_odpi()
        return "%d.%d.%d.%d.%d" % \
                (version_info.versionNum, version_info.releaseNum,
                 version_info.updateNum, version_info.portReleaseNum,
                 version_info.portUpdateNum)

    def set_action(self, str value):
        self._set_text_attr(dpiConn_setAction, value)

    def set_call_timeout(self, uint32_t value):
        if dpiConn_setCallTimeout(self._handle, value) < 0:
            _raise_from_odpi()

    def set_client_identifier(self, str value):
        self._set_text_attr(dpiConn_setClientIdentifier, value)

    def set_client_info(self, str value):
        self._set_text_attr(dpiConn_setClientInfo, value)

    def set_current_schema(self, str value):
        self._set_text_attr(dpiConn_setCurrentSchema, value)

    def set_dbop(self, str value):
        self._set_text_attr(dpiConn_setDbOp, value)

    def ping(self):
        cdef int status
        with nogil:
            status = dpiConn_ping(self._handle)
        if status < 0:
            _raise_from_odpi()

    def prepare(self):
        cdef:
            bint commit_needed
            int status
        with nogil:
            status = dpiConn_prepareDistribTrans(self._handle, &commit_needed)
        if status < 0:
            _raise_from_odpi()
        return commit_needed

    def rollback(self):
        cdef int status
        with nogil:
            status = dpiConn_rollback(self._handle)
        if status < 0:
            _raise_from_odpi()

    def set_external_name(self, str value):
        self._set_text_attr(dpiConn_setExternalName, value)

    def set_internal_name(self, str value):
        self._set_text_attr(dpiConn_setInternalName, value)

    def set_module(self, str value):
        self._set_text_attr(dpiConn_setModule, value)

    def set_stmt_cache_size(self, uint32_t value):
        if dpiConn_setStmtCacheSize(self._handle, value) < 0:
            _raise_from_odpi()
