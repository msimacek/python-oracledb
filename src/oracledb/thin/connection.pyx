#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class Connection(BaseConnection):

    cdef:
        StatementCache _statement_cache
        Protocol _protocol

    cdef int _close(self) except -1:
        self._protocol._close()

    cdef int _commit(self) except -1:
        self._protocol._commit()

    def _connect(self, host, port, connect_string, password):
        sock = socket.socket()
        sock.connect((host, port))
        params = types.SimpleNamespace(connect_string=connect_string,
                                       user=self.username, password=password)
        self._protocol = Protocol(sock)
        self._protocol._connect(params)
        self._statement_cache = StatementCache(30)
        self._is_connected = True

    cdef BaseCursor _create_cursor(self):
        return Cursor.__new__(Cursor, self)

    cdef str _get_version(self):
        return self._protocol._server_version

    cdef int _ping(self) except -1:
        self._protocol._ping()

    cdef int _rollback(self) except -1:
        self._protocol._rollback()
