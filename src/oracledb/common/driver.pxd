#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

from libc.stdint cimport int32_t, uint32_t, uint64_t

cdef class BaseConnection:
    cdef readonly str user
    cdef readonly str dsn
    cdef bint _is_connected

    cdef int _verify_connected(self) except -1


cdef class BaseCursor:
    cdef:
        readonly uint64_t rowcount
        readonly str statement
        public uint32_t arraysize
        public uint32_t prefetchrows
        bint _is_open

    cdef int _verify_open(self) except -1


cdef object get_exception_class(int32_t code)
