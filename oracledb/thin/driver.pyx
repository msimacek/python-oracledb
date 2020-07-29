#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

# cython: language_level=3

cimport cython
cimport cpython

from Crypto.Cipher import AES
import hashlib
import os
import socket
import types

from .. import constants, errors, exceptions

from ..common.driver cimport get_exception_class
from ..common.driver cimport Connection as BaseConnection

include "buffer.pyx"
include "constants.pxi"
include "protocol.pyx"

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
