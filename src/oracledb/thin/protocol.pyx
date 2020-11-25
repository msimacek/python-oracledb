#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

DEF SDU = 8192
DEF TDU = 65535

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
        list dmlrowcounts


cdef class Protocol:

    cdef:
        uint32_t _session_id, _serial_num
        uint8_t _seq_num
        str _server_version
        object _socket
        ReadBuffer _read_buf
        WriteBuffer _write_buf
        ChunkedBytesBuffer _chunked_bytes_buf
        _OracleErrorInfo _error_info

    def __init__(self, sock):
        self._seq_num = 3
        self._socket = sock
        self._read_buf = ReadBuffer(sock, SDU)
        self._write_buf = WriteBuffer(sock, SDU)
        self._chunked_bytes_buf = ChunkedBytesBuffer()

    cdef int _close(self) except -1:

        # send close request
        self._write_buf.start_request(TNS_PACKET_TYPE_DATA)
        self._write_buf.write_uint32(0x00000309)
        self._increment_seq_num()
        self._write_buf.write_uint8(self._seq_num)
        self._write_buf.end_request()

        # receive response
        self._receive_packet()

        # send final close
        self._write_buf.start_request(TNS_PACKET_TYPE_DATA)
        self._write_buf.write_uint16(0x0040)
        self._write_buf.end_request()
        self._socket.close()

    cdef int _commit(self) except -1:

        # send request
        self._write_buf.start_request(TNS_PACKET_TYPE_DATA)
        self._write_buf.write_uint32(0x0000030e)
        self._increment_seq_num()
        self._write_buf.write_uint8(self._seq_num)
        self._write_buf.end_request()

        # receive response
        self._receive_packet()

    def _connect(self, params):
        cdef:
            bytes user_bytes = params.user.encode()
            uint8_t user_len = <uint8_t> len(user_bytes)
            WriteBuffer buf = self._write_buf

        # send connect packet and receive response (which requests the packet
        # to be resent)
        self._send_connect_packet(params.connect_string)
        self._receive_packet()

        # resend connect packet and receive response
        self._send_connect_packet(params.connect_string)
        self._receive_packet()
        self._process_accept_packet()

        # send services packet and receive response
        self._send_services_packet()
        self._receive_packet()

        # send protocol packet
        buf.start_request(TNS_PACKET_TYPE_DATA)
        buf.start_request(TNS_PACKET_TYPE_DATA)
        buf.write_bytes(b'\x00\x00\x01\x06\x00')
        buf.write_bytes(b'Python_Thin\x00')
        buf.end_request()

        # receive response (server protocol)
        self._receive_packet()

        # send data types packet
        buf.start_request(TNS_PACKET_TYPE_DATA)
        buf.write_bytes(TNS_DATA_TYPES_PACKET_DATA)
        buf.end_request()

        # receive response (server data type support)
        self._receive_packet()

        # send session key packet
        buf.start_request(TNS_PACKET_TYPE_DATA)
        buf.write_bytes(b'\x00\x00\x03\x76\x02')
        buf.write_uint8(1)                  # pointer (authusr)
        buf.write_ub4(user_len)             # length of user name
        buf.write_ub4(1)                    # authentication mode
        buf.write_uint8(1)                  # pointer (authivl)
        buf.write_ub4(5)                    # number of key/value pairs
        buf.write_uint8(0)                  # pointer (authovl)
        buf.write_uint8(1)                  # pointer (authovln)
        buf.write_bytes(user_bytes)         # user name
        self._populate_key_value("AUTH_TERMINAL", "pts/2", 0)
        self._populate_key_value("AUTH_PROGRAM_NM",
                                 "python3.8@atc (TNS V1-V3)", 0)
        self._populate_key_value("AUTH_MACHINE", "atc", 0)
        self._populate_key_value("AUTH_PID", "83274", 0)
        self._populate_key_value("AUTH_SID", "anthony", 0)
        buf.end_request()

        # receive response (session key packet)
        self._receive_packet()
        params.session_data = {}
        self._process_session_data_packet(params)

        # send authorization packet
        buf.start_request(TNS_PACKET_TYPE_DATA)
        password, session_key = self._generate_auth_response(params)
        buf.write_bytes(b'\x00\x00\x03\x73\x03')
        buf.write_uint8(1)                  # pointer (authusr)
        buf.write_ub4(user_len)
        buf.write_ub4(257)                  # authentication mode
        buf.write_uint8(1)                  # pointer (authivl)
        buf.write_ub4(4)                    # number of key/value pairs
        buf.write_uint8(1)                  # pointer (authovl)
        buf.write_uint8(1)                  # pointer (authovln)
        buf.write_bytes(user_bytes)
        self._populate_key_value("AUTH_SESSKEY", session_key, 1)
        self._populate_key_value("AUTH_PASSWORD", password, 0)
        self._populate_key_value("SESSION_CLIENT_CHARSET", "873", 0)
        self._populate_key_value("SESSION_CLIENT_DRIVER_NAME",
                                 constants.DRIVER_NAME, 0)
        buf.end_request()

        # receive response (session data packet)
        self._receive_packet()
        self._process_session_data_packet(params)

    def _encrypt_cbc(self, key, plain_text):
        iv = b"\x00" * AES.block_size
        b = AES.new(key, AES.MODE_CBC, iv)
        n = AES.block_size - len(plain_text) % AES.block_size
        if n:
            plain_text += (bytes([n]) * n)
        return b.encrypt(plain_text)

    cdef int _execute(self, Cursor cursor, uint32_t fetch_array_size,
                      list params, uint32_t num_execs=1,
                      bint arraydmlrowcounts=False,
                      bint batcherrors=False) except -1:

        # send execute packet
        self._write_buf.start_request(TNS_PACKET_TYPE_DATA)
        self._populate_execute_packet(cursor, fetch_array_size, num_execs,
                                      params, arraydmlrowcounts, batcherrors)
        self._write_buf.end_request()

        # receive and process response
        self._error_info = _OracleErrorInfo()
        self._receive_packet(cursor, arraydmlrowcounts)
        if self._error_info.batcherrors is None:
            self._process_execute_packet(cursor, arraydmlrowcounts, num_execs)

    cdef int _fetch(self, Cursor cursor, uint32_t fetch_array_size) except -1:
        cdef WriteBuffer buf = self._write_buf

        # send fetch request
        buf.start_request(TNS_PACKET_TYPE_DATA)
        cursor._buffer_rowcount = 0
        cursor._buffer_index = 0
        buf.write_uint32(0x00000305)
        self._increment_seq_num()
        buf.write_uint8(self._seq_num)
        buf.write_ub4(cursor._statement._cursor_id)
        buf.write_ub4(fetch_array_size)
        buf.end_request()

        # receive and process response
        self._receive_packet()
        self._process_execute_packet(cursor)

    cdef _generate_auth_response(self, object params):

        # create password hash
        verifier_data = bytes.fromhex(params.session_data['AUTH_VFR_DATA'])
        h = hashlib.sha1(params.password.encode())
        h.update(verifier_data)
        password_hash = h.digest() + b"\x00\x00\x00\x00"

        # encrypt client session key
        client_key = b'\x08' * 48
        encoded_client_key = self._encrypt_cbc(password_hash, client_key)

        # decode server key
        encoded_server_key = bytes.fromhex(params.session_data['AUTH_SESSKEY'])
        b = AES.new(password_hash, AES.MODE_CBC, b"\x00" * AES.block_size)
        server_key = b.decrypt(encoded_server_key)

        # create combo key used for encrypting password
        b = bytearray(24)
        for i in range (16, 40):
            b[i - 16] = server_key[i] ^ client_key[i]
        part1 = hashlib.md5(b[:16]).digest()
        part2 = hashlib.md5(b[16:]).digest()
        combo_key = (part1 + part2)[:24]

        # encrypt password
        salt = bytes.fromhex("4C31AFE05F3B012C0AE9AB0CDFF0C508")
        password_with_salt = salt + params.password.encode()
        encoded_password = self._encrypt_cbc(combo_key, password_with_salt)

        # store results in session data for transmission to the server
        return (encoded_password.hex().upper(),
                encoded_client_key.hex().upper()[:96])

    cdef int _handle_error(self) except -1:
        cdef WriteBuffer buf = self._write_buf
        buf.start_request(TNS_PACKET_TYPE_MARKER)
        buf.write_bytes(b'\x01\x00\x02')
        buf.end_request()
        self._receive_packet()
        self._process_error_packet()

    cdef _increment_seq_num(self):
        self._seq_num += 1
        if self._seq_num == 0:
            self._seq_num = 1

    cdef int _send_connect_packet(self, object connect_string) except -1:
        cdef:
            WriteBuffer buf = self._write_buf
            uint16_t connect_string_length
            bytes connect_string_bytes
        buf.start_request(TNS_PACKET_TYPE_CONNECT)
        connect_string_bytes = connect_string.encode()
        connect_string_length = <uint16_t> len(connect_string_bytes)
        buf.write_uint16(TNS_VERSION_DESIRED)
        buf.write_uint16(TNS_VERSION_MINIMUM)
        buf.write_uint16(0xc41)             # service options
        buf.write_uint16(SDU)               # SDU
        buf.write_uint16(TDU)               # TDU
        buf.write_uint16(0x7f08)            # protocol characteristics
        buf.write_uint16(0)                 # line turnaround
        buf.write_uint16(1)                 # value of 1
        buf.write_uint16(connect_string_length)
        buf.write_uint16(70)                # offset to connect data
        buf.write_uint32(0)                 # max receivable data
        buf.write_uint16(0x4141)            # connect flags
        buf.write_uint64(0)                 # obsolete
        buf.write_uint64(0)                 # obsolete
        buf.write_uint64(0)                 # obsolete
        buf.write_uint32(SDU)               # SDU (large)
        buf.write_uint32(TDU)               # TDU (large)
        buf.write_uint32(0)                 # compression flags
        buf.write_bytes(connect_string_bytes)
        buf.end_request()

    cdef int _send_services_packet(self) except -1:
        cdef:
            WriteBuffer buf = self._write_buf
            uint16_t packet_length
            NetworkService service

        # calculate length of packet
        packet_length = TNS_NETWORK_HEADER_SIZE
        for service in TNS_NETWORK_SERVICES:
            packet_length += service.get_data_size()

        # write header
        buf.start_request(TNS_PACKET_TYPE_DATA)
        buf.write_uint16(0)                 # data flags
        buf.write_uint32(TNS_NETWORK_MAGIC)
        buf.write_uint16(packet_length)
        buf.write_uint32(TNS_NETWORK_VERSION)
        buf.write_uint16(<uint16_t> len(TNS_NETWORK_SERVICES))
        buf.write_uint8(0)                  # flags

        # write service data
        for service in TNS_NETWORK_SERVICES:
            service.write_data(buf)
        buf.end_request()

    cdef int _populate_execute_packet(self, Cursor cursor,
                                      uint32_t fetch_array_size,
                                      uint32_t num_execs, list params,
                                      bint arraydmlrowcounts,
                                      bint batcherrors) except -1:
        cdef:
            uint32_t options, dml_options = 0, num_params = 0, num_iters = 1
            WriteBuffer buf = self._write_buf
            Statement stmt

        # determine the options to use for the execute
        stmt = cursor._statement
        if params:
            num_params = <uint32_t> len(params)
        options = TNS_EXEC_OPTION_EXECUTE
        if stmt._cursor_id == 0:
            options |= TNS_EXEC_OPTION_PARSE
        if not stmt._is_plsql:
            options |= TNS_EXEC_OPTION_NOT_PLSQL
        elif num_params > 0:
            options |= TNS_EXEC_OPTION_PLSQL_BIND
        if stmt._is_query:
            options |= TNS_EXEC_OPTION_FETCH
            num_iters = fetch_array_size
        if num_params > 0:
            options |= TNS_EXEC_OPTION_BIND
        if batcherrors:
            options |= TNS_EXEC_OPTION_BATCH_ERRORS
        if arraydmlrowcounts:
            dml_options = TNS_EXEC_OPTION_DML_ROWCOUNTS

        # write packet
        buf.write_uint16(0)                 # data flags
        buf.write_uint16(0x35e)             # function code
        self._increment_seq_num()
        buf.write_uint8(self._seq_num)
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
        if arraydmlrowcounts:
            buf.write_uint8(1)              # pointer (al8pidmlrc)
            buf.write_ub4(num_execs)        # al8pidmlrcbl
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
        buf.write_bytes(stmt._sql_bytes)
        buf.write_ub4(1)                    # al8i4[0] parse
        if stmt._is_query:
            buf.write_ub4(0)                # al8i4[1] execution count
        else:
            buf.write_ub4(num_execs)        # al8i4[1] execution count
        buf.write_ub4(0)                    # al8i4[2]
        buf.write_ub4(0)                    # al8i4[3]
        buf.write_ub4(0)                    # al8i4[4]
        buf.write_ub4(0)                    # al8i4[5] SCN (part 1)
        buf.write_ub4(0)                    # al8i4[6] SCN (part 2)
        buf.write_ub4(stmt._is_query)       # al8i4[7] is query
        buf.write_ub4(0)                    # al8i4[8]
        if arraydmlrowcounts:
            buf.write_ub4(dml_options)      # al8i4[9] DML row counts/implicit
        else:
            buf.write_ub4(0)                # al8i4[9] DML row counts/implicit
        buf.write_ub4(0)                    # al8i4[10]
        buf.write_ub4(0)                    # al8i4[11]
        buf.write_ub4(0)                    # al8i4[12]
        if num_params > 0:
            self._populate_bind_params(buf, params, num_execs)

    cdef int _ping(self) except -1:

        # send request
        self._write_buf.start_request(TNS_PACKET_TYPE_DATA)
        self._write_buf.write_uint32(0x00000393)
        self._increment_seq_num()
        self._write_buf.write_uint8(self._seq_num)
        self._write_buf.end_request()

        # receive response
        self._receive_packet()

    cdef int _populate_bind_params(self, WriteBuffer buf, list params,
                                   uint32_t num_execs) except -1:
        cdef:
            uint32_t i, num_params = <uint32_t> len(params)
            uint8_t ora_type_num, flag
            BindInfo bind_info
            bytes temp_bytes
            object value
            Var var

        # write parameter header information
        for i in range(num_params):
            bind_info = <BindInfo> cpython.PyList_GET_ITEM(params, i)
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
            buf.write_ub4(873)              # character set id
            buf.write_uint8(var._dbtype._csfrm)
            buf.write_ub4(var.size)
            buf.write_ub4(0)                # oaccolid

        # write parameter values
        for i in range(num_execs):
            buf.write_uint8(7)              # data indicator
            self._populate_bind_params_row(buf, params, i)

    cdef int _populate_bind_params_row(self, WriteBuffer buf, list params,
                                       uint32_t pos) except -1:
        cdef:
            uint32_t i, num_elements, num_params = <uint32_t> len(params)
            BindInfo bind_info
            Var var
        for i in range(num_params):
            bind_info = <BindInfo> cpython.PyList_GET_ITEM(params, i)
            var = bind_info._bind_var
            if var.is_array:
                num_elements = var._num_elements_in_array
                buf.write_ub4(num_elements)
                for value in var._values[:num_elements]:
                    self._populate_bind_value(buf, var, value)
            else:
                self._populate_bind_value(buf, var, var._values[pos])

    cdef int _populate_bind_value(self, WriteBuffer buf, Var var,
                                  object value) except -1:
        cdef:
            uint8_t ora_type_num = var._dbtype._ora_type_num
            bytes temp_bytes
        if value is None:
            buf.write_uint8(0)
        elif ora_type_num == TNS_DATA_TYPE_VARCHAR \
                or ora_type_num == TNS_DATA_TYPE_CHAR \
                or ora_type_num == TNS_DATA_TYPE_LONG:
            if var._dbtype._csfrm == 1:
                temp_bytes = value.encode()
            else:
                temp_bytes = value.encode("UTF-16BE")
            self._write_bytes(temp_bytes)
        elif ora_type_num == TNS_DATA_TYPE_RAW \
                or ora_type_num == TNS_DATA_TYPE_LONG_RAW:
            self._write_bytes(value)
        elif ora_type_num == TNS_DATA_TYPE_NUMBER:
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
        else:
            errors._raise_from_string(exceptions.NotSupportedError,
                                      f"unsupported type {var.type}")

    cdef int _populate_fetch_packet(self, WriteBuffer buf, Cursor cursor,
                                    list params,
                                    uint32_t fetch_array_size) except -1:
        cursor._buffer_rowcount = 0
        cursor._buffer_index = 0
        buf.write_uint32(0x00000305)
        self._increment_seq_num()
        buf.write_uint8(self._seq_num)
        buf.write_ub4(cursor._statement._cursor_id)
        buf.write_ub4(fetch_array_size)

    cdef int _populate_key_value(self, str key, str value,
                                 uint32_t flags) except -1:
        cdef:
            bytes key_bytes = key.encode()
            bytes value_bytes = value.encode()
            uint8_t key_len = <uint8_t> cpython.PyBytes_GET_SIZE(key_bytes)
            uint8_t value_len = <uint8_t> cpython.PyBytes_GET_SIZE(value_bytes)
            WriteBuffer buf = self._write_buf
        buf.write_ub4(key_len)
        buf.write_uint8(key_len)
        buf.write_bytes(key_bytes)
        buf.write_ub4(value_len)
        if value_len > 0:
            buf.write_uint8(value_len)
            buf.write_bytes(value_bytes)
        buf.write_ub4(flags)

    cdef int _populate_marker_packet(self, WriteBuffer buf,
                                     object params) except -1:
        buf.write_uint8(1)
        buf.write_uint8(0)
        buf.write_uint8(2)

    cdef int _populate_protocol_packet(self, WriteBuffer buf,
                                       object params) except -1:
        buf.write_bytes(b'\x00\x00\x01\x06\x00')
        buf.write_bytes(b'Python_Thin\x00')

    cdef int _process_accept_packet(self) except -1:
        cdef:
            ReadBuffer buf = self._read_buf
            uint16_t version
        version = buf.read_uint16()
        self._read_buf._protocol_version = version
        self._write_buf._protocol_version = version

    cdef Var _process_column_info(self, Cursor cursor, ReadBuffer buf):
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
        buf.read_ub4()                      # oaccolid
        var.nulls_allowed = buf.read_uint8()
        buf.skip_bytes(1)                   # v7 length of name
        num_bytes = buf.read_ub4()
        if num_bytes > 0:
            buf.skip_bytes(1)               # skip repeated length
            var.name = buf.read_str(num_bytes)
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

    cdef int _process_error_info(self, ReadBuffer buf) except -1:
        cdef:
            uint16_t num_entries, error_code, message_length
            _OracleErrorInfo info = self._error_info
            const char_type *message
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
            self._read_bytes(buf.read_uint8())

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
                        self._read_bytes(buf.read_uint8()).decode().rstrip()
                buf.skip_bytes(2)           # ignore end marker

        info.num = buf.read_ub4()           # error number (extended)
        info.rowcount = buf.read_ub8()      # row number (extended)
        if info.num != 0:
            message_length = buf.read_uint8()
            message = buf._get_raw(message_length)
            info.message = message[:message_length].decode()

    cdef int _process_error_packet(self) except -1:
        cdef:
            ReadBuffer buf = self._read_buf
            uint8_t num_bytes, message_type
        buf.skip_bytes(2)                   # skip data flag
        while buf.bytes_left() > 0:
            message_type = buf.read_uint8()
            if message_type == TNS_MSG_TYPE_PARAMETER:
                self._process_msg_parameter(buf)
            elif message_type == TNS_MSG_TYPE_ERROR:
                self._process_error_info(buf)
            else:
                errors._raise_from_string(exceptions.DatabaseError,
                                          "TTC error: expecting error packet")

    cdef int _process_execute_packet(self, Cursor cursor,
                                     bint arraydmlrowcounts=False,
                                     uint32_t num_execs=1) except -1:
        cdef:
            uint32_t num_columns, num_bytes, i, temp, row_index
            ReadBuffer buf = self._read_buf
            uint8_t message_type, bind_dir
            bint in_fetch = False
            BindInfo bind_info
            uint16_t num_bits
            Statement stmt
            list row_vars
            Var var
        buf.skip_bytes(2)
        stmt = cursor._statement
        if cursor._statement._is_query:
            row_vars = cursor._fetch_vars
            cursor._more_rows_to_fetch = True
            cursor._fetch_array_size = cursor.arraysize
            row_index = cursor._buffer_rowcount = cursor._buffer_index = 0
            in_fetch = True
            if row_vars is not None:
                for var in row_vars:
                    if var.num_elements < cursor._fetch_array_size:
                        var.num_elements = cursor._fetch_array_size
                        var._finalize_init()
        if arraydmlrowcounts:
            self._error_info.dmlrowcounts = []
        while buf.bytes_left() > 0:
            message_type = buf.read_uint8()
            if message_type == TNS_MSG_TYPE_DESCRIBE_INFO:
                num_bytes = buf.read_uint8()
                buf.skip_bytes(num_bytes)
                buf.read_ub4()              # max row size
                num_columns = buf.read_ub4()
                row_vars = cursor._fetch_vars = cpython.PyList_New(num_columns)
                buf.skip_bytes(1)
                for i in range(num_columns):
                    var = self._process_column_info(cursor, buf)
                    cpython.Py_INCREF(var)
                    cpython.PyList_SET_ITEM(cursor._fetch_vars, i, var)
                num_bytes = buf.read_ub4()
                if num_bytes > 0:
                    buf.skip_bytes(num_bytes + 1)   # current date
                buf.read_ub4()              # dcbflag
                buf.read_ub4()              # dcbmdbz
                buf.read_ub4()              # dcbmnpr
                buf.read_ub4()              # dcbmxpr
                num_bytes = buf.read_ub4()
                if num_bytes > 0:
                    buf.skip_bytes(num_bytes + 1)   # dcbqcky
                cursor._statement._fetch_vars = cursor._fetch_vars
            elif message_type == TNS_MSG_TYPE_ROW_HEADER:
                buf.skip_bytes(1)           # flags
                buf.read_ub2()              # num requests
                buf.read_ub4()              # iteration number
                buf.read_ub4()              # num iters
                buf.read_ub2()              # buffer length
                num_bytes = buf.read_ub4()
                if num_bytes > 0:
                    buf.skip_bytes(num_bytes + 1)   # rxhbvc
                num_bytes = buf.read_ub4()
                if num_bytes > 0:
                    buf.skip_bytes(num_bytes + 1)   # rxhrid
            elif message_type == TNS_MSG_TYPE_IO_VECTOR:
                buf.skip_bytes(1)           # flag
                temp = buf.read_ub2()       # num requests
                row_index = buf.read_ub4()  # iter num
                buf.read_ub4()              # num iters this time
                buf.read_ub2()              # uac buffer length
                num_bytes = buf.read_ub2()  # bit vector for fast fetch
                if num_bytes > 0:
                    buf.skip_bytes(num_bytes)
                num_bytes = buf.read_ub2()  # rowid
                if num_bytes > 0:
                    buf.skip_bytes(num_bytes)
                row_vars = []
                for i in range(temp):       # bind directions
                    bind_dir = buf.read_uint8()
                    if bind_dir == TNS_BIND_DIR_INPUT:
                        continue
                    bind_info = stmt._bind_info_list[i]
                    row_vars.append(bind_info._bind_var)
            elif message_type == TNS_MSG_TYPE_ROW_DATA:
                self._process_row(buf, row_vars, row_index, in_fetch)
                if in_fetch:
                    cursor._buffer_rowcount += 1
                    row_index = cursor._buffer_rowcount
            elif message_type == TNS_MSG_TYPE_BIT_VECTOR:
                num_bits = buf.read_ub2()
                num_bytes = num_bits // 8
                if num_bits % 8 > 0:
                    num_bytes += 1
                buf.skip_bytes(num_bytes)
            elif message_type == TNS_MSG_TYPE_PARAMETER:
                self._process_msg_parameter(buf)
                cursor._dmlrowcounts = self._error_info.dmlrowcounts
            elif message_type == TNS_MSG_TYPE_ERROR:
                self._process_error_info(buf)
                stmt._cursor_id = self._error_info.cursor_id
                cursor.rowcount = self._error_info.rowcount
                cursor._lastrowid = self._error_info.rowid
                if self._error_info.num == 1403:
                    cursor._more_rows_to_fetch = False
            elif message_type == TNS_MSG_TYPE_SERVER_SIDE_PIGGYBACK:
                self._process_server_side_piggyback()
            else:
                msg = f"unknown message type: {message_type}"
                errors._raise_from_string(exceptions.InternalError, msg)

    cdef int _process_msg_parameter(self, ReadBuffer buf) except -1:
        cdef:
            _OracleErrorInfo error_info = self._error_info
            uint32_t num_params, num_bytes, i
        num_params = buf.read_ub2()         # al8o4l (ignored)
        for i in range(num_params):
            buf.read_ub4()
        num_bytes = buf.read_ub2()          # al8txl (ignored)
        if num_bytes > 0:
            buf.skip_bytes(num_bytes)
        buf.read_ub2()                      # num key/val pairs
        num_bytes = buf.read_ub4()          # registration
        if num_bytes > 0:
            buf.skip_bytes(num_bytes)
        if error_info.dmlrowcounts is not None:
            for i in range(buf.read_ub4()):
                error_info.dmlrowcounts.append(buf.read_ub8())

    cdef int _process_row(self, ReadBuffer buf, list row_vars,
                          uint32_t row_index, bint in_fetch) except -1:
        cdef:
            uint8_t num_bytes, ora_type_num, csfrm
            object column_value
            bytes temp_bytes
            uint32_t pos
            ssize_t i
            Var var
        for i, var in enumerate(row_vars):
            if var.is_array:
                var._num_elements_in_array = buf.read_ub4()
                for pos in range(var._num_elements_in_array):
                    var._values[pos] = self._process_row_data(buf, var,
                                                              in_fetch)
            else:
                var._values[row_index] = self._process_row_data(buf, var,
                                                                in_fetch)

    cdef object _process_row_data(self, ReadBuffer buf, Var var,
                                  bint in_fetch):
        cdef:
            uint8_t num_bytes, ora_type_num, csfrm
            object column_value
            bytes temp_bytes
        ora_type_num = var._dbtype._ora_type_num
        csfrm = var._dbtype._csfrm
        num_bytes = buf.read_uint8()
        if num_bytes == 0:
            column_value = None
        elif ora_type_num == TNS_DATA_TYPE_VARCHAR \
                or ora_type_num == TNS_DATA_TYPE_CHAR \
                or ora_type_num == TNS_DATA_TYPE_LONG:
            temp_bytes = self._read_bytes(num_bytes)
            if csfrm == 1:
                column_value = temp_bytes.decode()
            else:
                column_value = temp_bytes.decode("UTF-16BE")
            if ora_type_num == TNS_DATA_TYPE_LONG:
                buf.skip_bytes(2)
        elif ora_type_num == TNS_DATA_TYPE_RAW \
                or ora_type_num == TNS_DATA_TYPE_LONG_RAW:
            column_value = self._read_bytes(num_bytes)
            if ora_type_num == TNS_DATA_TYPE_LONG_RAW:
                buf.skip_bytes(2)
        elif ora_type_num == TNS_DATA_TYPE_NUMBER:
            column_value = buf.read_oracle_number(num_bytes)
        elif ora_type_num == TNS_DATA_TYPE_DATE \
                or ora_type_num == TNS_DATA_TYPE_TIMESTAMP \
                or ora_type_num == TNS_DATA_TYPE_TIMESTAMP_LTZ \
                or ora_type_num == TNS_DATA_TYPE_TIMESTAMP_TZ:
            column_value = buf.read_oracle_date(num_bytes)
        elif ora_type_num == TNS_DATA_TYPE_ROWID:
            column_value = buf.read_rowid()
        elif ora_type_num == TNS_DATA_TYPE_UROWID:
            buf.skip_bytes(num_bytes)           # skip length
            temp_bytes = self._read_bytes(buf.read_uint8())
            column_value = buf.read_urowid(temp_bytes)
        elif ora_type_num == TNS_DATA_TYPE_BINARY_DOUBLE:
            column_value = buf.read_binary_double()
        elif ora_type_num == TNS_DATA_TYPE_BINARY_FLOAT:
            column_value = buf.read_binary_float()
        else:
            msg = f"unhandled data type {var.type}"
            raise Exception(msg)
        if not in_fetch:
            buf.skip_bytes(1)           # skip trailing zero byte
        return column_value

    cdef int _process_server_side_piggyback(self) except -1:
        cdef:
            uint32_t num_bytes, num_elements, i
            ReadBuffer buf = self._read_buf
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
            buf.read_ub2()              # skip number of DTYs
            buf.read_uint8()            # skip length of DTYs
            num_elements = buf.read_ub4()
            buf.skip_bytes(1)           # skip length
            for i in range(num_elements):
                num_bytes = buf.read_ub2()
                if num_bytes > 0:       # skip key
                    buf.skip_bytes(num_bytes + 1)
                num_bytes = buf.read_ub2()
                if num_bytes > 0:       # skip value
                    buf.skip_bytes(num_bytes + 1)
                buf.read_ub2()          # skip flags
            buf.read_ub4()              # skip overall flags
        elif opcode == TNS_SERVER_PIGGYBACK_EXT_SYNC:
            buf.read_ub2()              # skip number of DTYs
            buf.read_uint8()            # skip length of DTYs
        elif opcode == TNS_SERVER_PIGGYBACK_AC_REPLAY_CONTEXT:
            buf.read_ub2()              # skip number of DTYs
            buf.read_uint8()            # skip length of DTYs
            buf.read_ub4()              # skip flags
            buf.read_ub4()              # skip error code
            buf.read_uint8()            # skip queue
            num_bytes = buf.read_ub4()  # skip replay context
            if num_bytes > 0:
                buf.skip_bytes(num_bytes)
        else:
            msg = f"Unhandled server side piggyback opcode: {opcode}"
            raise Exception(msg)

    cdef int _process_session_data_packet(self, object params) except -1:
        cdef:
            int version_num, release_num, update_num, port_release_num
            uint32_t num_bytes, flags, full_version_num
            int port_update_num
            uint16_t num_params
            ReadBuffer buf
            str key, value
        buf = self._read_buf
        buf.skip_bytes(3)               # skip data flag, data id
        num_params = buf.read_ub2()
        for i in range(num_params):
            num_bytes = buf.read_ub4()
            buf.skip_bytes(1)           # skip redundant length
            key = buf.read_str(num_bytes)
            num_bytes = buf.read_ub4()
            if num_bytes > 0:
                buf.skip_bytes(1)           # skip redundant length
                value = buf.read_str(num_bytes)
            else:
                value = ""
            flags = buf.read_ub4()
            params.session_data[key] = value
        if "AUTH_SESSION_ID" in params.session_data:
            self._session_id = \
                    <uint32_t> int(params.session_data["AUTH_SESSION_ID"])
            self._serial_num = \
                    <uint32_t> int(params.session_data["AUTH_SERIAL_NUM"])
            full_version_num = int(params.session_data["AUTH_VERSION_NO"])
            self._server_version = "%d.%d.%d.%d.%d" % \
                    ((full_version_num >> 24) & 0xFF,
                     (full_version_num >> 16) & 0xFF,
                     (full_version_num >> 12) & 0x0F,
                     (full_version_num >> 4) & 0xFF,
                     (full_version_num & 0x0F))

    cdef bytes _read_bytes(self, uint32_t num_bytes):
        cdef:
            ReadBuffer buf = self._read_buf
            const char_type *source_ptr
            uint32_t num_bytes_left
            char_type *dest_ptr
        if num_bytes != TNS_LONG_LENGTH_INDICATOR:
            num_bytes_left = <uint32_t> buf.bytes_left()
            if num_bytes < num_bytes_left:
                return buf.read_bytes(num_bytes)
            self._chunked_bytes_buf.start_chunked_read()
            self._read_split_bytes(num_bytes_left, num_bytes - num_bytes_left)
            return self._chunked_bytes_buf.end_chunked_read()
        self._chunked_bytes_buf.start_chunked_read()
        while True:
            num_bytes = buf.read_ub4()
            if num_bytes == 0:
                break
            num_bytes_left = <uint32_t> buf.bytes_left()
            if num_bytes < num_bytes_left:
                source_ptr = buf._get_raw(num_bytes)
                dest_ptr = self._chunked_bytes_buf.get_chunk_ptr(num_bytes)
                memcpy(dest_ptr, source_ptr, num_bytes)
            else:
                self._read_split_bytes(num_bytes_left,
                                       num_bytes - num_bytes_left)
        return self._chunked_bytes_buf.end_chunked_read()

    cdef int _read_split_bytes(self, uint32_t num_bytes_1,
                               uint32_t num_bytes_2) except -1:
        cdef:
            const char_type *source_ptr
            char_type *dest_ptr
        dest_ptr = self._chunked_bytes_buf.get_chunk_ptr(num_bytes_1)
        source_ptr = self._read_buf._get_raw(num_bytes_1)
        memcpy(dest_ptr, source_ptr, num_bytes_1)
        self._receive_packet()
        self._read_buf.skip_bytes(2)
        dest_ptr = self._chunked_bytes_buf.get_chunk_ptr(num_bytes_2)
        source_ptr = self._read_buf._get_raw(num_bytes_2)
        memcpy(dest_ptr, source_ptr, num_bytes_2)

    cdef int _receive_packet(self, Cursor cursor=None,
                             bint arraydmlrowcounts=False) except -1:
        cdef uint8_t packet_type
        self._read_buf.receive_packet(&packet_type)
        if packet_type == TNS_PACKET_TYPE_MARKER:
            # on error a second packet is sent which is ignored
            self._read_buf.receive_packet(&packet_type)
            self._error_info = _OracleErrorInfo()
            if arraydmlrowcounts:
                self._error_info.dmlrowcounts = []
            self._handle_error()
            if cursor is not None:
                cursor.rowcount = self._error_info.rowcount
                cursor._batcherrors = self._error_info.batcherrors
                cursor._dmlrowcounts = self._error_info.dmlrowcounts
            if self._error_info.batcherrors is None:
                error = errors._Error(self._error_info.message,
                                      code=self._error_info.num,
                                      offset=self._error_info.pos)
                exc_type = get_exception_class(self._error_info.num)
                raise exc_type(error)

    cdef int _rollback(self) except -1:

        # send request
        self._write_buf.start_request(TNS_PACKET_TYPE_DATA)
        self._write_buf.write_uint32(0x0000030f)
        self._increment_seq_num()
        self._write_buf.write_uint8(self._seq_num)
        self._write_buf.end_request()

        # receive response
        self._receive_packet()

    cdef int _write_bytes(self, bytes value) except -1:
        cdef:
            WriteBuffer buf = self._write_buf
            ssize_t value_len, bytes_left
            char_type *ptr
        cpython.PyBytes_AsStringAndSize(value, <char**> &ptr, &value_len)
        if value_len <= TNS_MAX_SHORT_LENGTH:
            buf.write_uint8(<uint8_t> value_len)
            buf.write_raw(ptr, value_len)
        else:
            buf.write_uint8(TNS_LONG_LENGTH_INDICATOR)
            buf.write_ub4(value_len)
            bytes_left = buf.bytes_left()
            while True:
                if bytes_left >= value_len:
                    buf.write_raw(ptr, value_len)
                    break
                buf.write_raw(ptr, bytes_left)
                value_len -= bytes_left
                ptr += bytes_left
                bytes_left = buf.max_payload_bytes()
            buf.write_ub4(0)
