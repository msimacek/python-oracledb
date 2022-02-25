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
        double _time_in_pool
        list _temp_lobs_to_close
        uint32_t _temp_lobs_total_size
        uint32_t _call_timeout

    cdef int _add_cursor_to_close(self, Statement stmt) except -1:
        if self._num_cursors_to_close == TNS_MAX_CURSORS_TO_CLOSE:
            raise Exception("too many cursors to close!")
        self._cursors_to_close[self._num_cursors_to_close] = stmt._cursor_id
        self._num_cursors_to_close += 1

    cdef int _adjust_statement_cache(self) except -1:
        cdef Statement stmt
        while len(self._statement_cache) > self._statement_cache_size:
            stmt = <Statement> self._statement_cache.popitem(last=False)[1]
            if stmt._in_use:
                stmt._return_to_cache = False
            elif stmt._cursor_id != 0:
                self._add_cursor_to_close(stmt)

    cdef int _force_close(self) except -1:
        self._pool = None
        self._protocol._force_close()

    cdef object _get_socket(self, object params, bint raise_exception):
        """
	Get a socket on which to communicate using the provided parameters. If
	a proxy is configured, a connection to the proxy is established and the
        target host and port is forwarded to the proxy before the socket is
        returned.
        """
        cdef bint use_proxy = (params.https_proxy is not None)
        if use_proxy:
            connect_info = (params.https_proxy, params.https_proxy_port)
        else:
            connect_info = (params.host, params.port)
        try:
            sock = socket.create_connection(connect_info,
                                            params.tcp_connect_timeout)
        except socket.gaierror:
            if raise_exception:
                raise
            return None
        if use_proxy:
            data = f"CONNECT {params.host}:{params.port} HTTP/1.0\r\n\r\n"
            sock.send(data.encode())
            reply = sock.recv(1024)
            match = re.search('HTTP/1.[01]\\s+(\\d+)\\s+', reply.decode())
            if match is None or match.groups()[0] != '200':
                errors._raise_err(errors.ERR_PROXY_FAILURE,
                                  response=reply.decode())
        return sock

    cdef Statement _get_statement(self, str sql, bint cache_statement):
        cdef Statement statement
        with self._statement_cache_lock:
            statement = self._statement_cache.get(sql)
            if statement is None:
                statement = Statement()
                statement._prepare(sql, self._protocol._caps.char_conversion)
                if len(self._statement_cache) < self._statement_cache_size \
                        and cache_statement:
                    self._statement_cache[sql] = statement
                    statement._return_to_cache = True
            elif statement._in_use or not cache_statement:
                if not cache_statement:
                    del self._statement_cache[sql]
                    statement._return_to_cache = False
                if statement._in_use:
                    statement = statement.copy()
            else:
                self._statement_cache.move_to_end(sql)
            statement._in_use = True
            return statement

    cdef int _return_statement(self, Statement statement) except -1:
        """
        Return the statement to the statement cache, if applicable. If the
        statement must not be returned to the statement cache, add the cursor
        id to the list of cursor ids to close on the next round trip to the
        database. Clear all bind variables and fetch variables in order to
        ensure that unnecessary references are not retained.
        """
        cdef:
            BaseVarImpl var_impl
            BindInfo bind_info
        if statement._bind_info_list is not None:
            for bind_info in statement._bind_info_list:
                bind_info._bind_var_impl = None
        if statement._fetch_var_impls is not None:
            for var_impl in statement._fetch_var_impls:
                var_impl.values = [None] * var_impl.num_elements
        with self._statement_cache_lock:
            if statement._return_to_cache:
                statement._in_use = False
                self._statement_cache.move_to_end(statement._sql)
                self._adjust_statement_cache()
            elif statement._cursor_id != 0:
                self._add_cursor_to_close(statement)

    def cancel(self):
        self._protocol._break_external()

    def change_password(self, str old_password, str new_password):
        self._protocol._change_password(self, old_password, new_password)

    def get_is_healthy(self):
        return not self._protocol._session_needs_to_be_closed

    def close(self, bint in_del=False):
        try:
            self._protocol._close(self)
        except ssl.SSLError:
            pass

    def commit(self):
        self._protocol._commit()

    def connect(self, params, str password, str newpassword=None):
        cdef unsigned long num_attempts = params.retry_count + 1
        for i in range(num_attempts):
            sock = self._get_socket(params, i == num_attempts - 1)
            if sock is not None:
                break
            time.sleep(params.retry_delay)
        if params.expire_time > 0:
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_KEEPALIVE, 1)
        if params.expire_time > 0 \
                and hasattr(socket, "TCP_KEEPIDLE") \
                and hasattr(socket, "TCP_KEEPINTVL") \
                and hasattr(socket, "TCP_KEEPCNT"):
            sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_KEEPIDLE,
                            params.expire_time * 60)
            sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_KEEPINTVL, 6)
            sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_KEEPCNT, 10)
        sock.settimeout(None)
        if params.protocol == "tcps":
            sock = get_ssl_socket(sock, params)
        self._protocol = Protocol(sock)
        redirect_data = self._protocol._connect(self, params,
                                                _get_connect_data(params),
                                                password, newpassword)
        if redirect_data is None:
            self._statement_cache = collections.OrderedDict()
            self._statement_cache_size = params.stmtcachesize
            self._statement_cache_lock = threading.Lock()
            self._cursors_to_close = array.array('I')
            array.resize(self._cursors_to_close, TNS_MAX_CURSORS_TO_CLOSE)
            self._drcp_enabled = params.enable_drcp
        return redirect_data

    def create_cursor_impl(self):
        return ThinCursorImpl.__new__(ThinCursorImpl, self)

    def create_temp_lob_impl(self, DbType dbtype):
        return ThinLobImpl._create(self, dbtype)

    def get_call_timeout(self):
        return self._call_timeout

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

    def set_call_timeout(self, uint32_t value):
        timeout = None if value == 0 else value / 1000
        self._protocol._socket.settimeout(timeout)
        self._call_timeout = value

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
