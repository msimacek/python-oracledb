#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class Connection(BaseConnection):

    cdef:
        Protocol _protocol

    def _connect(self, host, port, connect_string, password):
        sock = socket.socket()
        sock.connect((host, port))
        params = types.SimpleNamespace(connect_string=connect_string,
                user=self.user, password=password)
        self._protocol = Protocol(sock)
        self._protocol._connect(params)
