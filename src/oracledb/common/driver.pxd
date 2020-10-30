#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

# cython: language_level=3

from libc.stdint cimport int8_t, int16_t, int32_t, int64_t
from libc.stdint cimport uint8_t, uint16_t, uint32_t, uint64_t

cdef class ApiType:
    cdef:
        readonly name
        tuple dbtypes


cdef class DbType:
    cdef:
        readonly uint32_t num
        readonly str name
        readonly uint32_t default_size
        uint32_t _buffer_size_factor
        uint8_t _ora_type_num
        uint8_t _csfrm

    @staticmethod
    cdef DbType _from_num(uint32_t num)

    @staticmethod
    cdef DbType _from_ora_type_and_csfrm(uint8_t ora_type_num, uint8_t csfrm)

    @staticmethod
    cdef DbType _from_type(object typ)

    @staticmethod
    cdef DbType _from_value(object value, uint32_t *size)


cdef class BaseConnection:

    cdef:
        readonly str username
        readonly str dsn
        public object inputtypehandler
        public object outputtypehandler
        public bint autocommit
        str _version
        bint _is_connected

    cdef int _begin(self, long format_id, str transaction_id,
                    str branch_id) except -1
    cdef int _cancel(self) except -1
    cdef int _change_password(self, str old_password,
                              str new_password) except -1
    cdef int _close(self) except -1
    cdef int _commit(self) except -1
    cdef BaseCursor _create_cursor(self)
    cdef str _get_current_schema(self)
    cdef str _get_edition(self)
    cdef str _get_external_name(self)
    cdef str _get_internal_name(self)
    cdef bytes _get_ltxid(self)
    cdef uint32_t _get_stmtcachesize(self) except *
    cdef str _get_version(self)
    cdef int _ping(self) except -1
    cdef bint _prepare(self) except *
    cdef int _rollback(self) except -1
    cdef int _set_action(self, str value) except -1
    cdef int _set_client_identifier(self, str value) except -1
    cdef int _set_client_info(self, str value) except -1
    cdef int _set_current_schema(self, str value) except -1
    cdef int _set_dbop(self, str value) except -1
    cdef int _set_external_name(self, str value) except -1
    cdef int _set_internal_name(self, str value) except -1
    cdef int _set_module(self, str value) except -1
    cdef int _set_stmtcachesize(self, uint32_t value) except -1
    cdef int _verify_connected(self) except -1


cdef class BaseCursor:
    cdef:
        readonly str statement
        readonly uint64_t rowcount
        public uint32_t arraysize
        public uint32_t prefetchrows
        public object inputtypehandler
        public object outputtypehandler
        public object rowfactory
        uint32_t _buffer_rowcount
        uint32_t _buffer_index
        uint32_t _fetch_array_size
        list _fetch_vars
        object _bind_vars
        bint _more_rows_to_fetch
        bint _set_input_sizes
        bint _is_open

    cdef int _bind_by_name(self, dict params, uint32_t num_elements=*,
                           uint32_t pos=*) except -1

    cdef int _bind_by_position(self, object params, uint32_t num_elements=*,
                               uint32_t pos=*) except -1

    cdef int _close(self) except -1

    cdef object _create_row(self)

    cdef BaseVar _create_var(self)

    cdef BaseVar _create_var_by_type(self, object value,
                                     uint32_t num_elements=?)

    cdef BaseVar _create_var_by_value(self, object value,
                                      uint32_t num_elements)

    cdef int _execute(self) except -1

    cdef int _executemany(self, uint32_t num_execs, bint batcherrors,
                          bint arraydmlrowcounts) except -1

    cdef object _fetch_next_row(self)

    cdef int _fetch_rows(self) except -1

    cdef object _get_array_dml_row_counts(self)

    cdef object _get_batch_errors(self)

    cdef BaseVar _get_bind_var(self, uint32_t num_elements, uint32_t pos,
                               object value, BaseVar orig_var)

    cdef int _perform_binds(self) except -1

    cdef int _prepare(self, str statement, str tag=*) except -1

    cdef int _verify_fetch(self) except -1

    cdef int _verify_open(self) except -1


cdef class BaseVar:
    cdef:
        readonly str name
        readonly DbType type
        readonly int16_t precision
        readonly int16_t scale
        readonly uint32_t num_elements
        readonly object inconverter
        readonly object outconverter
        readonly uint32_t size
        readonly uint32_t buffer_size
        readonly bint is_array
        readonly bint nulls_allowed

    cdef int _bind(self, BaseCursor cursor, str name=*,
                   uint32_t pos=*) except -1

    cdef int _finalize_init(self) except -1

    cdef uint32_t _get_actual_elements(self) except *

    cdef list _get_array_value(self, uint32_t num_elements)

    cdef object _get_single_value(self, uint32_t pos)

    cdef int _set_array_value(self, list value) except -1

    cdef int _set_single_value(self, uint32_t pos, object value) except -1

    cdef int _set_value(self, uint32_t pos, object value) except -1


cdef object get_exception_class(int32_t code)
