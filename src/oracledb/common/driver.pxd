#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

# cython: language_level=3

from libc.stdint cimport int32_t, uint32_t, uint64_t

cdef class ApiType:
    cdef:
        readonly name
        tuple dbtypes


cdef class DbType:
    cdef:
        readonly uint32_t num
        readonly str name

    @staticmethod
    cdef DbType _from_num(uint32_t num)

    @staticmethod
    cdef DbType _from_type(object typ)


cdef class BaseConnection:
    cdef:
        readonly str user
        readonly str dsn
        public object outputtypehandler
        bint _is_connected

    cdef BaseCursor _create_cursor(self)

    cdef int _verify_connected(self) except -1


cdef class BaseCursor:
    cdef:
        readonly str statement
        public uint32_t arraysize
        public uint32_t prefetchrows
        public object outputtypehandler
        public object rowfactory
        list _fetch_vars
        bint _is_open

    cdef BaseVar _create_var(self)

    cdef int _execute(self) except -1

    cdef object _fetch_next_row(self)

    cdef int _prepare(self, str statement, str tag=*) except -1

    cdef int _verify_fetch(self) except -1

    cdef int _verify_open(self) except -1


cdef class BaseVar:
    cdef:
        readonly object inconverter
        readonly object outconverter
        readonly uint32_t num_elements
        readonly bint is_array
        readonly uint32_t size
        readonly uint32_t buffer_size
        readonly DbType type

    cdef int _finalize_init(self) except -1

    cdef uint32_t _get_actual_elements(self) except *

    cdef list _get_array_value(self, uint32_t num_elements)

    cdef object _get_single_value(self, uint32_t pos)


cdef object get_exception_class(int32_t code)
