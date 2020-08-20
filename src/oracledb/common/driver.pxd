#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

# cython: language_level=3

from libc.stdint cimport int32_t, uint32_t, uint64_t

cdef class BaseConnection:
    cdef:
        readonly str user
        readonly str dsn
        bint _is_connected

    cdef int _verify_connected(self) except -1


cdef class BaseCursor:
    cdef:
        readonly str statement
        public uint32_t arraysize
        public uint32_t prefetchrows
        bint _is_open

    cdef int _verify_open(self) except -1


cdef class ApiType:
    cdef:
        readonly name
        tuple db_types


cdef class DbType:
    cdef:
        readonly uint32_t num
        readonly str name


cdef object get_exception_class(int32_t code)
