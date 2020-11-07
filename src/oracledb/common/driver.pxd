#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

# cython: language_level=3

from libc.stdint cimport int8_t, int16_t, int32_t, int64_t
from libc.stdint cimport uint8_t, uint16_t, uint32_t, uint64_t

cdef enum:
    FETCH_MODE_ABSOLUTE = 0x0020
    FETCH_MODE_FIRST = 0x0004
    FETCH_MODE_LAST = 0x0008
    FETCH_MODE_RELATIVE = 0x0040

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
    cdef DbType _from_value(object value, uint32_t *size, bint is_plsql=*)


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
    cdef BaseLob _create_temp_lob(self, DbType dbtype)
    cdef str _get_current_schema(self)
    cdef str _get_edition(self)
    cdef str _get_external_name(self)
    cdef str _get_internal_name(self)
    cdef bytes _get_ltxid(self)
    cdef uint32_t _get_stmtcachesize(self) except *
    cdef BaseDbObjectType _get_type(self, str name)
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


cdef class BasePool:
    cdef:
        readonly str dsn
        readonly bint homogeneous
        readonly uint32_t increment
        readonly uint32_t min
        readonly uint32_t max
        readonly str username
        readonly str name

    cdef BaseConnection _acquire(self, str user, str password, str cclass,
                                 uint32_t purity, str tag, bint match_any_tag,
                                 list sharding_key, list super_sharding_key)
    cdef int _close(self, bint force) except -1
    cdef int _drop(self, BaseConnection connection) except -1
    cdef int _get_busy_count(self, uint32_t *value) except -1
    cdef int _get_getmode(self, uint8_t *value) except -1
    cdef int _get_max_lifetime_session(self, uint32_t *value) except -1
    cdef int _get_open_count(self, uint32_t *value) except -1
    cdef int _get_stmt_cache_size(self, uint32_t *value) except -1
    cdef int _get_timeout(self, uint32_t *value) except -1
    cdef int _get_wait_timeout(self, uint32_t *value) except -1
    cdef int _release(self, BaseConnection connection, str tag) except -1
    cdef int _set_getmode(self, uint8_t value) except -1
    cdef int _set_max_lifetime_session(self, uint32_t value) except -1
    cdef int _set_stmt_cache_size(self, uint32_t value) except -1
    cdef int _set_timeout(self, uint32_t value) except -1
    cdef int _set_wait_timeout(self, uint32_t value) except -1


cdef class BaseCursor:
    cdef:
        readonly BaseConnection connection
        readonly str statement
        readonly uint64_t rowcount
        public uint32_t arraysize
        public uint32_t prefetchrows
        public object inputtypehandler
        public object outputtypehandler
        public object rowfactory
        public bint scrollable
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
    cdef object _bindnames(self)
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
    cdef object _get_implicit_results(self)
    cdef object _get_lastrowid(self)
    cdef bint _is_plsql(self)
    cdef bint _is_query(self) except *
    cdef int _perform_binds(self) except -1
    cdef int _parse(self) except -1
    cdef int _prepare(self, str statement, str tag=*) except -1
    cdef int _scroll(self, int32_t offset, uint32_t mode) except -1
    cdef int _verify_fetch(self) except -1
    cdef int _verify_open(self) except -1


cdef class BaseVar:
    cdef:
        readonly str name
        readonly int16_t precision
        readonly int16_t scale
        readonly uint32_t num_elements
        readonly object inconverter
        readonly object outconverter
        readonly uint32_t size
        readonly uint32_t buffer_size
        readonly bint is_array
        readonly bint nulls_allowed
        DbType _dbtype
        BaseDbObjectType _objtype

    cdef int _bind(self, BaseCursor cursor, str name=*,
                   uint32_t pos=*) except -1
    cdef int _finalize_init(self) except -1
    cdef uint32_t _get_actual_elements(self) except *
    cdef list _get_array_value(self, uint32_t num_elements)
    cdef object _get_single_value(self, uint32_t pos)
    cdef int _set_array_value(self, list value) except -1
    cdef int _set_single_value(self, uint32_t pos, object value) except -1
    cdef int _set_value(self, uint32_t pos, object value) except -1


cdef class BaseLob:
    cdef:
        readonly DbType type
        readonly BaseConnection _connection

    cdef int _close(self) except -1
    cdef int _file_exists(self, bint* exists) except -1
    cdef int _get_chunk_size(self, uint32_t* size) except -1
    cdef object _get_file_name(self)
    cdef int _get_is_open(self, bint* is_open) except -1
    cdef int _open(self) except -1
    cdef object _read(self, uint64_t offset, uint64_t amount)
    cdef int _set_file_name(self, str dir_alias, str name) except -1
    cdef int _get_size(self, uint64_t* size) except -1
    cdef int _trim(self, uint64_t new_size=*) except -1
    cdef int _write(self, object value, uint64_t offset) except -1


cdef class BaseDbObjectType:
    cdef:
        readonly str schema
        readonly str name
        readonly list attributes
        readonly bint iscollection
        readonly BaseConnection _connection
        readonly dict _attributesByName
        DbType _element_dbtype
        BaseDbObjectType _element_objtype

    cdef BaseDbObject _new_object(self)


cdef class BaseDbObjectAttr:
    cdef:
        readonly str name
        DbType _dbtype
        BaseDbObjectType _objtype


cdef class BaseDbObject:
    cdef:
        readonly BaseDbObjectType type

    cdef int _append(self, object value) except -1
    cdef object _copy(self)
    cdef int _delete_by_index(self, int32_t index) except -1
    cdef bint _exists_by_index(self, int32_t index) except *
    cdef object _get_attr_value(self, BaseDbObjectAttr attr)
    cdef object _get_element_by_index(self, int32_t index)
    cdef int _get_first_index(self, int32_t* index, bint* exists) except -1
    cdef int _get_last_index(self, int32_t* index, bint* exists) except -1
    cdef int _get_next_index(self, int32_t index, int32_t* next_index,
                             bint* exists) except -1
    cdef int _get_prev_index(self, int32_t index, int32_t* prev_index,
                             bint* exists) except -1
    cdef int32_t _get_size(self) except *
    cdef int _set_attr_value(self, BaseDbObjectAttr attr,
                             object value) except -1
    cdef int _set_element_by_index(self, int32_t index, object value) except -1
    cdef int _trim(self, int32_t num_to_trim) except -1

cdef object get_exception_class(int32_t code)
