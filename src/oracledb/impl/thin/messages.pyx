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
        bint error_occurred

    def __cinit__(self):
        self.message_type = TNS_MSG_TYPE_FUNCTION
        self.error_info = _OracleErrorInfo()

    cdef int _preprocess(self) except -1:
        pass

    cdef int _process_error_info(self, ReadBuffer buf) except -1:
        cdef:
            _OracleErrorInfo info = self.error_info
            uint16_t num_entries, error_code
            uint32_t num_bytes, i
            uint8_t first_byte
            str error_msg
        buf.read_ub4()                      # end of call status
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

    cdef int _process_message(self, ReadBuffer buf,
                              uint8_t message_type) except -1:
        if message_type == TNS_MSG_TYPE_ERROR:
            self._process_error_info(buf)
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

    cdef int _write_function_code(self, WriteBuffer buf) except -1:
        buf.write_uint8(self.message_type)
        buf.write_uint8(self.function_code)
        buf.write_seq_num()

    cdef int _write_message(self, WriteBuffer buf) except -1:
        self._write_function_code(buf)

    cdef int process(self, ReadBuffer buf) except -1:
        self._preprocess()
        buf.skip_bytes(2)                   # skip data flags
        while buf.bytes_left() > 0:
            self._process_message(buf, buf.read_uint8())

    cdef int send(self, WriteBuffer buf) except -1:
        buf.start_request(TNS_PACKET_TYPE_DATA)
        self._write_message(buf)
        buf.end_request()


cdef class MessageWithData(Message):
    cdef:
        bint arraydmlrowcounts
        uint32_t row_index
        uint32_t num_execs
        list dmlrowcounts
        bint batcherrors
        Connection conn
        Cursor cursor
        list row_vars
        bint in_fetch

    def __cinit__(self, cursor):
        self.cursor = cursor
        self.conn = cursor.connection
        self.num_execs = 1

    cdef Cursor _create_cursor_from_describe(self, ReadBuffer buf,
                                             Cursor cursor=None):
        if cursor is None:
            cursor = Cursor(self.conn)
        cursor._statement = Statement()
        cursor._fetch_array_size = cursor.arraysize
        cursor._more_rows_to_fetch = True
        cursor._statement._is_query = True
        self._process_describe_info(buf, cursor)
        return cursor

    cdef int _preprocess(self) except -1:
        cdef Var var
        if self.cursor._statement._is_query:
            self.in_fetch = True
            self.row_vars = self.cursor._fetch_vars
            self.cursor._more_rows_to_fetch = True
            self.cursor._fetch_array_size = self.cursor.arraysize
            self.cursor._buffer_rowcount = self.cursor._buffer_index = 0
            if self.row_vars is not None:
                for var in self.row_vars:
                    if var.num_elements < self.cursor._fetch_array_size:
                        var.num_elements = self.cursor._fetch_array_size
                        var._finalize_init()

    cdef object _process_column_data(self, ReadBuffer buf, Var var,
                                     uint32_t pos):
        cdef:
            uint8_t num_bytes, ora_type_num, csfrm
            uint32_t actual_num_bytes
            Cursor cursor = None
            object column_value
            bytes temp_bytes
            Lob lob
        ora_type_num = var._dbtype._ora_type_num
        csfrm = var._dbtype._csfrm
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
                                                  var._preferred_num_type)
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
                cursor = var._values[pos]
            cursor = self._create_cursor_from_describe(buf, cursor)
            cursor._statement._cursor_id = buf.read_ub4()
            column_value = cursor
        elif ora_type_num == TNS_DATA_TYPE_BOOLEAN:
            column_value = buf.read_uint32() != 0
        elif ora_type_num == TNS_DATA_TYPE_INTERVAL_DS:
            column_value = buf.read_interval_ds(num_bytes)
        elif ora_type_num == TNS_DATA_TYPE_CLOB \
                or ora_type_num == TNS_DATA_TYPE_BLOB:
            lob = Lob()
            lob.type = var._dbtype
            num_bytes = buf.read_uint8()
            lob._connection = self.conn
            lob._locator = buf.read_bytes(buf.read_uint8())
            column_value = lob
        else:
            msg = f"unhandled data type {var.type}"
            raise Exception(msg)
        if not self.in_fetch:
            actual_num_bytes = buf.read_ub4()
            if actual_num_bytes != 0 and column_value is not None:
                unit_type = "bytes" if isinstance(column_value, bytes) \
                            else "characters"
                message = f"column truncated to {len(column_value)} " \
                          f"{unit_type} (actual is {actual_num_bytes})"
                errors._raise_from_string(exceptions.DatabaseError, message)
        return column_value

    cdef Var _process_column_info(self, ReadBuffer buf, Cursor cursor):
        cdef:
            uint8_t data_type, csfrm
            uint16_t charset_id
            uint32_t num_bytes
            Var var
        var = cursor._create_var()
        data_type = buf.read_uint8()
        buf.read_uint8()                    # flags
        var.precision = buf.read_uint8()
        if data_type == TNS_DATA_TYPE_NUMBER \
                or data_type == TNS_DATA_TYPE_INTERVAL_DS \
                or data_type == TNS_DATA_TYPE_TIMESTAMP \
                or data_type == TNS_DATA_TYPE_TIMESTAMP_LTZ \
                or data_type == TNS_DATA_TYPE_TIMESTAMP_TZ:
            var.scale = buf.read_ub2()
        else:
            var.scale = buf.read_int8()
        var.buffer_size = buf.read_ub4()
        buf.read_ub4()                      # max number of array elements
        buf.read_ub4()                      # cont flags
        num_bytes = buf.read_ub4()          # OID
        if num_bytes > 0:
            buf.skip_bytes(num_bytes + 1)
        buf.read_ub2()                      # version
        buf.read_ub2()                      # character set id
        csfrm = buf.read_uint8()            # character set form
        var._dbtype = DbType._from_ora_type_and_csfrm(data_type, csfrm)
        var.size = buf.read_ub4()
        if data_type == TNS_DATA_TYPE_RAW:
            var.size = var.buffer_size
        elif data_type == TNS_DATA_TYPE_NUMBER:
            if var.scale == 0 or (var.scale == -127 and var.precision == 0):
                var._preferred_num_type = NUM_TYPE_INT
        buf.read_ub4()                      # oaccolid
        var.nulls_allowed = buf.read_uint8()
        buf.skip_bytes(1)                   # v7 length of name
        num_bytes = buf.read_ub4()
        if num_bytes > 0:
            var.name = buf.read_str(buf.read_uint8())
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
        var.num_elements = cursor._fetch_array_size
        var._finalize_init()
        return var

    cdef int _process_describe_info(self, ReadBuffer buf,
                                    Cursor cursor) except -1:
        cdef uint32_t num_bytes, num_columns, i
        buf.read_ub4()                      # max row size
        num_columns = buf.read_ub4()
        cursor._fetch_vars = cpython.PyList_New(num_columns)
        buf.skip_bytes(1)
        for i in range(num_columns):
            var = self._process_column_info(buf, cursor)
            cpython.Py_INCREF(var)
            cpython.PyList_SET_ITEM(cursor._fetch_vars, i, var)
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
        cursor._statement._fetch_vars = cursor._fetch_vars

    cdef int _process_implicit_result(self, ReadBuffer buf) except -1:
        cdef:
            Cursor child_cursor
            uint8_t num_bytes
            uint32_t i
        self.cursor._implicit_resultsets = []
        for i in range(buf.read_ub4()):
            num_bytes = buf.read_uint8()
            buf.skip_bytes(num_bytes)
            child_cursor = self._create_cursor_from_describe(buf)
            child_cursor._statement._cursor_id = buf.read_ub4()
            self.cursor._implicit_resultsets.append(child_cursor)

    cdef int _process_io_vector(self, ReadBuffer buf) except -1:
        cdef:
            uint32_t i, temp, num_bytes
            BindInfo bind_info
            uint8_t bind_dir
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
        self.row_vars = []
        for i in range(temp):               # bind directions
            bind_dir = buf.read_uint8()
            if bind_dir == TNS_BIND_DIR_INPUT:
                continue
            bind_info = self.cursor._statement._bind_info_list[i]
            self.row_vars.append(bind_info._bind_var)

    cdef int _process_message(self, ReadBuffer buf,
                              uint8_t message_type) except -1:
        if message_type == TNS_MSG_TYPE_ROW_HEADER:
            self._process_row_header(buf)
        elif message_type == TNS_MSG_TYPE_ROW_DATA:
            self._process_row_data(buf)
        elif message_type == TNS_MSG_TYPE_DESCRIBE_INFO:
            buf.skip_bytes(buf.read_uint8())
            self._process_describe_info(buf, self.cursor)
            self.row_vars = self.cursor._fetch_vars
        elif message_type == TNS_MSG_TYPE_ERROR:
            Message._process_error_info(self, buf)
            self.cursor._statement._cursor_id = self.error_info.cursor_id
            self.cursor.rowcount = self.error_info.rowcount
            if self.error_info.rowcount > 0:
                self.cursor._lastrowid = self.error_info.rowid
            else:
                self.cursor._lastrowid = None
            self.cursor._batcherrors = self.error_info.batcherrors
            if self.error_info.num == TNS_ERR_NO_DATA_FOUND:
                self.error_info.num = 0
                self.cursor._more_rows_to_fetch = False
            if self.error_info.batcherrors is not None:
                self.error_occurred = False
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
        cdef uint32_t num_params, num_bytes, i
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
                buf.read_bytes(buf.read_uint8())
            num_bytes = buf.read_ub2()      # value
            if num_bytes > 0:
                buf.read_bytes(buf.read_uint8())
            buf.read_ub2()                  # keyword num
        num_bytes = buf.read_ub4()          # registration
        if num_bytes > 0:
            buf.skip_bytes(num_bytes)
        if self.arraydmlrowcounts:
            self.cursor._dmlrowcounts = \
                    [buf.read_ub8() for i in range(buf.read_ub4())]

    cdef int _process_row_data(self, ReadBuffer buf) except -1:
        cdef:
            uint32_t num_rows, pos
            BindInfo bind_info
            object value
            list values
            ssize_t i
            Var var
        if self.cursor._statement._is_returning:
            for bind_info in self.cursor._statement._bind_info_list:
                if not bind_info._is_return_bind:
                    continue
                num_rows = buf.read_ub4()
                values = [None] * num_rows
                for j in range(num_rows):
                    var = bind_info._bind_var
                    values[j] = self._process_column_data(buf, var, j)
                bind_info._bind_var._values[self.row_index] = values
        else:
            for i, var in enumerate(self.row_vars):
                if var.is_array:
                    var._num_elements_in_array = buf.read_ub4()
                    for pos in range(var._num_elements_in_array):
                        value = self._process_column_data(buf, var, pos)
                        var._values[pos] = value
                else:
                    value = self._process_column_data(buf, var, self.row_index)
                    var._values[self.row_index] = value
        self.row_index += 1
        if self.in_fetch:
            self.cursor._buffer_rowcount = self.row_index

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

    cdef int _write_bind_params(self, WriteBuffer buf, list params) except -1:
        cdef:
            uint8_t ora_type_num, flag
            bint returning_only
            BindInfo bind_info
            bytes temp_bytes
            object value
            uint32_t i
            Var var

        # write parameter header information
        returning_only = True
        for i, bind_info in enumerate(params):
            if not bind_info._is_return_bind:
                returning_only = False
            var = bind_info._bind_var
            flag = TNS_BIND_USE_INDICATORS | TNS_BIND_USE_LENGTH
            if var.is_array:
                flag |= TNS_BIND_ARRAY
            buf.write_uint8(var._dbtype._ora_type_num)
            buf.write_uint8(flag)
            buf.write_uint8(var.precision)
            buf.write_uint8(var.scale)
            buf.write_ub4(var.buffer_size)
            if var.is_array:
                buf.write_ub4(var.num_elements)
            else:
                buf.write_ub4(0)            # max num elements
            buf.write_ub4(0)                # cont flag
            buf.write_ub4(0)                # OID
            buf.write_ub4(0)                # version
            buf.write_ub4(TNS_CHARSET_UTF8)
            buf.write_uint8(var._dbtype._csfrm)
            buf.write_ub4(var.size)
            buf.write_ub4(0)                # oaccolid

        # write parameter values unless statement contains only returning binds
        if not returning_only:
            for i in range(self.num_execs):
                buf.write_uint8(TNS_MSG_TYPE_ROW_DATA)
                self._write_bind_params_row(buf, params, i)

    cdef int _write_bind_params_column(self, WriteBuffer buf, Var var,
                                       object value) except -1:
        cdef:
            uint8_t ora_type_num = var._dbtype._ora_type_num
            uint8_t num_bytes
            bytes temp_bytes
            Cursor cursor
            Lob lob
        if value is None:
            buf.write_uint8(0)
        elif ora_type_num == TNS_DATA_TYPE_VARCHAR \
                or ora_type_num == TNS_DATA_TYPE_CHAR \
                or ora_type_num == TNS_DATA_TYPE_LONG:
            if var._dbtype._csfrm == 1:
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
            buf.write_oracle_date(value, var._dbtype._buffer_size_factor)
        elif ora_type_num == TNS_DATA_TYPE_BINARY_DOUBLE:
            buf.write_binary_double(value)
        elif ora_type_num == TNS_DATA_TYPE_BINARY_FLOAT:
            buf.write_binary_float(value)
        elif ora_type_num == TNS_DATA_TYPE_CURSOR:
            cursor = <Cursor> value
            if cursor._statement is None:
                cursor._statement = Statement()
            if cursor._statement._cursor_id == 0:
                buf.write_uint8(1)
                buf.write_uint8(0)
            else:
                buf.write_ub4(1)
                buf.write_ub4(cursor._statement._cursor_id)
        elif ora_type_num == TNS_DATA_TYPE_BOOLEAN:
            if value:
                buf.write_uint16(0x0101)
            else:
                buf.write_uint16(0x0100)
        elif ora_type_num == TNS_DATA_TYPE_INTERVAL_DS:
            buf.write_interval_ds(value)
        elif ora_type_num == TNS_DATA_TYPE_CLOB \
                or ora_type_num == TNS_DATA_TYPE_BLOB:
            lob = <Lob> value
            num_bytes = <uint8_t> len(lob._locator)
            buf.write_ub4(num_bytes)
            buf.write_uint8(num_bytes)
            buf.write_bytes(lob._locator)
        else:
            errors._raise_from_string(exceptions.NotSupportedError,
                                      f"unsupported type {var.type}")

    cdef int _write_bind_params_row(self, WriteBuffer buf, list params,
                                    uint32_t pos) except -1:
        cdef:
            uint32_t i, num_elements
            BindInfo bind_info
            Var var
        for i, bind_info in enumerate(params):
            if bind_info._is_return_bind:
                continue
            var = bind_info._bind_var
            if var.is_array:
                num_elements = var._num_elements_in_array
                buf.write_ub4(num_elements)
                for value in var._values[:num_elements]:
                    self._write_bind_params_column(buf, var, value)
            else:
                self._write_bind_params_column(buf, var, var._values[pos])

    cdef int _write_end_to_end_piggyback(self, WriteBuffer buf) except -1:
        cdef:
            bytes action_bytes, client_identifier_bytes, client_info_bytes
            bytes module_bytes, dbop_bytes
            Connection conn = self.conn
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


@cython.final
cdef class AuthMessage(Message):
    cdef:
        Connection conn
        str encoded_password
        str password
        str session_key
        uint8_t user_bytes_len
        bytes user_bytes
        dict session_data

    def __cinit__(self, conn, password):
        self.function_code = TNS_FUNC_AUTH_PHASE_ONE
        self.conn = conn
        self.session_data = {}
        self.password = password
        self.user_bytes = conn.username.encode()
        self.user_bytes_len = <uint8_t> len(self.user_bytes)

    def _encrypt_cbc(self, key, plain_text):
        iv = bytes(AES.block_size)
        b = AES.new(key, AES.MODE_CBC, iv)
        n = AES.block_size - len(plain_text) % AES.block_size
        if n:
            plain_text += (bytes([n]) * n)
        return b.encrypt(plain_text)

    cdef int _generate_auth_response(self) except -1:

        # create password hash
        verifier_data = bytes.fromhex(self.session_data['AUTH_VFR_DATA'])
        h = hashlib.sha1(self.password.encode())
        h.update(verifier_data)
        password_hash = h.digest() + b"\x00\x00\x00\x00"

        # encrypt client session key
        client_key = b'\x08' * 48
        encoded_client_key = self._encrypt_cbc(password_hash, client_key)

        # decode server key
        encoded_server_key = bytes.fromhex(self.session_data['AUTH_SESSKEY'])
        b = AES.new(password_hash, AES.MODE_CBC, b"\x00" * AES.block_size)
        server_key = b.decrypt(encoded_server_key)

        # create combo key used for encrypting password
        b = bytearray(24)
        for i in range(16, 40):
            b[i - 16] = server_key[i] ^ client_key[i]
        part1 = hashlib.md5(b[:16]).digest()
        part2 = hashlib.md5(b[16:]).digest()
        combo_key = (part1 + part2)[:24]

        # encrypt password
        salt = bytes.fromhex("4C31AFE05F3B012C0AE9AB0CDFF0C508")
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
            self.conn._session_id = \
                    <uint32_t> int(self.session_data["AUTH_SESSION_ID"])
            self.conn._serial_num = \
                    <uint32_t> int(self.session_data["AUTH_SERIAL_NUM"])
            full_version_num = int(self.session_data["AUTH_VERSION_NO"])
            self.conn._server_version = "%d.%d.%d.%d.%d" % \
                    ((full_version_num >> 24) & 0xFF,
                     (full_version_num >> 16) & 0xFF,
                     (full_version_num >> 12) & 0x0F,
                     (full_version_num >> 4) & 0xFF,
                     (full_version_num & 0x0F))

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
            buf.write_ub4(1)                # authentication mode
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
            self._generate_auth_response()
            buf.write_ub4(257)              # authentication mode
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
        bint first_packet

    def __cinit__(self, connect_string):
        self.connect_string_bytes = connect_string.encode()
        self.connect_string_len = <uint16_t> len(self.connect_string_bytes)
        self.first_packet = True

    cdef int process(self, ReadBuffer buf) except -1:
        if self.first_packet:
            self.first_packet = False
        else:
            buf._caps.protocol_version = buf.read_uint16()

    cdef int send(self, WriteBuffer buf) except -1:
        buf.start_request(TNS_PACKET_TYPE_CONNECT)
        buf.write_uint16(TNS_VERSION_DESIRED)
        buf.write_uint16(TNS_VERSION_MINIMUM)
        buf.write_uint16(TNS_SERVICE_OPTIONS)
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
            Statement stmt = self.cursor._statement
            list params = stmt._bind_info_list

        # determine the options to use for the execute
        if params:
            num_params = <uint32_t> len(params)
        options = TNS_EXEC_OPTION_EXECUTE | TNS_EXEC_OPTION_NO_COMPRESSED_FETCH
        dml_options = TNS_EXEC_OPTION_IMPLICIT_RESULTSET
        if stmt._cursor_id == 0:
            options |= TNS_EXEC_OPTION_PARSE
        if not stmt._is_plsql:
            options |= TNS_EXEC_OPTION_NOT_PLSQL
        elif num_params > 0:
            options |= TNS_EXEC_OPTION_PLSQL_BIND
        if stmt._is_query:
            if self.cursor.prefetchrows > 0:
                options |= TNS_EXEC_OPTION_FETCH
            num_iters = self.cursor.prefetchrows
        if num_params > 0:
            options |= TNS_EXEC_OPTION_BIND
        if self.batcherrors:
            options |= TNS_EXEC_OPTION_BATCH_ERRORS
        if self.arraydmlrowcounts:
            dml_options = TNS_EXEC_OPTION_DML_ROWCOUNTS
        if self.cursor.connection.autocommit:
            options |= TNS_EXEC_OPTION_COMMIT

        # write end to end attribute piggyback if needed
        if self.conn._action_modified \
                or self.conn._client_identifier_modified \
                or self.conn._client_info_modified \
                or self.conn._dbop_modified \
                or self.conn._module_modified:
            self._write_end_to_end_piggyback(buf)

        # write body of message
        self._write_function_code(buf)
        buf.write_ub4(options)              # execute options
        buf.write_ub4(stmt._cursor_id)
        buf.write_uint8(1)                  # pointer (cursor id)
        buf.write_ub4(stmt._sql_bytes_length)
        buf.write_uint8(1)                  # pointer (vector)
        buf.write_ub4(13)                   # al8i4 array length
        buf.write_uint8(0)                  # pointer (al8o4)
        buf.write_uint8(0)                  # pointer (al8o4l)
        buf.write_ub4(0)                    # prefetch buffer size
        buf.write_ub4(num_iters)            # prefetch number of rows
        buf.write_ub4(0x7fffffff)           # maximum long size
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
        buf.write_uint8(0)                  # pointer (al8doac)
        buf.write_ub4(0)                    # number of defines
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
        buf.write_bytes(stmt._sql_bytes)
        buf.write_ub4(1)                    # al8i4[0] parse
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
        if num_params > 0:
            self._write_bind_params(buf, params)


@cython.final
cdef class FetchMessage(MessageWithData):

    def __cinit__(self, cursor):
        self.function_code = TNS_FUNC_FETCH

    cdef int _write_message(self, WriteBuffer buf) except -1:
        self._write_function_code(buf)
        buf.write_ub4(self.cursor._statement._cursor_id)
        buf.write_ub4(self.cursor._fetch_array_size)


@cython.final
cdef class LobOpMessage(Message):
    cdef:
        uint32_t operation
        Lob source_lob
        Lob dest_lob
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
        cdef bytes temp_bytes
        if message_type == TNS_MSG_TYPE_LOB_DATA:
            temp_bytes = buf.read_bytes(buf.read_uint8())
            if self.source_lob.type._ora_type_num == TNS_DATA_TYPE_BLOB:
                self.data = temp_bytes
            else:
                self.data = temp_bytes.decode(TNS_ENCODING_UTF16)
        else:
            Message._process_message(self, buf, message_type)

    cdef int _process_return_parameters(self, ReadBuffer buf) except -1:
        cdef uint32_t temp_num
        if self.source_lob is not None:
            temp_num = <uint32_t> len(self.source_lob._locator)
            self.source_lob._locator = buf.read_bytes(temp_num)
        if self.dest_lob is not None:
            temp_num = <uint32_t> len(self.dest_lob._locator)
            self.dest_lob._locator = buf.read_bytes(temp_num)
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
        if self.source_lob is None:
            buf.write_uint8(0)              # source pointer
            buf.write_ub4(0)                # source length
        else:
            buf.write_uint8(1)              # source pointer
            buf.write_ub4(len(self.source_lob._locator))
        if self.dest_lob is None:
            buf.write_uint8(0)              # dest pointer
            buf.write_ub4(0)                # dest length
        else:
            buf.write_uint8(1)              # dest pointer
            buf.write_ub4(len(self.dest_lob._locator))
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
        if self.source_lob is not None:
            buf.write_bytes(self.source_lob._locator)
        if self.dest_lob is not None:
            buf.write_bytes(self.dest_lob._locator)
        if self.operation == TNS_LOB_OP_CREATE_TEMP:
            if self.source_lob.type._csfrm == TNS_CS_NCHAR:
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
