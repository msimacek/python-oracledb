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

cdef enum:
    NUM_TYPE_FLOAT = 0
    NUM_TYPE_INT = 1
    NUM_TYPE_DECIMAL = 2

cdef class ApiType:
    cdef:
        readonly str name
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
    cdef DbType _from_value(object value, uint32_t *size, bint is_plsql=*)


cdef class BaseConnImpl:
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
    cdef int _commit(self) except -1
    cdef BaseMsgProps _create_msg_props(self)
    cdef BaseQueue _create_queue(self)
    cdef BaseSubscription _create_subscription(self, object connection)
    cdef BaseLob _create_temp_lob(self, DbType dbtype)
    cdef str _get_current_schema(self)
    cdef str _get_edition(self)
    cdef str _get_external_name(self)
    cdef str _get_internal_name(self)
    cdef bytes _get_ltxid(self)
    cdef BaseSodaDatabase _get_soda_database(self, object connection)
    cdef int _get_stmtcachesize(self, uint32_t *value) except -1
    cdef int _get_calltimeout(self, uint32_t *value) except -1
    cdef BaseDbObjectType _get_type(self, object conn, str name)
    cdef str _get_version(self)
    cdef int _ping(self) except -1
    cdef int _prepare(self, bint *commit_needed) except -1
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
    cdef int _set_calltimeout(self, uint32_t value) except -1


cdef class BasePool:
    cdef:
        readonly str dsn
        readonly bint homogeneous
        readonly uint32_t increment
        readonly uint32_t min
        readonly uint32_t max
        readonly str username
        readonly str name
        object connection_type

    cdef object _acquire(self, str user, str password, str cclass,
                         uint32_t purity, str tag, bint match_any_tag,
                         list sharding_key, list super_sharding_key)
    cdef int _close(self, bint force) except -1
    cdef int _drop(self, BaseConnImpl connection) except -1
    cdef int _get_busy_count(self, uint32_t *value) except -1
    cdef int _get_getmode(self, uint8_t *value) except -1
    cdef int _get_max_lifetime_session(self, uint32_t *value) except -1
    cdef int _get_open_count(self, uint32_t *value) except -1
    cdef int _get_stmt_cache_size(self, uint32_t *value) except -1
    cdef int _get_timeout(self, uint32_t *value) except -1
    cdef int _get_wait_timeout(self, uint32_t *value) except -1
    cdef int _release(self, BaseConnImpl connection, str tag) except -1
    cdef int _set_getmode(self, uint8_t value) except -1
    cdef int _set_max_lifetime_session(self, uint32_t value) except -1
    cdef int _set_stmt_cache_size(self, uint32_t value) except -1
    cdef int _set_timeout(self, uint32_t value) except -1
    cdef int _set_wait_timeout(self, uint32_t value) except -1


cdef class BaseCursorImpl:
    cdef:
        readonly str statement
        readonly uint64_t rowcount
        public uint32_t arraysize
        public uint32_t prefetchrows
        public object inputtypehandler
        public object outputtypehandler
        public object rowfactory
        public bint scrollable
        public list fetch_vars
        public object bind_vars
        uint32_t _buffer_rowcount
        uint32_t _buffer_index
        uint32_t _fetch_array_size
        bint _more_rows_to_fetch

    cdef int _bind_by_name(self, object cursor, dict params,
                           uint32_t num_elements=*, uint32_t pos=*) except -1
    cdef int _bind_by_position(self, object cursor, object params,
                               uint32_t num_elements=*,
                               uint32_t pos=*) except -1
    cdef object _bindnames(self)
    cdef int _close(self) except -1
    cdef object _create_row(self)
    cdef BaseVar _create_var(self, object connection)
    cdef BaseVar _create_var_by_type(self, object connection, object value,
                                     uint32_t num_elements=?)
    cdef BaseVar _create_var_by_value(self, object cursor, object value,
                                      uint32_t num_elements)
    cdef int _fetch_rows(self, object cursor) except -1
    cdef object _get_array_dml_row_counts(self)
    cdef object _get_batch_errors(self)
    cdef BaseVar _get_bind_var(self, object cursor, uint32_t num_elements,
                               uint32_t pos, object value, BaseVar orig_var)
    cdef object _get_lastrowid(self)
    cdef bint _is_plsql(self)
    cdef int _perform_binds(self, uint32_t num_execs=*) except -1
    cdef int _parse(self, object connection) except -1
    cdef int _prepare(self, str statement, str tag=*) except -1
    cdef int _scroll(self, int32_t offset, uint32_t mode) except -1


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
        uint32_t _num_elements_in_array
        object _conn
        list _values
        DbType _dbtype
        BaseDbObjectType _objtype
        int _preferred_num_type
        bint _is_value_set

    cdef int _bind(self, BaseCursorImpl cursor, uint32_t num_execs, str name=*,
                   uint32_t pos=*) except -1
    cdef int _finalize_init(self) except -1
    cdef uint32_t _get_actual_elements(self)
    cdef list _get_array_value(self, uint32_t num_elements)
    cdef object _get_single_value(self, uint32_t pos)
    cdef int _resize(self, uint32_t new_size) except -1
    cdef int _set_array_value(self, list value) except -1
    cdef int _set_dbtype_from_type(self, object typ) except -1
    cdef int _set_single_value(self, uint32_t pos, object value) except -1
    cdef int _set_value(self, uint32_t pos, object value) except -1


cdef class BaseLob:
    cdef:
        readonly DbType type
        readonly BaseConnImpl _connection

    cdef int _close(self) except -1
    cdef int _file_exists(self, bint* exists) except -1
    cdef int _get_chunk_size(self, uint32_t* size) except -1
    cdef object _get_file_name(self)
    cdef int _get_is_open(self, bint* is_open) except -1
    cdef int _get_max_amount(self, uint64_t* max_amount) except -1
    cdef int _get_size(self, uint64_t* size) except -1
    cdef int _open(self) except -1
    cdef object _read(self, uint64_t offset, uint64_t amount)
    cdef int _set_file_name(self, str dir_alias, str name) except -1
    cdef int _trim(self, uint64_t new_size=*) except -1
    cdef int _write(self, object value, uint64_t offset) except -1


cdef class BaseDbObjectType:
    cdef:
        readonly str schema
        readonly str name
        readonly list attributes
        readonly bint iscollection
        readonly object _conn
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
    cdef int _exists_by_index(self, int32_t index, bint* exists) except -1
    cdef object _get_attr_value(self, BaseDbObjectAttr attr)
    cdef object _get_element_by_index(self, int32_t index)
    cdef int _get_first_index(self, int32_t* index, bint* exists) except -1
    cdef int _get_last_index(self, int32_t* index, bint* exists) except -1
    cdef int _get_next_index(self, int32_t index, int32_t* next_index,
                             bint* exists) except -1
    cdef int _get_prev_index(self, int32_t index, int32_t* prev_index,
                             bint* exists) except -1
    cdef int _get_size(self, int32_t *size) except -1
    cdef int _set_attr_value(self, BaseDbObjectAttr attr,
                             object value) except -1
    cdef int _set_element_by_index(self, int32_t index, object value) except -1
    cdef int _trim(self, int32_t num_to_trim) except -1


cdef class BaseSodaDatabase:
    cdef:
        object _conn

    cdef BaseSodaCollection _create_collection(self, str name, str metadata,
                                               bint map_mode)
    cdef BaseSodaDoc _create_document(self, bytes content, str key,
                                      str media_type)
    cdef object _get_collection_names(self, str start_name, uint32_t limit)
    cdef BaseSodaCollection _open_collection(self, str name)


cdef class BaseSodaCollection:
    cdef:
        BaseSodaDatabase _db
        readonly str name

    cdef int _create_index(self, str spec) except -1
    cdef BaseSodaOperation _create_operation(self)
    cdef int _drop(self, bint* is_dropped) except -1
    cdef int _drop_index(self, str name, bint force,
                         bint* is_dropped) except -1
    cdef BaseSodaDoc _get_data_guide(self)
    cdef object _get_metadata(self)
    cdef object _insert_many(self, list documents, bint return_docs)
    cdef object _insert_one(self, BaseSodaDoc doc, bint return_doc)
    cdef BaseSodaDoc _process_doc_arg(self, object doc_arg)
    cdef object _save(self, BaseSodaDoc doc, bint return_doc)
    cdef int _truncate(self) except -1


cdef class BaseSodaDoc:
    cdef:
        BaseSodaDatabase _db

    cdef object _get_content(self, const char **encoding)
    cdef object _get_created_on(self)
    cdef object _get_key(self)
    cdef object _get_last_modified(self)
    cdef object _get_media_type(self)
    cdef object _get_version(self)


cdef class BaseSodaDocCursor:
    cdef:
        BaseSodaDatabase _db

    cdef object _get_next_doc(self)
    cdef int _close(self) except -1


cdef class BaseSodaOperation:
    cdef:
        BaseSodaCollection _collection
        str _key
        list _keys
        str _version
        str _filter
        uint32_t _skip
        uint32_t _limit
        uint32_t _fetch_array_size

    cdef int _count(self, uint64_t* count) except -1
    cdef BaseSodaDocCursor _get_cursor(self)
    cdef BaseSodaDoc _get_one(self)
    cdef int _remove(self, uint64_t* count) except -1
    cdef object _replace_one(self, BaseSodaDoc doc, bint return_doc,
                             bint* replaced)


cdef class BaseQueue:
    cdef:
        readonly BaseConnImpl connection
        readonly str name
        readonly BaseDbObjectType payloadType
        readonly BaseDeqOptions deqOptions
        readonly BaseEnqOptions enqOptions

    cdef object _deq_many(self, uint32_t max_messages)
    cdef object _deq_one(self)
    cdef int _enq_many(self, list messages) except -1
    cdef int _enq_one(self, BaseMsgProps message) except -1
    cdef int _initialize(self) except -1


cdef class BaseDeqOptions:

    cdef object _get_condition(self)
    cdef object _get_consumer_name(self)
    cdef object _get_correlation(self)
    cdef int _get_mode(self, uint32_t* value) except -1
    cdef object _get_message_id(self)
    cdef int _get_navigation(self, uint32_t* value) except -1
    cdef object _get_transformation(self)
    cdef int _get_visibility(self, uint32_t* value) except -1
    cdef int _get_wait(self, uint32_t* value) except -1
    cdef int _set_condition(self, str value) except -1
    cdef int _set_consumer_name(self, str value) except -1
    cdef int _set_correlation(self, str value) except -1
    cdef int _set_delivery_mode(self, uint16_t value) except -1
    cdef int _set_mode(self, uint32_t value) except -1
    cdef int _set_message_id(self, bytes value) except -1
    cdef int _set_navigation(self, uint32_t value) except -1
    cdef int _set_transformation(self, str value) except -1
    cdef int _set_visibility(self, uint32_t value) except -1
    cdef int _set_wait(self, uint32_t value) except -1


cdef class BaseEnqOptions:

    cdef object _get_transformation(self)
    cdef int _get_visibility(self, uint32_t* value) except -1
    cdef int _set_delivery_mode(self, uint16_t value) except -1
    cdef int _set_transformation(self, str value) except -1
    cdef int _set_visibility(self, uint32_t value) except -1


cdef class BaseMsgProps:
    cdef:
        public object payload

    cdef int _get_num_attempts(self, int32_t* value) except -1
    cdef object _get_correlation(self)
    cdef int _get_delay(self, int32_t* value) except -1
    cdef int _get_delivery_mode(self, uint16_t* value) except -1
    cdef object _get_enq_time(self)
    cdef object _get_exception_queue(self)
    cdef int _get_expiration(self, int32_t* value) except -1
    cdef object _get_original_message_id(self)
    cdef int _get_priority(self, int32_t* value) except -1
    cdef int _get_message_state(self, uint32_t* value) except -1
    cdef int _set_correlation(self, str value) except -1
    cdef int _set_delay(self, int32_t value) except -1
    cdef int _set_exception_queue(self, str value) except -1
    cdef int _set_expiration(self, int32_t value) except -1
    cdef int _set_original_message_id(self, bytes value) except -1
    cdef int _set_priority(self, int32_t value) except -1


cdef class BaseSubscription:
    cdef:
        readonly object callback
        readonly object connection
        readonly uint32_t namespace
        readonly str name
        readonly uint32_t protocol
        readonly str ip_address
        readonly uint32_t port
        readonly uint32_t timeout
        readonly uint32_t operations
        readonly uint32_t qos
        readonly uint64_t id
        readonly uint8_t grouping_class
        readonly uint32_t grouping_value
        readonly uint8_t grouping_type
        readonly bint client_initiated
        BaseConnImpl _conn_impl

    cdef int _register_query(self, str sql, object args,
                             uint64_t* query_id) except -1
    cdef int _unsubscribe(self, BaseConnImpl connection) except -1


cdef class Message:
    cdef:
        readonly uint32_t type
        readonly BaseSubscription subscription
        readonly str dbname
        readonly bytes txid
        readonly list tables
        readonly list queries
        readonly str queueName
        readonly str consumerName
        readonly bint registered


cdef class MessageQuery:
    cdef:
        readonly uint64_t id
        readonly uint32_t operation
        readonly list tables


cdef class MessageRow:
    cdef:
        readonly uint32_t operation
        readonly str rowid


cdef class MessageTable:
    cdef:
        readonly str name
        readonly uint32_t operation
        readonly list rows


cdef object get_exception_class(int32_t code)
