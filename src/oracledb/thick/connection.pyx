#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
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


cdef class Connection(BaseConnection):
    cdef:
        dpiConn *_handle
        public str tag

    def __dealloc__(self):
        if self._handle != NULL:
            dpiConn_release(self._handle)


    cdef int _begin(self, long format_id, str transaction_id,
                    str branch_id) except -1:
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

    cdef int _cancel(self) except -1:
        cdef int status
        with nogil:
            status = dpiConn_breakExecution(self._handle)
        if status < 0:
            _raise_from_odpi()

    cdef int _change_password(self, str old_password,
                              str new_password) except -1:
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

    cdef int _close(self) except -1:
        cdef:
            uint32_t mode = DPI_MODE_CONN_CLOSE_DEFAULT
            const char *tag_ptr = NULL
            uint32_t tag_length = 0
            bytes tag_bytes
            int status
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
        if status < 0:
            _raise_from_odpi()

    cdef int _commit(self) except -1:
        cdef int status
        with nogil:
            status = dpiConn_commit(self._handle)
        if status < 0:
            _raise_from_odpi()

    def _connect(self, password, mode, handle, pool, threaded, events, cclass,
                 purity, newpassword, edition, appcontext, tag, matchanytag,
                 shardingkey, supershardingkey):
        cdef:
            dpiCommonCreateParams common_params
            dpiConnCreateParams conn_params
            ConnectionParams params
            Pool thick_pool
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
            params.cclass = cclass.decode()
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
        if edition:
            common_params.edition = params.edition_ptr
            common_params.editionLength = params.edition_len

        # set up connection specific creation parameters
        if dpiContext_initConnCreateParams(driver_context, &conn_params) < 0:
            _raise_from_odpi()
        if params.username_len == 0 and params.password_len == 0:
            conn_params.externalAuth = 1
        if cclass:
            conn_params.connectionClass = params.cclass_ptr
            conn_params.connectionClassLength = params.cclass_ptr_len
        if newpassword:
            conn_params.newPassword = params.new_password_ptr
            conn_params.newPasswordLength = params.new_password_len
        if appcontext:
            conn_params.appContext = params.app_context
            conn_params.numAppContext = params.num_app_context
        if tag:
            conn_params.tag = params.tag_ptr
            conn_params.tagLength = params.tag_len
        if handle:
            conn_params.externalHandle = <void*> (<uint64_t> handle)
        if pool is not None:
            thick_pool = pool
            conn_params.pool = thick_pool._handle
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
        self._is_connected = True

        # set tag property, if applicable
        if conn_params.outTagLength > 0:
            self.tag = conn_params.outTag[:conn_params.outTagLength].decode()

    cdef BaseMsgProps _create_msg_props(self):
        cdef MsgProps props = MsgProps.__new__(MsgProps)
        if dpiConn_newMsgProps(self._handle, &props._handle) < 0:
            _raise_from_odpi()
        return props

    cdef BaseQueue _create_queue(self):
        return Queue.__new__(Queue)

    cdef BaseSubscription _create_subscription(self):
        return Subscription.__new__(Subscription)

    cdef BaseLob _create_temp_lob(self, DbType dbtype):
        cdef:
            dpiLob *handle
            int status
        with nogil:
            status = dpiConn_newTempLob(self._handle, dbtype.num, &handle)
        if status < 0:
            _raise_from_odpi()
        try:
            return Lob._new_lob(self, dbtype, handle)
        finally:
            dpiLob_release(handle)

    cdef str _get_current_schema(self):
        cdef:
            uint32_t value_length
            const char *value
        if dpiConn_getCurrentSchema(self._handle, &value, &value_length) < 0:
            _raise_from_odpi()
        if value is not NULL:
            return value[:value_length].decode()

    cdef str _get_edition(self):
        cdef:
            uint32_t value_length
            const char *value
        if dpiConn_getEdition(self._handle, &value, &value_length) < 0:
            _raise_from_odpi()
        if value is not NULL:
            return value[:value_length].decode()

    cdef str _get_external_name(self):
        cdef:
            uint32_t value_length
            const char *value
        if dpiConn_getExternalName(self._handle, &value, &value_length) < 0:
            _raise_from_odpi()
        if value is not NULL:
            return value[:value_length].decode()

    cdef str _get_internal_name(self):
        cdef:
            uint32_t value_length
            const char *value
        if dpiConn_getInternalName(self._handle, &value, &value_length) < 0:
            _raise_from_odpi()
        if value is not NULL:
            return value[:value_length].decode()

    cdef bytes _get_ltxid(self):
        cdef:
            uint32_t value_length
            const char *value
        if dpiConn_getLTXID(self._handle, &value, &value_length) < 0:
            _raise_from_odpi()
        return value[:value_length]

    cdef BaseSodaDatabase _get_soda_database(self):
        cdef SodaDatabase db = SodaDatabase.__new__(SodaDatabase)
        db._connection = self
        if dpiConn_getSodaDb(self._handle, &db._handle) < 0:
            _raise_from_odpi()
        return db

    cdef uint32_t _get_stmtcachesize(self) except *:
        cdef uint32_t size
        if dpiConn_getStmtCacheSize(self._handle, &size) < 0:
            _raise_from_odpi()
        return size

    cdef BaseDbObjectType _get_type(self, str name):
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
        objtype = DbObjectType._new_type(self, handle)
        dpiObjectType_release(handle)
        return objtype

    cdef str _get_version(self):
        cdef:
            dpiVersionInfo version_info
            int status
        self._verify_connected()
        with nogil:
            status = dpiConn_getServerVersion(self._handle, NULL, NULL,
                                              &version_info)
        if status < 0:
            _raise_from_odpi()
        return "%d.%d.%d.%d.%d" % \
                (version_info.versionNum, version_info.releaseNum,
                 version_info.updateNum, version_info.portReleaseNum,
                 version_info.portUpdateNum)

    cdef BaseCursor _create_cursor(self):
        return Cursor.__new__(Cursor, self)

    cdef int _ping(self) except -1:
        cdef int status
        with nogil:
            status = dpiConn_ping(self._handle)
        if status < 0:
            _raise_from_odpi()

    cdef bint _prepare(self) except *:
        cdef int commit_needed, status
        with nogil:
            status = dpiConn_prepareDistribTrans(self._handle, &commit_needed)
        if status < 0:
            _raise_from_odpi()
        return commit_needed

    cdef int _rollback(self) except -1:
        cdef int status
        with nogil:
            status = dpiConn_rollback(self._handle)
        if status < 0:
            _raise_from_odpi()

    cdef int _set_action(self, str value) except -1:
        self._set_text_attr(dpiConn_setAction, value)

    cdef int _set_client_identifier(self, str value) except -1:
        self._set_text_attr(dpiConn_setClientIdentifier, value)

    cdef int _set_client_info(self, str value) except -1:
        self._set_text_attr(dpiConn_setClientInfo, value)

    cdef int _set_current_schema(self, str value) except -1:
        self._set_text_attr(dpiConn_setCurrentSchema, value)

    cdef int _set_dbop(self, str value) except -1:
        self._set_text_attr(dpiConn_setDbOp, value)

    cdef int _set_external_name(self, str value) except -1:
        self._set_text_attr(dpiConn_setExternalName, value)

    cdef int _set_internal_name(self, str value) except -1:
        self._set_text_attr(dpiConn_setInternalName, value)

    cdef int _set_module(self, str value) except -1:
        self._set_text_attr(dpiConn_setModule, value)

    cdef int _set_stmtcachesize(self, uint32_t value) except -1:
        if dpiConn_setStmtCacheSize(self._handle, value) < 0:
            _raise_from_odpi()

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

    @property
    def handle(self):
        cdef void* handle
        self._verify_connected()
        if dpiConn_getHandle(self._handle, &handle) < 0:
            _raise_from_odpi()
        return <uint64_t> handle
