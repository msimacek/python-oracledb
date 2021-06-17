#------------------------------------------------------------------------------
# Copyright (c) 2020, 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class ThinConnImpl(BaseConnImpl):

    cdef:
        object _statement_cache
        uint32_t _statement_cache_size
        object _statement_cache_lock
        Protocol _protocol
        str _server_version
        uint32_t _session_id
        uint32_t _serial_num
        str _action
        bint _action_modified
        str _dbop
        bint _dbop_modified
        str _client_info
        bint _client_info_modified
        str _client_identifier
        bint _client_identifier_modified
        str _module
        bint _module_modified
        ThinPoolImpl _pool
        bytes _ltxid
        str _current_schema
        bint _current_schema_modified
        str _edition
        str _internal_name
        str _external_name
        array.array _cursors_to_close
        ssize_t _num_cursors_to_close
        bint _drcp_enabled

    cdef int _add_cursor_to_close(self, Statement stmt) except -1:
        if self._num_cursors_to_close == TNS_MAX_CURSORS_TO_CLOSE:
            raise Exception("too many cursors to close!")
        self._cursors_to_close[self._num_cursors_to_close] = stmt._cursor_id
        self._num_cursors_to_close += 1

    cdef int _adjust_statement_cache(self) except -1:
        cdef Statement stmt
        while len(self._statement_cache) > self._statement_cache_size:
            stmt = <Statement> self._statement_cache.popitem(last=False)
            if stmt._in_use:
                stmt._return_to_cache = False
            elif stmt._cursor_id != 0:
                self._add_cursor_to_close(stmt)

    cdef Statement _get_statement(self, str sql):
        cdef Statement statement
        with self._statement_cache_lock:
            statement = self._statement_cache.get(sql)
            if statement is None:
                statement = Statement()
                statement._prepare(sql)
                if len(self._statement_cache) < self._statement_cache_size:
                    self._statement_cache[sql] = statement
                    statement._return_to_cache = True
            elif statement._in_use:
                statement = statement.copy()
            else:
                self._statement_cache.move_to_end(sql)
            statement._in_use = True
            return statement

    cdef int _return_statement(self, Statement statement) except -1:
        with self._statement_cache_lock:
            if statement._return_to_cache:
                statement._in_use = False
                self._statement_cache.move_to_end(statement._sql)
                self._adjust_statement_cache()
            elif statement._cursor_id != 0:
                self._add_cursor_to_close(statement)

    def cancel(self):
        self._protocol._break_external()

    def close(self, bint in_del=False):
        if self._pool is not None:
            self._pool._free_busy_connection(self)
        else:
            try:
                self._protocol._close(self._drcp_enabled)
            except ssl.SSLError:
                pass

    def commit(self):
        self._protocol._commit()

    def connect(self, params, uint32_t stmtcachesize, uint32_t auth_mode,
                str cclass=None, uint8_t purity=0):
        sock = socket.create_connection((params.host, params.port))
        if params.secure_transport:
            wallet_file_name = params.get_wallet_file_name()
            ssl_context = ssl.create_default_context(cafile=wallet_file_name)
            ssl_context.load_cert_chain(certfile=wallet_file_name)
            ssl_context.check_hostname = False
            sock = ssl_context.wrap_socket(sock)
        self._protocol = Protocol(sock)
        redirect_data = self._protocol._connect(self, params.secure_transport,
                                                params.get_connect_data(),
                                                params.password, auth_mode,
                                                params.can_use_oob(), cclass,
                                                purity)
        if redirect_data is None:
            self._statement_cache = collections.OrderedDict()
            self._statement_cache_size = stmtcachesize
            self._statement_cache_lock = threading.Lock()
            self._cursors_to_close = array.array('I')
            array.resize(self._cursors_to_close, TNS_MAX_CURSORS_TO_CLOSE)
            self._drcp_enabled = params.enable_drcp
        return redirect_data

    def create_cursor_impl(self):
        return ThinCursorImpl.__new__(ThinCursorImpl, self)

    def create_temp_lob_impl(self, DbType dbtype):
        return ThinLobImpl._create(self, dbtype)

    def get_current_schema(self):
        return self._current_schema

    def get_edition(self):
        return self._edition

    def get_external_name(self):
        return self._external_name

    def get_internal_name(self):
        return self._internal_name

    def get_ltxid(self):
        return self._ltxid or b''

    def get_stmt_cache_size(self):
        return self._statement_cache_size

    def get_version(self):
        return self._server_version

    def ping(self):
        self._protocol._ping()

    def rollback(self):
        self._protocol._rollback()

    def set_action(self, str value):
        self._action = value
        self._action_modified = True

    def set_client_identifier(self, str value):
        self._client_identifier = value
        self._client_identifier_modified = True

    def set_client_info(self, str value):
        self._client_info = value
        self._client_info_modified = True

    def set_current_schema(self, value):
        self._current_schema = value
        self._current_schema_modified = True

    def set_dbop(self, str value):
        self._dbop = value
        self._dbop_modified = True

    def set_external_name(self, value):
        self._external_name = value

    def set_internal_name(self, value):
        self._internal_name = value

    def set_module(self, str value):
        self._module = value
        self._module_modified = True
        # setting the module by itself results in an error so always force the
        # action to be set as well (which eliminates this error)
        self._action_modified = True

    def set_stmt_cache_size(self, uint32_t value):
        self._statement_cache_size = value
        self._adjust_statement_cache()
