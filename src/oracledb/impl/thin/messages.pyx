#------------------------------------------------------------------------------
# Copyright (c) 2020, 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

@cython.freelist(20)
cdef class _OracleErrorInfo:
    cdef:
        uint32_t num
        uint16_t cursor_id
        uint16_t pos
        uint64_t rowcount
        bint is_warning
        str message
        str rowid
        list batcherrors


cdef class Message:
    cdef:
        _OracleErrorInfo error_info
        uint8_t message_type
        uint8_t function_code
        uint32_t call_status
        uint16_t end_to_end_seq_num
        uint8_t packet_type
        bint error_occurred

    def __cinit__(self):
        self.message_type = TNS_MSG_TYPE_FUNCTION
        self.error_info = _OracleErrorInfo()

    cdef bint _has_more_data(self, ReadBuffer buf):
        return buf.bytes_left() > 0

    cdef int _preprocess(self) except -1:
        pass

    cdef int _process_error_info(self, ReadBuffer buf) except -1:
        cdef:
            _OracleErrorInfo info = self.error_info
            uint16_t num_entries, error_code
            uint32_t num_bytes, i
            uint8_t first_byte
            str error_msg
        self.call_status = buf.read_ub4()   # end of call status
        buf.read_ub2()                      # end to end seq#
        buf.read_ub4()                      # current row number
        buf.read_ub2()                      # error number
        buf.read_ub2()                      # array elem error
        buf.read_ub2()                      # array elem error
        info.cursor_id = buf.read_ub2()     # cursor id
        info.pos = buf.read_ub2()           # error position
        buf.read_uint8()                    # sql type
        buf.read_uint8()                    # fatal?
        buf.read_ub2()                      # flags
        buf.read_ub2()                      # user cursor options
        buf.read_uint8()                    # UPI parameter
        buf.read_uint8()                    # warning flag
        info.rowid = buf.read_rowid()
        buf.read_ub4()                      # OS error
        buf.read_uint8()                    # statement number
        buf.read_uint8()                    # call number
        buf.read_ub2()                      # padding
        buf.read_ub4()                      # success iters
        num_bytes = buf.read_ub4()          # oerrdd (logical rowid)
        if num_bytes > 0:
            buf.read_bytes(buf.read_uint8())

        # batch error codes
        num_entries = buf.read_ub2()        # batch error codes array
        if num_entries > 0:
            info.batcherrors = []
            first_byte = buf.read_uint8()
            for i in range(num_entries):
                if first_byte == TNS_LONG_LENGTH_INDICATOR:
                    buf.read_ub4()          # chunk length ignored
                error_code = buf.read_ub2()
                info.batcherrors.append(errors._Error(code=error_code))
            if first_byte == TNS_LONG_LENGTH_INDICATOR:
                buf.skip_bytes(1)           # ignore end marker

        # batch error offsets
        num_entries = buf.read_ub2()        # batch error row offset array
        if num_entries > 0:
            first_byte = buf.read_uint8()
            for i in range(num_entries):
                if first_byte == TNS_LONG_LENGTH_INDICATOR:
                    buf.read_ub4()          # chunk length ignored
                info.batcherrors[i].offset = buf.read_ub4()
            if first_byte == TNS_LONG_LENGTH_INDICATOR:
                buf.skip_bytes(1)           # ignore end marker

        # batch error messages
        num_entries = buf.read_ub2()        # batch error messages array
        if num_entries > 0:
            buf.skip_bytes(1)               # ignore packed size
            for i in range(num_entries):
                buf.read_ub2()              # skip chunk length
                info.batcherrors[i].message = \
                        buf.read_str(buf.read_uint8()).rstrip()
                buf.skip_bytes(2)           # ignore end marker

        info.num = buf.read_ub4()           # error number (extended)
        info.rowcount = buf.read_ub8()      # row number (extended)
        if info.num != 0:
            info.message = buf.read_str(buf.read_uint8()).rstrip()
        info.is_warning = False

    cdef int _process_message(self, ReadBuffer buf,
                              uint8_t message_type) except -1:
        if message_type == TNS_MSG_TYPE_ERROR:
            self._process_error_info(buf)
        elif message_type == TNS_MSG_TYPE_WARNING:
            self._process_warning_info(buf)
        elif message_type == TNS_MSG_TYPE_STATUS:
            self.call_status = buf.read_ub4()
            self.end_to_end_seq_num = buf.read_ub2()
        elif message_type == TNS_MSG_TYPE_PARAMETER:
            self._process_return_parameters(buf)
        else:
            msg = f"protocol error: unknown message type: {message_type}"
            errors._raise_from_string(exceptions.InternalError, msg)

    cdef int _process_return_parameters(self, ReadBuffer buf) except -1:
        raise NotImplementedError()

    cdef int _process_warning_info(self, ReadBuffer buf) except -1:
        cdef:
            _OracleErrorInfo info = self.error_info
            uint32_t num_bytes
        info.num = buf.read_ub2()           # error number
        num_bytes = buf.read_ub2()          # length of error message
        buf.read_ub2()                      # flags
        if info.num != 0 and num_bytes > 0:
            info.message = buf.read_str(num_bytes).rstrip()
        info.is_warning = True

    cdef int _write_function_code(self, WriteBuffer buf) except -1:
        buf.write_uint8(self.message_type)
        buf.write_uint8(self.function_code)
        buf.write_seq_num()

    cdef int _write_message(self, WriteBuffer buf) except -1:
        self._write_function_code(buf)

    cdef int process(self, ReadBuffer buf) except -1:
        self._preprocess()
        buf.skip_bytes(2)                   # skip data flags
        while self._has_more_data(buf):
            self._process_message(buf, buf.read_uint8())

    cdef int send(self, WriteBuffer buf) except -1:
        buf.start_request(TNS_PACKET_TYPE_DATA)
        self._write_message(buf)
        buf.end_request()


cdef class MessageWithData(Message):
    cdef:
        ThinCursorImpl cursor_impl
        ThinConnImpl conn_impl
        bint arraydmlrowcounts
        bint requires_define
        uint32_t row_index
        uint32_t num_execs
        list dmlrowcounts
        bint batcherrors
        list row_var_impls
        bint in_fetch
        bint parse_only
        bint processed_error
        object cursor
        object conn

    def __cinit__(self, cursor):
        self.cursor = cursor
        self.cursor_impl = cursor._impl
        self.conn = cursor.connection
        self.conn_impl = self.conn._impl
        self.num_execs = 1

    cdef object _create_cursor_from_describe(self, ReadBuffer buf,
                                             object cursor=None):
        cdef ThinCursorImpl cursor_impl
        if cursor is None:
            cursor = Cursor(self.conn)
        cursor_impl = cursor._impl
        cursor_impl._statement = Statement()
        cursor_impl._fetch_array_size = cursor.arraysize + cursor.prefetchrows
        cursor_impl._more_rows_to_fetch = True
        cursor_impl._statement._is_query = True
        self._process_describe_info(buf, cursor)
        return cursor

    cdef bint _has_more_data(self, ReadBuffer buf):
        return not self.processed_error

    cdef int _write_bind_params(self, WriteBuffer buf, list params) except -1:
        cdef:
            bint returning_only, all_values_null = False
            list bind_vars, bind_vals
            uint32_t i
            BindInfo bind_info
        bind_vars = []
        returning_only = True
        for bind_info in params:
            if not bind_info._is_return_bind:
                returning_only = False
            bind_vals = bind_info._bind_var.values
            for i in range(len(bind_vals)):
                if cpython.PyList_GET_ITEM(bind_vals, i) is not \
                        <cpython.ref.PyObject*> None:
                    all_values_null = True
                    break
            bind_vars.append(bind_info._bind_var)
        self._write_column_metadata(buf, bind_vars)

        # plsql batch executions without bind values
        if self.cursor_impl._statement._is_plsql and self.num_execs > 1 \
                and not all_values_null:
            buf.write_uint8(TNS_MSG_TYPE_ROW_DATA)
            buf.write_uint8(TNS_ESCAPE_CHAR)
            buf.write_uint8(1)
        # write parameter values unless statement contains only returning binds
        elif not returning_only:
            for i in range(self.num_execs):
                buf.write_uint8(TNS_MSG_TYPE_ROW_DATA)
                self._write_bind_params_row(buf, params, i)

    cdef int _preprocess(self) except -1:
        cdef:
            ThinCursorImpl cursor_impl = self.cursor_impl
            ThinVarImpl var_impl
        self.processed_error = False
        if cursor_impl._statement._is_query:
            self.in_fetch = True
            if cursor_impl.fetch_vars is not None:
                self.row_var_impls = [v._impl for v in cursor_impl.fetch_vars]
            cursor_impl._more_rows_to_fetch = True
            if self.in_fetch and not cursor_impl._requires_full_execute:
                cursor_impl._fetch_array_size = cursor_impl.arraysize
            cursor_impl._buffer_rowcount = cursor_impl._buffer_index = 0
            if self.row_var_impls is not None:
                for var_impl in self.row_var_impls:
                    if var_impl.num_elements < cursor_impl._fetch_array_size:
                        var_impl.num_elements = cursor_impl._fetch_array_size
                        var_impl.values = [None] * var_impl.num_elements

    cdef object _process_column_data(self, ReadBuffer buf,
                                     ThinVarImpl var_impl, uint32_t pos):
        cdef:
            uint8_t num_bytes, ora_type_num, csfrm
            ThinCursorImpl cursor_impl
            object column_value = None
            uint32_t actual_num_bytes
            ThinLobImpl lob_impl
            bytes temp_bytes
            FetchInfo fetch_info
        fetch_info = var_impl._fetch_info
        if fetch_info is not None:
            ora_type_num = fetch_info._dbtype._ora_type_num
            csfrm =  fetch_info._dbtype._csfrm
        else:
            ora_type_num = var_impl.dbtype._ora_type_num
            csfrm = var_impl.dbtype._csfrm
        num_bytes = buf.read_uint8()
        if num_bytes == 0:
            column_value = None
        elif ora_type_num == TNS_DATA_TYPE_VARCHAR \
                or ora_type_num == TNS_DATA_TYPE_CHAR \
                or ora_type_num == TNS_DATA_TYPE_LONG:
            temp_bytes = buf.read_bytes(num_bytes)
            if csfrm == 1:
                column_value = temp_bytes.decode()
            else:
                column_value = temp_bytes.decode(TNS_ENCODING_UTF16)
            if ora_type_num == TNS_DATA_TYPE_LONG:
                buf.skip_bytes(2)
        elif ora_type_num == TNS_DATA_TYPE_RAW \
                or ora_type_num == TNS_DATA_TYPE_LONG_RAW:
            column_value = buf.read_bytes(num_bytes)
            if ora_type_num == TNS_DATA_TYPE_LONG_RAW:
                buf.skip_bytes(2)
        elif ora_type_num == TNS_DATA_TYPE_NUMBER:
            column_value = buf.read_oracle_number(num_bytes,
                                                  var_impl._preferred_num_type)
        elif ora_type_num == TNS_DATA_TYPE_DATE \
                or ora_type_num == TNS_DATA_TYPE_TIMESTAMP \
                or ora_type_num == TNS_DATA_TYPE_TIMESTAMP_LTZ \
                or ora_type_num == TNS_DATA_TYPE_TIMESTAMP_TZ:
            column_value = buf.read_oracle_date(num_bytes)
        elif ora_type_num == TNS_DATA_TYPE_ROWID:
            column_value = buf.read_rowid()
        elif ora_type_num == TNS_DATA_TYPE_UROWID:
            buf.skip_bytes(num_bytes)           # skip length
            temp_bytes = buf.read_bytes(buf.read_uint8())
            column_value = buf.read_urowid(temp_bytes)
        elif ora_type_num == TNS_DATA_TYPE_BINARY_DOUBLE:
            column_value = buf.read_binary_double()
        elif ora_type_num == TNS_DATA_TYPE_BINARY_FLOAT:
            column_value = buf.read_binary_float()
        elif ora_type_num == TNS_DATA_TYPE_BINARY_INTEGER:
            column_value = int(buf.read_oracle_number(num_bytes, NUM_TYPE_INT))
        elif ora_type_num == TNS_DATA_TYPE_CURSOR:
            if not self.in_fetch:
                column_value = var_impl.values[pos]
            column_value = self._create_cursor_from_describe(buf, column_value)
            cursor_impl = column_value._impl
            cursor_impl._statement._cursor_id = buf.read_ub4()
            cursor_impl._requires_full_execute = True
        elif ora_type_num == TNS_DATA_TYPE_BOOLEAN:
            column_value = buf.read_ub4() != 0
        elif ora_type_num == TNS_DATA_TYPE_INTERVAL_DS:
            column_value = buf.read_interval_ds(num_bytes)
        elif ora_type_num == TNS_DATA_TYPE_CLOB \
                or ora_type_num == TNS_DATA_TYPE_BLOB:
            buf.skip_bytes(1)
            temp_bytes = buf.read_bytes(buf.read_uint8())
            lob_impl = ThinLobImpl._create(self.conn_impl, var_impl.dbtype,
                                           temp_bytes)
            column_value = LOB._from_impl(lob_impl)
        else:
            msg = f"unhandled data type {var_impl.dbtype}"
            raise Exception(msg)
        if not self.in_fetch:
            actual_num_bytes = buf.read_ub4()
            if actual_num_bytes != 0 and column_value is not None:
                unit_type = "bytes" if isinstance(column_value, bytes) \
                            else "characters"
                message = f"column truncated to {len(column_value)} " \
                          f"{unit_type} (actual is {actual_num_bytes})"
                errors._raise_from_string(exceptions.DatabaseError, message)
        if var_impl._conv_func is not None:
            column_value = var_impl._conv_func(column_value)
        if var_impl.outconverter is not None:
            column_value = var_impl.outconverter(column_value)
        return column_value

    cdef FetchInfo _process_column_info(self, ReadBuffer buf,
                                        ThinCursorImpl cursor_impl):
        cdef:
            uint8_t data_type, csfrm
            uint32_t num_bytes
            FetchInfo fetch_info
        data_type = buf.read_uint8()
        fetch_info = FetchInfo()
        buf.read_uint8()                    # flags
        fetch_info._precision = buf.read_int8()
        if data_type == TNS_DATA_TYPE_NUMBER \
                or data_type == TNS_DATA_TYPE_INTERVAL_DS \
                or data_type == TNS_DATA_TYPE_TIMESTAMP \
                or data_type == TNS_DATA_TYPE_TIMESTAMP_LTZ \
                or data_type == TNS_DATA_TYPE_TIMESTAMP_TZ:
            fetch_info._scale = <int16_t> buf.read_oracle_int()
        else:
            fetch_info._scale = buf.read_int8()
        fetch_info._buffer_size = buf.read_ub4()
        buf.read_ub4()                      # max number of array elements
        buf.read_ub4()                      # cont flags
        num_bytes = buf.read_ub4()          # OID
        if num_bytes > 0:
            buf.skip_bytes(num_bytes + 1)
        buf.read_ub2()                      # version
        buf.read_ub2()                      # character set id
        csfrm = buf.read_uint8()            # character set form
        fetch_info._dbtype = DbType._from_ora_type_and_csfrm(data_type, csfrm)
        fetch_info._size = buf.read_ub4()
        if data_type == TNS_DATA_TYPE_RAW:
            fetch_info._size = fetch_info._buffer_size
        buf.read_ub4()                      # oaccolid
        fetch_info._nulls_allowed = buf.read_uint8()
        buf.skip_bytes(1)                   # v7 length of name
        num_bytes = buf.read_ub4()
        if num_bytes > 0:
            fetch_info._name = buf.read_str(buf.read_uint8())
        num_bytes = buf.read_ub4()
        if num_bytes > 0:
            buf.skip_bytes(1)               # skip repeated length
            buf.skip_bytes(num_bytes)       # schema name
        num_bytes = buf.read_ub4()
        if num_bytes > 0:
            buf.skip_bytes(1)               # skip repeated length
            buf.skip_bytes(num_bytes)       # type name
        buf.read_ub2()                      # column position
        buf.read_ub4()                      # uds flag
        return fetch_info

    cdef int _process_describe_info(self, ReadBuffer buf,
                                    object cursor) except -1:
        cdef:
            ThinCursorImpl cursor_impl = <ThinCursorImpl> cursor._impl
            uint32_t num_elements, num_bytes, num_columns, i
            object type_handler, var
            ThinVarImpl var_impl
            FetchInfo fetch_info
            bint nulls_allowed
            str message
        buf.read_ub4()                      # max row size
        num_columns = buf.read_ub4()
        cursor_impl.fetch_vars = cpython.PyList_New(num_columns)
        buf.skip_bytes(1)
        type_handler = cursor_impl.outputtypehandler \
                or cursor_impl._conn_impl.outputtypehandler
        num_elements = cursor_impl._fetch_array_size
        for i in range(num_columns):
            var = None
            fetch_info = self._process_column_info(buf, cursor_impl)
            if type_handler is not None:
                var = type_handler(cursor, fetch_info._name,
                                   fetch_info._dbtype, fetch_info._size,
                                   fetch_info._precision, fetch_info._scale)
                if var is not None:
                    if not isinstance(var, Var):
                        message = "Expecting cursor.var object from " \
                                  "outputtypehandler method"
                        errors._raise_from_string(TypeError, message)
                    var_impl = <ThinVarImpl> var._impl
                    if var_impl.dbtype is not fetch_info._dbtype:
                        conversion_helper(var_impl, fetch_info,
                                          &self.requires_define)
            if var is None:
                nulls_allowed = fetch_info._nulls_allowed
                var = cursor_impl.create_var(self.conn, fetch_info._dbtype,
                                             size=fetch_info._size,
                                             scale=fetch_info._scale,
                                             precision=fetch_info._precision,
                                             num_elements=num_elements,
                                             name=fetch_info._name,
                                             nulls_allowed=nulls_allowed,
                                             inconverter=None,
                                             outconverter=None,
                                             encoding_errors=None)
            var_impl = <ThinVarImpl> var._impl
            var_impl._fetch_info = fetch_info
            if fetch_info._dbtype._ora_type_num == TNS_DATA_TYPE_NUMBER \
                    and var_impl._preferred_num_type == NUM_TYPE_FLOAT:
                if fetch_info._scale == 0 or (fetch_info._scale == -127 \
                        and fetch_info._precision == 0):
                    var_impl._preferred_num_type = NUM_TYPE_INT
            cpython.Py_INCREF(var)
            cpython.PyList_SET_ITEM(cursor_impl.fetch_vars, i, var)
        num_bytes = buf.read_ub4()
        if num_bytes > 0:
            buf.skip_bytes(num_bytes + 1)   # current date
        buf.read_ub4()                      # dcbflag
        buf.read_ub4()                      # dcbmdbz
        buf.read_ub4()                      # dcbmnpr
        buf.read_ub4()                      # dcbmxpr
        num_bytes = buf.read_ub4()
        if num_bytes > 0:
            buf.skip_bytes(num_bytes + 1)   # dcbqcky
        cursor_impl._statement._fetch_vars = cursor_impl.fetch_vars

    cdef int _process_implicit_result(self, ReadBuffer buf) except -1:
        cdef:
            ThinCursorImpl child_cursor_impl
            object child_cursor
            uint8_t num_bytes
            uint32_t i
        self.cursor_impl._implicit_resultsets = []
        for i in range(buf.read_ub4()):
            num_bytes = buf.read_uint8()
            buf.skip_bytes(num_bytes)
            child_cursor = self._create_cursor_from_describe(buf)
            child_cursor_impl = child_cursor._impl
            child_cursor_impl._statement._cursor_id = buf.read_ub4()
            child_cursor_impl._is_implicit_cursor = True
            self.cursor_impl._implicit_resultsets.append(child_cursor)

    cdef int _process_io_vector(self, ReadBuffer buf) except -1:
        cdef:
            uint32_t i, temp, num_bytes
            BindInfo bind_info
        buf.skip_bytes(1)                   # flag
        temp = buf.read_ub2()               # num requests
        self.row_index = buf.read_ub4()     # iter num
        buf.read_ub4()                      # num iters this time
        buf.read_ub2()                      # uac buffer length
        num_bytes = buf.read_ub2()          # bit vector for fast fetch
        if num_bytes > 0:
            buf.skip_bytes(num_bytes)
        num_bytes = buf.read_ub2()          # rowid
        if num_bytes > 0:
            buf.skip_bytes(num_bytes)
        self.row_var_impls = []
        for i in range(temp):               # bind directions
            bind_info = self.cursor_impl._statement._bind_info_list[i]
            bind_info.bind_dir = buf.read_uint8()
            if bind_info.bind_dir == TNS_BIND_DIR_INPUT:
                continue
            self.row_var_impls.append(bind_info._bind_var._impl)

    cdef int _process_message(self, ReadBuffer buf,
                              uint8_t message_type) except -1:
        cdef ThinCursorImpl cursor_impl = self.cursor_impl
        if message_type == TNS_MSG_TYPE_ROW_HEADER:
            self._process_row_header(buf)
        elif message_type == TNS_MSG_TYPE_ROW_DATA:
            self._process_row_data(buf)
        elif message_type == TNS_MSG_TYPE_DESCRIBE_INFO:
            buf.skip_bytes(buf.read_uint8())
            self._process_describe_info(buf, self.cursor)
            self.row_var_impls = [v._impl for v in cursor_impl.fetch_vars]
        elif message_type == TNS_MSG_TYPE_ERROR:
            Message._process_error_info(self, buf)
            cursor_impl._statement._cursor_id = self.error_info.cursor_id
            cursor_impl.rowcount = self.error_info.rowcount
            if self.error_info.rowcount > 0:
                cursor_impl._lastrowid = self.error_info.rowid
            else:
                cursor_impl._lastrowid = None
            cursor_impl._batcherrors = self.error_info.batcherrors
            if self.error_info.num == TNS_ERR_NO_DATA_FOUND:
                self.error_info.num = 0
                cursor_impl._more_rows_to_fetch = False
            if self.error_info.batcherrors is not None:
                self.error_occurred = False
            self.processed_error = True
        elif message_type == TNS_MSG_TYPE_BIT_VECTOR:
            num_bits = buf.read_ub2()
            num_bytes = num_bits // 8
            if num_bits % 8 > 0:
                num_bytes += 1
            buf.skip_bytes(num_bytes)
        elif message_type == TNS_MSG_TYPE_IO_VECTOR:
            self._process_io_vector(buf)
        elif message_type == TNS_MSG_TYPE_SERVER_SIDE_PIGGYBACK:
            self._process_server_side_piggyback(buf)
        elif message_type == TNS_MSG_TYPE_IMPLICIT_RESULTSET:
            self._process_implicit_result(buf)
        else:
            Message._process_message(self, buf, message_type)

    cdef int _process_return_parameters(self, ReadBuffer buf) except -1:
        cdef:
            uint32_t num_params, num_bytes, i
            uint16_t keyword_num
            bytes key_value
        num_params = buf.read_ub2()         # al8o4l (ignored)
        for i in range(num_params):
            buf.read_ub4()
        num_bytes = buf.read_ub2()          # al8txl (ignored)
        if num_bytes > 0:
            buf.skip_bytes(num_bytes)
        num_params = buf.read_ub2()         # num key/value pairs
        for i in range(num_params):
            num_bytes = buf.read_ub2()      # key
            if num_bytes > 0:
                key_value = buf.read_bytes(buf.read_uint8())
            num_bytes = buf.read_ub2()      # value
            if num_bytes > 0:
                buf.read_bytes(buf.read_uint8())
            keyword_num = buf.read_ub2()    # keyword num
            if keyword_num == TNS_KEYWORD_NUM_CURRENT_SCHEMA:
                self.conn_impl._current_schema = key_value.decode()
            elif keyword_num == TNS_KEYWORD_NUM_EDITION:
                self.conn_impl._edition = key_value.decode()
        num_bytes = buf.read_ub4()          # registration
        if num_bytes > 0:
            buf.skip_bytes(num_bytes)
        if self.arraydmlrowcounts:
            self.cursor_impl._dmlrowcounts = \
                    [buf.read_ub8() for i in range(buf.read_ub4())]

    cdef int _process_row_data(self, ReadBuffer buf) except -1:
        cdef:
            uint32_t num_rows, pos
            ThinVarImpl var_impl
            BindInfo bind_info
            object value, var
            list values
            ssize_t i
        if self.cursor_impl._statement._is_returning:
            for bind_info in self.cursor_impl._statement._bind_info_list:
                if not bind_info._is_return_bind:
                    continue
                num_rows = buf.read_ub4()
                values = [None] * num_rows
                var = bind_info._bind_var
                var_impl = <ThinVarImpl> var._impl
                for j in range(num_rows):
                    values[j] = self._process_column_data(buf, var_impl, j)
                var_impl.values[self.row_index] = values
        else:
            for i, var_impl in enumerate(self.row_var_impls):
                if var_impl.is_array:
                    var_impl.num_elements_in_array = buf.read_ub4()
                    for pos in range(var_impl.num_elements_in_array):
                        value = self._process_column_data(buf, var_impl, pos)
                        var_impl.values[pos] = value
                else:
                    value = self._process_column_data(buf, var_impl,
                                                      self.row_index)
                    var_impl.values[self.row_index] = value
        self.row_index += 1
        if self.in_fetch:
            self.cursor_impl._buffer_rowcount = self.row_index

    cdef int _process_row_header(self, ReadBuffer buf) except -1:
        buf.skip_bytes(1)                   # flags
        buf.read_ub2()                      # num requests
        buf.read_ub4()                      # iteration number
        buf.read_ub4()                      # num iters
        buf.read_ub2()                      # buffer length
        num_bytes = buf.read_ub4()
        if num_bytes > 0:
            buf.skip_bytes(num_bytes + 1)   # rxhbvc
        num_bytes = buf.read_ub4()
        if num_bytes > 0:
            buf.skip_bytes(num_bytes + 1)   # rxhrid

    cdef int _process_server_side_piggyback(self, ReadBuffer buf) except -1:
        cdef:
            uint32_t num_bytes, num_elements, i
            uint8_t opcode
        opcode = buf.read_uint8()
        if opcode == TNS_SERVER_PIGGYBACK_LTXID:
            num_bytes = buf.read_ub4()
            if num_bytes > 0:
                buf.skip_bytes(num_bytes)
        elif opcode == TNS_SERVER_PIGGYBACK_QUERY_CACHE_INVALIDATION \
                or opcode == TNS_SERVER_PIGGYBACK_TRACE_EVENT:
            pass
        elif opcode == TNS_SERVER_PIGGYBACK_OS_PID_MTS:
            num_bytes = buf.read_ub2()
            buf.skip_bytes(num_bytes + 1)
        elif opcode == TNS_SERVER_PIGGYBACK_SYNC:
            buf.read_ub2()                  # skip number of DTYs
            buf.read_uint8()                # skip length of DTYs
            num_elements = buf.read_ub4()
            buf.skip_bytes(1)               # skip length
            for i in range(num_elements):
                num_bytes = buf.read_ub2()
                if num_bytes > 0:           # skip key
                    buf.skip_bytes(num_bytes + 1)
                num_bytes = buf.read_ub2()
                if num_bytes > 0:           # skip value
                    buf.skip_bytes(num_bytes + 1)
                buf.read_ub2()              # skip flags
            buf.read_ub4()                  # skip overall flags
        elif opcode == TNS_SERVER_PIGGYBACK_EXT_SYNC:
            buf.read_ub2()                  # skip number of DTYs
            buf.read_uint8()                # skip length of DTYs
        elif opcode == TNS_SERVER_PIGGYBACK_AC_REPLAY_CONTEXT:
            buf.read_ub2()                  # skip number of DTYs
            buf.read_uint8()                # skip length of DTYs
            buf.read_ub4()                  # skip flags
            buf.read_ub4()                  # skip error code
            buf.read_uint8()                # skip queue
            num_bytes = buf.read_ub4()      # skip replay context
            if num_bytes > 0:
                buf.skip_bytes(num_bytes)
        else:
            msg = f"Unhandled server side piggyback opcode: {opcode}"
            raise Exception(msg)

    cdef int _write_column_metadata(self, WriteBuffer buf,
                                    list bind_vars) except -1:
        cdef:
            uint8_t ora_type_num, flag
            ThinVarImpl var_impl
            object var

        # write parameter header information
        for var in bind_vars:
            var_impl = <ThinVarImpl> var._impl
            ora_type_num = var_impl.dbtype._ora_type_num
            flag = TNS_BIND_USE_INDICATORS | TNS_BIND_USE_LENGTH
            if var_impl.is_array:
                flag |= TNS_BIND_ARRAY
            buf.write_uint8(ora_type_num)
            buf.write_uint8(flag)
            buf.write_uint8(var_impl.precision)
            buf.write_uint8(var_impl.scale)
            if ora_type_num == TNS_DATA_TYPE_LONG \
                    or ora_type_num == TNS_DATA_TYPE_LONG_RAW:
                buf.write_ub4(TNS_MAX_LONG_LENGTH)
            else:
                buf.write_ub4(var_impl.buffer_size)
            if var_impl.is_array:
                buf.write_ub4(var_impl.num_elements)
            else:
                buf.write_ub4(0)            # max num elements
            buf.write_ub4(0)                # cont flag
            buf.write_ub4(0)                # OID
            buf.write_ub4(0)                # version
            buf.write_ub4(TNS_CHARSET_UTF8)
            buf.write_uint8(var_impl.dbtype._csfrm)
            buf.write_ub4(var_impl.size)
            buf.write_ub4(0)                # oaccolid

    cdef int _write_bind_params_column(self, WriteBuffer buf,
                                       ThinVarImpl var_impl,
                                       object value) except -1:
        cdef:
            uint8_t ora_type_num = var_impl.dbtype._ora_type_num
            ThinCursorImpl cursor_impl
            ThinLobImpl lob_impl
            uint8_t num_bytes
            bytes temp_bytes
        if value is None:
            if ora_type_num == TNS_DATA_TYPE_BOOLEAN:
                buf.write_uint8(TNS_ESCAPE_CHAR)
                buf.write_uint8(1)
            else:
                buf.write_uint8(0)
        elif ora_type_num == TNS_DATA_TYPE_VARCHAR \
                or ora_type_num == TNS_DATA_TYPE_CHAR \
                or ora_type_num == TNS_DATA_TYPE_LONG:
            if var_impl.dbtype._csfrm == 1:
                temp_bytes = value.encode()
            else:
                temp_bytes = value.encode(TNS_ENCODING_UTF16)
            buf.write_bytes_chunked(temp_bytes)
        elif ora_type_num == TNS_DATA_TYPE_RAW \
                or ora_type_num == TNS_DATA_TYPE_LONG_RAW:
            buf.write_bytes_chunked(value)
        elif ora_type_num == TNS_DATA_TYPE_NUMBER \
                or ora_type_num == TNS_DATA_TYPE_BINARY_INTEGER:
            if isinstance(value, bool):
                value = int(value)
            buf.write_oracle_number(str(value).encode())
        elif ora_type_num == TNS_DATA_TYPE_DATE \
                or ora_type_num == TNS_DATA_TYPE_TIMESTAMP \
                or ora_type_num == TNS_DATA_TYPE_TIMESTAMP_TZ \
                or ora_type_num == TNS_DATA_TYPE_TIMESTAMP_LTZ:
            buf.write_oracle_date(value, var_impl.dbtype._buffer_size_factor)
        elif ora_type_num == TNS_DATA_TYPE_BINARY_DOUBLE:
            buf.write_binary_double(value)
        elif ora_type_num == TNS_DATA_TYPE_BINARY_FLOAT:
            buf.write_binary_float(value)
        elif ora_type_num == TNS_DATA_TYPE_CURSOR:
            cursor_impl = value._impl
            if cursor_impl._statement is None:
                cursor_impl._statement = Statement()
            if cursor_impl._statement._cursor_id == 0:
                buf.write_uint8(1)
                buf.write_uint8(0)
            else:
                buf.write_ub4(1)
                buf.write_ub4(cursor_impl._statement._cursor_id)
        elif ora_type_num == TNS_DATA_TYPE_BOOLEAN:
            if value:
                buf.write_uint8(2)
                buf.write_uint16(0x0101)
            else:
                buf.write_uint16(0x0100)
        elif ora_type_num == TNS_DATA_TYPE_INTERVAL_DS:
            buf.write_interval_ds(value)
        elif ora_type_num == TNS_DATA_TYPE_CLOB \
                or ora_type_num == TNS_DATA_TYPE_BLOB:
            lob_impl = value._impl
            num_bytes = <uint8_t> len(lob_impl._locator)
            buf.write_ub4(num_bytes)
            buf.write_uint8(num_bytes)
            buf.write_bytes(lob_impl._locator)
        else:
            errors._raise_from_string(exceptions.NotSupportedError,
                                      f"unsupported type {var_impl.dbtype}")

    cdef int _write_bind_params_row(self, WriteBuffer buf, list params,
                                    uint32_t pos) except -1:
        cdef:
            uint32_t i, num_elements
            ThinVarImpl var_impl
            BindInfo bind_info
            object var
        for i, bind_info in enumerate(params):
            if bind_info._is_return_bind:
                continue
            var = bind_info._bind_var
            var_impl = <ThinVarImpl> var._impl
            if var_impl.is_array:
                num_elements = var_impl.num_elements_in_array
                buf.write_ub4(num_elements)
                for value in var_impl.values[:num_elements]:
                    self._write_bind_params_column(buf, var_impl, value)
            else:
                self._write_bind_params_column(buf, var_impl,
                                               var_impl.values[pos])

    cdef int _write_close_cursors_piggyback(self, WriteBuffer buf) except -1:
        cdef:
            unsigned int *cursor_ids
            ssize_t i
        buf.write_uint8(TNS_MSG_TYPE_PIGGYBACK)
        buf.write_uint8(TNS_FUNC_CLOSE_CURSORS)
        buf.write_seq_num()
        buf.write_uint8(1)                  # pointer
        buf.write_ub4(self.conn_impl._num_cursors_to_close)
        cursor_ids = self.conn_impl._cursors_to_close.data.as_uints
        for i in range(self.conn_impl._num_cursors_to_close):
            buf.write_ub4(cursor_ids[i])
        self.conn_impl._num_cursors_to_close = 0

    cdef int _write_current_schema_piggyback(self, WriteBuffer buf) except -1:
        cdef bytes schema_bytes
        buf.write_uint8(TNS_MSG_TYPE_PIGGYBACK)
        buf.write_uint8(TNS_FUNC_SET_SCHEMA)
        buf.write_seq_num()
        buf.write_uint8(1)                  # pointer
        schema_bytes = self.conn_impl._current_schema.encode()
        buf.write_ub4(len(schema_bytes))
        buf.write_bytes(schema_bytes)

    cdef int _write_end_to_end_piggyback(self, WriteBuffer buf) except -1:
        cdef:
            bytes action_bytes, client_identifier_bytes, client_info_bytes
            ThinConnImpl conn = self.conn_impl
            bytes module_bytes, dbop_bytes
            uint32_t flags = 0

        # determine which flags to send
        if conn._action_modified:
            flags |= TNS_END_TO_END_ACTION
        if conn._client_identifier_modified:
            flags |= TNS_END_TO_END_CLIENT_IDENTIFIER
        if conn._client_info_modified:
            flags |= TNS_END_TO_END_CLIENT_INFO
        if conn._module_modified:
            flags |= TNS_END_TO_END_MODULE
        if conn._dbop_modified:
            flags |= TNS_END_TO_END_DBOP

        # write initial packet data
        buf.write_uint8(TNS_MSG_TYPE_PIGGYBACK)
        buf.write_uint8(TNS_FUNC_SET_END_TO_END_ATTR)
        buf.write_seq_num()
        buf.write_uint8(0)                  # pointer (cidnam)
        buf.write_uint8(0)                  # pointer (cidser)
        buf.write_ub4(flags)

        # write client identifier header info
        if conn._client_identifier_modified:
            buf.write_uint8(1)              # pointer (client identifier)
            if conn._client_identifier is None:
                buf.write_ub4(0)
            else:
                client_identifier_bytes = conn._client_identifier.encode()
                buf.write_ub4(len(client_identifier_bytes))
        else:
            buf.write_uint8(0)              # pointer (client identifier)
            buf.write_ub4(0)                # length of client identifier

        # write module header info
        if conn._module_modified:
            buf.write_uint8(1)              # pointer (module)
            if conn._module is None:
                buf.write_ub4(0)
            else:
                module_bytes = conn._module.encode()
                buf.write_ub4(len(module_bytes))
        else:
            buf.write_uint8(0)              # pointer (module)
            buf.write_ub4(0)                # length of module

        # write action header info
        if conn._action_modified:
            buf.write_uint8(1)              # pointer (action)
            if conn._action is None:
                buf.write_ub4(0)
            else:
                action_bytes = conn._action.encode()
                buf.write_ub4(len(action_bytes))
        else:
            buf.write_uint8(0)              # pointer (action)
            buf.write_ub4(0)                # length of action

        # write unsupported bits
        buf.write_uint8(0)                  # pointer (cideci)
        buf.write_ub4(0)                    # length (cideci)
        buf.write_uint8(0)                  # cidcct
        buf.write_ub4(0)                    # cidecs

        # write client info header info
        if conn._client_info_modified:
            buf.write_uint8(1)              # pointer (client info)
            if conn._client_info is None:
                buf.write_ub4(0)
            else:
                client_info_bytes = conn._client_info.encode()
                buf.write_ub4(len(client_info_bytes))
        else:
            buf.write_uint8(0)              # pointer (client info)
            buf.write_ub4(0)                # length of client info

        # write more unsupported bits
        buf.write_uint8(0)                  # pointer (cidkstk)
        buf.write_ub4(0)                    # length (cidkstk)
        buf.write_uint8(0)                  # pointer (cidktgt)
        buf.write_ub4(0)                    # length (cidktgt)

        # write dbop header info
        if conn._dbop_modified:
            buf.write_uint8(1)              # pointer (dbop)
            if conn._dbop is None:
                buf.write_ub4(0)
            else:
                dbop_bytes = conn._dbop.encode()
                buf.write_ub4(len(dbop_bytes))
        else:
            buf.write_uint8(0)              # pointer (dbop)
            buf.write_ub4(0)                # length of dbop

        # write strings
        if conn._client_identifier_modified \
                and conn._client_identifier is not None:
            buf.write_bytes(client_identifier_bytes)
        if conn._module_modified and conn._module is not None:
            buf.write_bytes(module_bytes)
        if conn._action_modified and conn._action is not None:
            buf.write_bytes(action_bytes)
        if conn._client_info_modified and conn._client_info is not None:
            buf.write_bytes(client_info_bytes)
        if conn._dbop_modified and conn._dbop is not None:
            buf.write_bytes(dbop_bytes)

        # reset flags and values
        conn._action_modified = False
        conn._action = None
        conn._client_identifier_modified = False
        conn._client_identifier = None
        conn._client_info_modified = False
        conn._client_info = None
        conn._dbop_modified = False
        conn._dbop = None
        conn._module_modified = False
        conn._module = None

    cdef int _write_piggybacks(self, WriteBuffer buf) except -1:
        if self.conn_impl._current_schema_modified:
            self._write_current_schema_piggyback(buf)
        if self.conn_impl._num_cursors_to_close > 0:
            self._write_close_cursors_piggyback(buf)
        if self.conn_impl._action_modified \
                or self.conn_impl._client_identifier_modified \
                or self.conn_impl._client_info_modified \
                or self.conn_impl._dbop_modified \
                or self.conn_impl._module_modified:
            self._write_end_to_end_piggyback(buf)


@cython.final
cdef class AuthMessage(Message):
    cdef:
        ThinConnImpl conn_impl
        str encoded_password
        str password
        str session_key
        uint8_t user_bytes_len
        bytes user_bytes
        dict session_data
        uint32_t auth_mode

    def __cinit__(self, conn_impl, password):
        self.function_code = TNS_FUNC_AUTH_PHASE_ONE
        self.conn_impl = conn_impl
        self.session_data = {}
        self.password = password
        self.user_bytes = conn_impl.username.encode()
        self.user_bytes_len = <uint8_t> len(self.user_bytes)

    def _encrypt_cbc(self, key, plain_text):
        block_size = 16
        iv = bytes(block_size)
        algo = algorithms.AES(key)
        cipher = Cipher(algo, modes.CBC(iv))
        encryptor = cipher.encryptor()
        n = block_size - len(plain_text) % block_size
        if n:
            plain_text += (bytes([n]) * n)
        return encryptor.update(plain_text) + encryptor.finalize()

    cdef int _generate_auth_response(self) except -1:

        # create password hash
        verifier_data = bytes.fromhex(self.session_data['AUTH_VFR_DATA'])
        h = hashlib.sha1(self.password.encode())
        h.update(verifier_data)
        password_hash = h.digest() + b"\x00\x00\x00\x00"

        # encrypt client session key
        client_key = secrets.token_bytes(48)
        encoded_client_key = self._encrypt_cbc(password_hash, client_key)

        # decode server key
        encoded_server_key = bytes.fromhex(self.session_data['AUTH_SESSKEY'])
        iv = bytes(16)
        algo = algorithms.AES(password_hash)
        cipher = Cipher(algo, modes.CBC(iv))
        decryptor = cipher.decryptor()
        server_key = decryptor.update(encoded_server_key)

        # create combo key used for encrypting password
        b = bytearray(24)
        for i in range(16, 40):
            b[i - 16] = server_key[i] ^ client_key[i]
        part1 = hashlib.md5(b[:16]).digest()
        part2 = hashlib.md5(b[16:]).digest()
        combo_key = (part1 + part2)[:24]

        # encrypt password
        salt = secrets.token_bytes(16)
        password_with_salt = salt + self.password.encode()
        encoded_password = self._encrypt_cbc(combo_key, password_with_salt)
        self.encoded_password = encoded_password.hex().upper()
        self.session_key = encoded_client_key.hex().upper()[:96]

    cdef int _process_return_parameters(self, ReadBuffer buf) except -1:
        cdef:
            uint32_t num_bytes, full_version_num
            int port_update_num
            uint16_t num_params, i
            str key, value
        num_params = buf.read_ub2()
        for i in range(num_params):
            num_bytes = buf.read_ub4()
            key = buf.read_str(buf.read_uint8())
            num_bytes = buf.read_ub4()
            if num_bytes > 0:
                value = buf.read_str(buf.read_uint8())
            else:
                value = ""
            buf.read_ub4()                  # skip flags
            self.session_data[key] = value
        if self.function_code == TNS_FUNC_AUTH_PHASE_ONE:
            self.function_code = TNS_FUNC_AUTH_PHASE_TWO
        else:
            self.conn_impl._session_id = \
                    <uint32_t> int(self.session_data["AUTH_SESSION_ID"])
            self.conn_impl._serial_num = \
                    <uint32_t> int(self.session_data["AUTH_SERIAL_NUM"])
            full_version_num = int(self.session_data["AUTH_VERSION_NO"])
            self.conn_impl._server_version = "%d.%d.%d.%d.%d" % \
                    ((full_version_num >> 24) & 0xFF,
                     (full_version_num >> 16) & 0xFF,
                     (full_version_num >> 12) & 0x0F,
                     (full_version_num >> 4) & 0xFF,
                     (full_version_num & 0x0F))

    cdef int _set_auth_mode(self, uint32_t public_auth_mode) except -1:
        self.auth_mode = TNS_AUTH_MODE_LOGON
        if public_auth_mode & constants.AUTH_MODE_SYSDBA:
            self.auth_mode |= TNS_AUTH_MODE_SYSDBA
        if public_auth_mode & constants.AUTH_MODE_SYSOPER:
            self.auth_mode |= TNS_AUTH_MODE_SYSOPER
        if public_auth_mode & constants.AUTH_MODE_SYSASM:
            self.auth_mode |= TNS_AUTH_MODE_SYSASM
        if public_auth_mode & constants.AUTH_MODE_SYSBKP:
            self.auth_mode |= TNS_AUTH_MODE_SYSBKP
        if public_auth_mode & constants.AUTH_MODE_SYSDGD:
            self.auth_mode |= TNS_AUTH_MODE_SYSDGD
        if public_auth_mode & constants.AUTH_MODE_SYSKMT:
            self.auth_mode |= TNS_AUTH_MODE_SYSKMT
        if public_auth_mode & constants.AUTH_MODE_SYSRAC:
            self.auth_mode |= TNS_AUTH_MODE_SYSRAC

    cdef int _write_key_value(self, WriteBuffer buf, str key, str value,
                              uint32_t flags=0) except -1:
        cdef:
            bytes key_bytes = key.encode()
            bytes value_bytes = value.encode()
            uint8_t key_len = <uint8_t> len(key_bytes)
            uint8_t value_len = <uint8_t> len(value_bytes)
        buf.write_ub4(key_len)
        buf.write_uint8(key_len)
        buf.write_bytes(key_bytes)
        buf.write_ub4(value_len)
        if value_len > 0:
            buf.write_uint8(value_len)
            buf.write_bytes(value_bytes)
        buf.write_ub4(flags)

    cdef int _write_message(self, WriteBuffer buf) except -1:
        self._write_function_code(buf)
        buf.write_uint8(1)                  # pointer (authusr)
        buf.write_ub4(self.user_bytes_len)
        if self.function_code == TNS_FUNC_AUTH_PHASE_ONE:
            buf.write_ub4(self.auth_mode)   # authentication mode
            buf.write_uint8(1)              # pointer (authivl)
            buf.write_ub4(5)                # number of key/value pairs
            buf.write_uint8(0)              # pointer (authovl)
            buf.write_uint8(1)              # pointer (authovln)
            buf.write_bytes(self.user_bytes)
            self._write_key_value(buf, "AUTH_TERMINAL", "unknown")
            self._write_key_value(buf, "AUTH_PROGRAM_NM", sys.executable)
            self._write_key_value(buf, "AUTH_MACHINE", socket.gethostname())
            self._write_key_value(buf, "AUTH_PID", str(os.getpid()))
            self._write_key_value(buf, "AUTH_SID", getpass.getuser())
        else:
            self.auth_mode |= TNS_AUTH_MODE_WITH_PASSWORD
            self._generate_auth_response()
            buf.write_ub4(self.auth_mode)   # authentication mode
            buf.write_uint8(1)              # pointer (authivl)
            buf.write_ub4(4)                # number of key/value pairs
            buf.write_uint8(1)              # pointer (authovl)
            buf.write_uint8(1)              # pointer (authovln)
            buf.write_bytes(self.user_bytes)
            self._write_key_value(buf, "AUTH_SESSKEY", self.session_key, 1)
            self._write_key_value(buf, "AUTH_PASSWORD", self.encoded_password)
            self._write_key_value(buf, "SESSION_CLIENT_CHARSET", "873")
            self._write_key_value(buf, "SESSION_CLIENT_DRIVER_NAME",
                                  constants.DRIVER_NAME)


@cython.final
cdef class CommitMessage(Message):

    def __cinit__(self):
        self.function_code = TNS_FUNC_COMMIT


@cython.final
cdef class ConnectMessage(Message):
    cdef:
        uint16_t connect_string_len
        bytes connect_string_bytes
        str redirect_data
        bint first_packet

    def __cinit__(self, connect_string):
        self.connect_string_bytes = connect_string.encode()
        self.connect_string_len = <uint16_t> len(self.connect_string_bytes)
        self.first_packet = True

    cdef int process(self, ReadBuffer buf) except -1:
        cdef:
            const char_type *redirect_data
            uint16_t redirect_data_length
        if self.first_packet:
            if self.packet_type == TNS_PACKET_TYPE_REDIRECT:
                redirect_data_length = buf.read_uint16()
                buf.receive_packet(&self.packet_type)
                buf.skip_bytes(2)           # skip data flags
                redirect_data = buf._get_raw(redirect_data_length)
                self.redirect_data = \
                        redirect_data[:redirect_data_length].decode()
            self.first_packet = False
        else:
            buf._caps._adjust_for_protocol(buf.read_uint16(),
                                           buf.read_uint16())

    cdef int send(self, WriteBuffer buf) except -1:
        cdef uint16_t service_options = TNS_BASE_SERVICE_OPTIONS
        if buf._caps.can_use_oob:
            service_options |= TNS_CAN_RECV_ATTENTION
        buf.start_request(TNS_PACKET_TYPE_CONNECT)
        buf.write_uint16(TNS_VERSION_DESIRED)
        buf.write_uint16(TNS_VERSION_MINIMUM)
        buf.write_uint16(service_options)
        buf.write_uint16(TNS_SDU)
        buf.write_uint16(TNS_TDU)
        buf.write_uint16(TNS_PROTOCOL_CHARACTERISTICS)
        buf.write_uint16(0)                 # line turnaround
        buf.write_uint16(1)                 # value of 1
        buf.write_uint16(self.connect_string_len)
        buf.write_uint16(70)                # offset to connect data
        buf.write_uint32(0)                 # max receivable data
        buf.write_uint16(TNS_CONNECT_FLAGS)
        buf.write_uint64(0)                 # obsolete
        buf.write_uint64(0)                 # obsolete
        buf.write_uint64(0)                 # obsolete
        buf.write_uint32(TNS_SDU)           # SDU (large)
        buf.write_uint32(TNS_TDU)           # TDU (large)
        buf.write_uint32(0)                 # compression flags
        buf.write_bytes(self.connect_string_bytes)
        buf.end_request()


@cython.final
cdef class DataTypesMessage(Message):

    cdef int _write_message(self, WriteBuffer buf) except -1:
        cdef:
            DataType* data_type
            int i

        # write character set and capabilities
        buf.write_uint8(TNS_MSG_TYPE_DATA_TYPES)
        buf.write_uint16(TNS_CHARSET_UTF8, BYTE_ORDER_LSB)
        buf.write_uint16(TNS_CHARSET_UTF8, BYTE_ORDER_LSB)
        buf.write_ub4(len(buf._caps.compile_caps))
        buf.write_bytes(bytes(buf._caps.compile_caps))
        buf.write_uint8(len(buf._caps.runtime_caps))
        buf.write_bytes(bytes(buf._caps.runtime_caps))

        # write data types
        i = 0
        while True:
            data_type = &DATA_TYPES[i]
            if data_type.data_type == 0:
                break
            i += 1
            buf.write_uint16(data_type.data_type)
            buf.write_uint16(data_type.conv_data_type)
            buf.write_uint16(data_type.representation)
            buf.write_uint16(0)
        buf.write_uint16(0)

    cdef int process(self, ReadBuffer buf) except -1:
        pass


@cython.final
cdef class ExecuteMessage(MessageWithData):

    def __cinit__(self, cursor):
        self.function_code = TNS_FUNC_EXECUTE

    cdef int _write_message(self, WriteBuffer buf) except -1:
        cdef:
            uint32_t options, dml_options = 0, num_params = 0, num_iters = 1
            Statement stmt = self.cursor_impl._statement
            list params = stmt._bind_info_list

        # determine the options to use for the execute
        if self.requires_define:
            options = TNS_EXEC_OPTION_FETCH
            options |= TNS_EXEC_OPTION_DEFINE
            num_iters = self.cursor_impl.prefetchrows
        elif self.cursor_impl._requires_full_execute:
            options = TNS_EXEC_OPTION_FETCH
            options |= TNS_EXEC_OPTION_NO_COMPRESSED_FETCH
            num_iters = self.cursor_impl._fetch_array_size
        elif self.parse_only:
            options = TNS_EXEC_OPTION_PARSE
            if not stmt._is_plsql:
                options |= TNS_EXEC_OPTION_NOT_PLSQL
            if stmt._is_query:
                options |= TNS_EXEC_OPTION_DESCRIBE
        else:
            if params:
                num_params = <uint32_t> len(params)
            options = TNS_EXEC_OPTION_EXECUTE | \
                TNS_EXEC_OPTION_NO_COMPRESSED_FETCH
            dml_options = TNS_EXEC_OPTION_IMPLICIT_RESULTSET
            if stmt._cursor_id == 0:
                options |= TNS_EXEC_OPTION_PARSE
            if not stmt._is_plsql:
                options |= TNS_EXEC_OPTION_NOT_PLSQL
            elif num_params > 0:
                options |= TNS_EXEC_OPTION_PLSQL_BIND
            if stmt._is_query:
                if self.cursor_impl.prefetchrows > 0:
                    options |= TNS_EXEC_OPTION_FETCH
                num_iters = self.cursor_impl.prefetchrows
            if num_params > 0:
                options |= TNS_EXEC_OPTION_BIND
            if self.batcherrors:
                options |= TNS_EXEC_OPTION_BATCH_ERRORS
            if self.arraydmlrowcounts:
                dml_options = TNS_EXEC_OPTION_DML_ROWCOUNTS
            if self.conn_impl.autocommit:
                options |= TNS_EXEC_OPTION_COMMIT

        # write piggybacks, if needed
        self._write_piggybacks(buf)

        # write body of message
        self._write_function_code(buf)
        buf.write_ub4(options)              # execute options
        buf.write_ub4(stmt._cursor_id)      # cursor id
        if stmt._cursor_id == 0:
            buf.write_uint8(1)              # pointer (cursor id)
            buf.write_ub4(stmt._sql_bytes_length)
        else:
            buf.write_uint8(0)              # pointer (cursor id)
            buf.write_ub4(0)
        buf.write_uint8(1)                  # pointer (vector)
        buf.write_ub4(13)                   # al8i4 array length
        buf.write_uint8(0)                  # pointer (al8o4)
        buf.write_uint8(0)                  # pointer (al8o4l)
        buf.write_ub4(0)                    # prefetch buffer size
        buf.write_ub4(num_iters)            # prefetch number of rows
        buf.write_ub4(TNS_MAX_LONG_LENGTH)  # maximum long size
        if num_params == 0:
            buf.write_uint8(0)              # pointer (binds)
            buf.write_ub4(0)                # number of binds
        else:
            buf.write_uint8(1)              # pointer (binds)
            buf.write_ub4(num_params)       # number of binds
        buf.write_uint8(0)                  # pointer (al8app)
        buf.write_uint8(0)                  # pointer (al8txn)
        buf.write_uint8(0)                  # pointer (al8txl)
        buf.write_uint8(0)                  # pointer (al8kv)
        buf.write_uint8(0)                  # pointer (al8kvl)
        if self.requires_define:
            buf.write_uint8(1)              # pointer (al8doac)
            buf.write_ub4(len(self.cursor_impl.fetch_vars)) 
                                            # number of defines
        else:
            buf.write_uint8(0)
            buf.write_ub4(0)
        buf.write_ub4(0)                    # registration id
        buf.write_uint8(0)                  # pointer (al8objlist)
        buf.write_uint8(1)                  # pointer (al8objlen)
        buf.write_uint8(0)                  # pointer (al8blv)
        buf.write_ub4(0)                    # al8blvl
        buf.write_uint8(0)                  # pointer (al8dnam)
        buf.write_ub4(0)                    # al8dnaml
        buf.write_ub4(0)                    # al8regid_msb
        if self.arraydmlrowcounts:
            buf.write_uint8(1)              # pointer (al8pidmlrc)
            buf.write_ub4(self.num_execs)   # al8pidmlrcbl
            buf.write_uint8(1)              # pointer (al8pidmlrcl)
        else:
            buf.write_uint8(0)              # pointer (al8pidmlrc)
            buf.write_ub4(0)                # al8pidmlrcbl
            buf.write_uint8(0)              # pointer (al8pidmlrcl)
        buf.write_uint8(0)                  # pointer (al8sqlsig)
        buf.write_ub4(0)                    # SQL signature length
        buf.write_uint8(0)                  # pointer (SQL ID)
        buf.write_ub4(0)                    # allocated size of SQL ID
        buf.write_uint8(0)                  # pointer (length of SQL ID)
        if buf._caps.ttc_field_version >= TNS_CCAP_FIELD_VERSION_12_2_EXT1:
            buf.write_uint8(0)              # pointer (chunk ids)
            buf.write_ub4(0)                # number of chunk ids
        if stmt._cursor_id == 0:
            buf.write_bytes(stmt._sql_bytes)
            buf.write_ub4(1)                # al8i4[0] parse
        else:
            buf.write_ub4(0)                # al8i4[0] parse
        if stmt._is_query:
            if stmt._cursor_id == 0:
                buf.write_ub4(0)            # al8i4[1] execution count
            else:
                buf.write_ub4(num_iters)
        else:
            buf.write_ub4(self.num_execs)   # al8i4[1] execution count
        buf.write_ub4(0)                    # al8i4[2]
        buf.write_ub4(0)                    # al8i4[3]
        buf.write_ub4(0)                    # al8i4[4]
        buf.write_ub4(0)                    # al8i4[5] SCN (part 1)
        buf.write_ub4(0)                    # al8i4[6] SCN (part 2)
        buf.write_ub4(stmt._is_query)       # al8i4[7] is query
        buf.write_ub4(0)                    # al8i4[8]
        buf.write_ub4(dml_options)          # al8i4[9] DML row counts/implicit
        buf.write_ub4(0)                    # al8i4[10]
        buf.write_ub4(0)                    # al8i4[11]
        buf.write_ub4(0)                    # al8i4[12]
        if self.requires_define:
            self._write_column_metadata(buf, self.cursor_impl.fetch_vars)
        elif num_params > 0:
            self._write_bind_params(buf, params)


@cython.final
cdef class ReExecuteMessage(MessageWithData):

    def __cinit__(self, cursor):
        cdef ThinCursorImpl cursor_impl = self.cursor_impl
        if cursor_impl._statement._is_query and cursor_impl.prefetchrows > 0:
            self.function_code = TNS_FUNC_REEXECUTE_AND_FETCH
        else:
            self.function_code = TNS_FUNC_REEXECUTE

    cdef int _write_message(self, WriteBuffer buf) except -1:
        cdef:
            uint32_t i, exec_flags_1 = 0, exec_flags_2 = 0, num_iters
            Statement stmt = self.cursor_impl._statement
            list params = stmt._bind_info_list
            BindInfo bind_info

        if params:
            self.row_var_impls = [bind_info._bind_var._impl \
                                  for bind_info in stmt._bind_info_list \
                                  if bind_info.bind_dir != TNS_BIND_DIR_INPUT]
            params = [bind_info for bind_info in stmt._bind_info_list \
                      if bind_info.bind_dir != TNS_BIND_DIR_OUTPUT]
        if self.function_code == TNS_FUNC_REEXECUTE_AND_FETCH:
            exec_flags_1 |= TNS_EXEC_OPTION_EXECUTE | \
                            TNS_EXEC_OPTION_NO_COMPRESSED_FETCH
            num_iters = self.cursor.prefetchrows
        else:
            if self.cursor.connection.autocommit:
                exec_flags_2 |= TNS_EXEC_OPTION_COMMIT
            num_iters = self.num_execs

        self._write_piggybacks(buf)
        self._write_function_code(buf)
        buf.write_ub4(stmt._cursor_id)
        buf.write_ub4(num_iters)
        buf.write_ub4(exec_flags_1)
        buf.write_ub4(exec_flags_2)
        if params:
            for i in range(self.num_execs):
                buf.write_uint8(TNS_MSG_TYPE_ROW_DATA)
                self._write_bind_params_row(buf, params, i)


@cython.final
cdef class FetchMessage(MessageWithData):

    def __cinit__(self, cursor):
        self.function_code = TNS_FUNC_FETCH

    cdef int _write_message(self, WriteBuffer buf) except -1:
        self._write_function_code(buf)
        buf.write_ub4(self.cursor_impl._statement._cursor_id)
        buf.write_ub4(self.cursor_impl._fetch_array_size)


@cython.final
cdef class LobOpMessage(Message):
    cdef:
        uint32_t operation
        ThinLobImpl source_lob_impl
        ThinLobImpl dest_lob_impl
        uint64_t source_offset
        uint64_t dest_offset
        uint64_t amount
        bint send_amount
        bint bool_flag
        object data

    def __cinit__(self):
        self.function_code = TNS_FUNC_LOB_OP

    cdef int _process_message(self, ReadBuffer buf,
                              uint8_t message_type) except -1:
        cdef:
            bytes temp_bytes
            str encoding
        if message_type == TNS_MSG_TYPE_LOB_DATA:
            temp_bytes = buf.read_bytes(buf.read_uint8())
            if self.source_lob_impl.dbtype._ora_type_num == TNS_DATA_TYPE_BLOB:
                self.data = temp_bytes
            else:
                encoding = self.source_lob_impl._get_encoding()
                self.data = temp_bytes.decode(encoding)
        else:
            Message._process_message(self, buf, message_type)

    cdef int _process_return_parameters(self, ReadBuffer buf) except -1:
        cdef uint32_t temp_num
        if self.source_lob_impl is not None:
            temp_num = <uint32_t> len(self.source_lob_impl._locator)
            self.source_lob_impl._locator = buf.read_bytes(temp_num)
        if self.dest_lob_impl is not None:
            temp_num = <uint32_t> len(self.dest_lob_impl._locator)
            self.dest_lob_impl._locator = buf.read_bytes(temp_num)
        if self.operation == TNS_LOB_OP_CREATE_TEMP:
            buf.read_ub2()                  # skip character set
        if self.send_amount:
            self.amount = buf.read_ub8()
        if self.operation == TNS_LOB_OP_CREATE_TEMP \
                or self.operation == TNS_LOB_OP_IS_OPEN:
            self.bool_flag = buf.read_ub2() # flag

    cdef int _write_message(self, WriteBuffer buf) except -1:
        cdef int i
        self._write_function_code(buf)
        if self.source_lob_impl is None:
            buf.write_uint8(0)              # source pointer
            buf.write_ub4(0)                # source length
        else:
            buf.write_uint8(1)              # source pointer
            buf.write_ub4(len(self.source_lob_impl._locator))
        if self.dest_lob_impl is None:
            buf.write_uint8(0)              # dest pointer
            buf.write_ub4(0)                # dest length
        else:
            buf.write_uint8(1)              # dest pointer
            buf.write_ub4(len(self.dest_lob_impl._locator))
        buf.write_ub4(0)                    # short source offset
        buf.write_ub4(0)                    # short dest offset
        if self.operation == TNS_LOB_OP_CREATE_TEMP:
            buf.write_uint8(1)              # pointer (character set)
        else:
            buf.write_uint8(0)              # pointer (character set)
        buf.write_uint8(0)                  # pointer (amount)
        if self.operation == TNS_LOB_OP_CREATE_TEMP \
                or self.operation == TNS_LOB_OP_IS_OPEN:
            buf.write_uint8(1)              # pointer (NULL LOB)
        else:
            buf.write_uint8(0)              # pointer (NULL LOB)
        buf.write_ub4(self.operation)
        if self.operation == TNS_LOB_OP_CREATE_TEMP:
            buf.write_uint8(1)              # pointer (SCN array)
            buf.write_ub4(1)                # SCN array length
        else:
            buf.write_uint8(0)              # pointer (SCN array)
            buf.write_ub4(0)                # SCN array length
        buf.write_ub8(self.source_offset)
        buf.write_ub8(self.dest_offset)
        if self.send_amount:
            buf.write_uint8(1)              # pointer (amount)
        else:
            buf.write_uint8(0)              # pointer (amount)
        for i in range(3):                  # array LOB (not used)
            buf.write_uint16(0)
        if self.source_lob_impl is not None:
            buf.write_bytes(self.source_lob_impl._locator)
        if self.dest_lob_impl is not None:
            buf.write_bytes(self.dest_lob_impl._locator)
        if self.operation == TNS_LOB_OP_CREATE_TEMP:
            if self.source_lob_impl.dbtype._csfrm == TNS_CS_NCHAR:
                buf.write_ub4(TNS_CHARSET_UTF16)
            else:
                buf.write_ub4(TNS_CHARSET_UTF8)
        if self.send_amount:
            buf.write_ub8(self.amount)
        if self.data is not None:
            buf.write_uint8(TNS_MSG_TYPE_LOB_DATA)
            buf.write_bytes_chunked(self.data)
        if self.operation == TNS_LOB_OP_CREATE_TEMP:
            buf.write_ub4(0)                # SCN array element


@cython.final
cdef class LogoffMessage(Message):

    def __cinit__(self):
        self.function_code = TNS_FUNC_LOGOFF


@cython.final
cdef class NetworkServicesMessage(Message):

    cdef int _write_message(self, WriteBuffer buf) except -1:
        cdef:
            uint16_t packet_length
            NetworkService service

        # calculate length of packet
        packet_length = TNS_NETWORK_HEADER_SIZE
        for service in TNS_NETWORK_SERVICES:
            packet_length += service.get_data_size()

        # write header
        buf.write_uint32(TNS_NETWORK_MAGIC)
        buf.write_uint16(packet_length)
        buf.write_uint32(TNS_NETWORK_VERSION)
        buf.write_uint16(<uint16_t> len(TNS_NETWORK_SERVICES))
        buf.write_uint8(0)                  # flags

        # write service data
        for service in TNS_NETWORK_SERVICES:
            service.write_data(buf)

    cdef int process(self, ReadBuffer buf) except -1:
        pass


@cython.final
cdef class PingMessage(Message):

    def __cinit__(self):
        self.function_code = TNS_FUNC_PING


@cython.final
cdef class ProtocolMessage(Message):

    cdef int _write_message(self, WriteBuffer buf) except -1:
        buf.write_uint8(TNS_MSG_TYPE_PROTOCOL)
        buf.write_uint8(6)                  # protocol version (8.1 and higher)
        buf.write_uint8(0)                  # "array" terminator
        buf.write_bytes(b'py-oracledb\x00') # unique name for driver

    cdef int _process_message(self, ReadBuffer buf,
                              uint8_t message_type) except -1:
        cdef:
            uint16_t num_elem, fdo_length
            bytearray server_compile_caps
            bytearray server_runtime_caps
        if message_type == TNS_MSG_TYPE_PROTOCOL:
            buf.skip_bytes(2)               # skip protocol array
            while buf.read_uint8() != 0:    # skip server banner
                pass
            buf.skip_bytes(2)               # skip charset (LSB)
            buf.skip_bytes(1)               # skip server flags
            num_elem = buf.read_uint16(BYTE_ORDER_LSB)
            if num_elem > 0:                # skip elements
                buf.skip_bytes(num_elem * 5)
            fdo_length = buf.read_uint16()
            buf.skip_bytes(fdo_length)
            server_compile_caps = bytearray(buf.read_bytes(buf.read_uint8()))
            server_runtime_caps = bytearray(buf.read_bytes(buf.read_uint8()))
            buf._caps._adjust_for_server_compile_caps(server_compile_caps)
            buf._caps._adjust_for_server_runtime_caps(server_runtime_caps)
        else:
            Message._process_message(self, buf, message_type)


@cython.final
cdef class RollbackMessage(Message):

    def __cinit__(self):
        self.function_code = TNS_FUNC_ROLLBACK
