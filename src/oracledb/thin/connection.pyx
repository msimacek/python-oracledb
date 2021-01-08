#------------------------------------------------------------------------------
# Copyright (c) 2020, 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class Connection(BaseConnection):

    cdef:
        StatementCache _statement_cache
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

    cdef int _close(self) except -1:
        self._protocol._close()

    cdef int _commit(self) except -1:
        self._protocol._commit()

    def _connect(self, host, port, connect_string, password):
        sock = socket.socket()
        sock.connect((host, port))
        self._protocol = Protocol(sock)
        self._protocol._connect(self, connect_string, password)
        self._statement_cache = StatementCache(30)
        self._is_connected = True

    cdef BaseCursor _create_cursor(self):
        return Cursor.__new__(Cursor, self)

    cdef BaseLob _create_temp_lob(self, DbType dbtype):
        return Lob._create_temp_lob(self, dbtype)

    cdef str _get_version(self):
        return self._server_version

    cdef int _ping(self) except -1:
        self._protocol._ping()

    cdef int _rollback(self) except -1:
        self._protocol._rollback()

    cdef int _set_action(self, str value) except -1:
        self._action = value
        self._action_modified = True

    cdef int _set_client_identifier(self, str value) except -1:
        self._client_identifier = value
        self._client_identifier_modified = True

    cdef int _set_client_info(self, str value) except -1:
        self._client_info = value
        self._client_info_modified = True

    cdef int _set_dbop(self, str value) except -1:
        self._dbop = value
        self._dbop_modified = True

    cdef int _set_module(self, str value) except -1:
        self._module = value
        self._module_modified = True
        # setting the module by itself results in an error so always force the
        # action to be set as well (which eliminates this error)
        self._action_modified = True
