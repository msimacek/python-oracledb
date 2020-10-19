#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef int MAX_PACKET_SIZE = 65535

ctypedef int (*populate_func_type)(Protocol self, WriteBuffer buf,
        object params) except -1

cdef struct _OracleErrorInfo:
    uint32_t num
    uint16_t cursor_id
    uint32_t message_length
    const char_type *message

cdef class Protocol:

    cdef:
        uint32_t _session_id, _serial_num
        uint8_t _seq_num, _debug_packets
        str _server_version
        object _socket
        bytearray _read_buf
        ChunkedBytesBuffer _chunked_bytes_buf

    def __init__(self, socket):
        self._seq_num = 3
        self._socket = socket
        self._debug_packets = <uint8_t> ("PYO_DEBUG_PACKETS" in os.environ)
        self._read_buf = bytearray(MAX_PACKET_SIZE * 2)
        self._chunked_bytes_buf = ChunkedBytesBuffer()

    cdef int _close(self) except -1:
        self._send_packet(TNS_PACKET_TYPE_DATA, None,
                          self._populate_close_packet)
        self._receive_packet()
        self._send_packet(TNS_PACKET_TYPE_DATA, None,
                          self._populate_final_close_packet)
        self._socket.close()

    cdef int _commit(self) except -1:
        self._send_packet(TNS_PACKET_TYPE_DATA, None,
                          self._populate_commit_packet)
        self._receive_packet()

    def _connect(self, params):
        cdef ReadBuffer buf
        self._send_packet(TNS_PACKET_TYPE_CONNECT, params,
                          self._populate_connect_packet)
        self._receive_packet()
        self._send_packet(TNS_PACKET_TYPE_CONNECT, params,
                          self._populate_connect_packet)
        self._receive_packet()
        self._send_packet(TNS_PACKET_TYPE_DATA, params,
                          self._populate_services_packet)
        self._receive_packet()
        self._send_packet(TNS_PACKET_TYPE_DATA, params,
                          self._populate_protocol_packet)
        self._receive_packet()
        self._send_packet(TNS_PACKET_TYPE_DATA, params,
                          self._populate_data_types_packet)
        self._receive_packet()
        self._send_packet(TNS_PACKET_TYPE_DATA, params,
                          self._populate_get_session_key_packet)
        buf = self._receive_packet()
        params.session_data = {}
        self._process_session_data_packet(buf, params)
        self._send_packet(TNS_PACKET_TYPE_DATA, params,
                          self._populate_auth_packet)
        buf = self._receive_packet()
        self._process_session_data_packet(buf, params)

    def _encrypt_cbc(self, key, plain_text):
        iv = b"\x00" * AES.block_size
        b = AES.new(key, AES.MODE_CBC, iv)
        n = AES.block_size - len(plain_text) % AES.block_size
        if n:
            plain_text += (bytes([n]) * n)
        return b.encrypt(plain_text)

    def _execute(self, params):
        cdef ReadBuffer buf
        self._send_packet(TNS_PACKET_TYPE_DATA, params,
                          self._populate_execute_packet)
        buf = self._receive_packet()
        self._process_execute_packet(params.cursor, buf)

    def _fetch(self, params):
        cdef ReadBuffer buf
        self._send_packet(TNS_PACKET_TYPE_DATA, params,
                          self._populate_fetch_packet)
        buf = self._receive_packet()
        self._process_execute_packet(params.cursor, buf)

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

    cdef _increment_seq_num(self):
        self._seq_num += 1
        if self._seq_num == 0:
            self._seqNum = 1

    cdef int _populate_auth_packet(self, WriteBuffer buf,
                                   object params) except -1:
        cdef:
            bytes user_bytes = params.user.encode()
            uint8_t user_len = <uint8_t> len(user_bytes)

        # generate authentication response
        password, session_key = self._generate_auth_response(params)

        # write function code (0x73) and sequence number (0x03)
        buf.write_bytes(b'\x00\x00\x03\x73\x03')

        # write first part of authentication structure
        buf.write_uint8(1)                  # pointer (authusr)
        buf.write_ub4(user_len)
        buf.write_ub4(257)                  # authentication mode
        buf.write_uint8(1)                  # pointer (authivl)
        buf.write_ub4(4)                    # number of key/value pairs
        buf.write_uint8(1)                  # pointer (authovl)
        buf.write_uint8(1)                  # pointer (authovln)
        buf.write_bytes(user_bytes)

        # write key/value pairs
        self._populate_key_value(buf, "AUTH_SESSKEY", session_key, 1)
        self._populate_key_value(buf, "AUTH_PASSWORD", password, 0)
        self._populate_key_value(buf, "SESSION_CLIENT_CHARSET", "873", 0)
        self._populate_key_value(buf, "SESSION_CLIENT_DRIVER_NAME",
                constants.DRIVER_NAME, 0)

    cdef int _populate_close_packet(self, WriteBuffer buf,
                                    object params) except -1:
        buf.write_uint32(0x00000309)
        self._increment_seq_num()
        buf.write_uint8(self._seq_num)

    cdef int _populate_commit_packet(self, WriteBuffer buf,
                                     object params) except -1:
        buf.write_uint32(0x0000030e)
        self._increment_seq_num()
        buf.write_uint8(self._seq_num)

    cdef int _populate_connect_packet(self, WriteBuffer buf,
                                      object params) except -1:
        cdef:
            uint16_t connect_string_length
            bytes connect_string_bytes
        connect_string_bytes = params.connect_string.encode()
        connect_string_length = <uint16_t> len(connect_string_bytes)
        buf.write_uint16(314)               # version
        buf.write_uint16(300)               # compatible with version
        buf.write_uint16(0xc41)             # service options
        buf.write_uint16(8192)              # SDU
        buf.write_uint16(65535)             # TDU
        buf.write_uint16(0x7f08)            # protocol characteristics
        buf.write_uint16(0)                 # line turnaround
        buf.write_uint16(1)                 # value of 1
        buf.write_uint16(connect_string_length)
        buf.write_uint16(58)                # offset to connect data
        buf.write_uint32(0)                 # max receivable data
        buf.write_uint16(0x4141)            # connect flags
        buf.write_uint64(0)                 # obsolete
        buf.write_uint64(0)                 # obsolete
        buf.write_uint64(0)                 # obsolete
        buf.write_bytes(connect_string_bytes)

    cdef int _populate_data_types_packet(self, WriteBuffer buf,
                                         object params) except -1:
        buf.write_bytes(TNS_DATA_TYPES_PACKET_DATA)

    cdef int _populate_execute_packet(self, WriteBuffer buf,
                                      object params) except -1:
        cdef:
            uint32_t options, num_params = 0, num_iters = 1
            bint is_query = 0
            bytes sql_bytes
            uint8_t sql_len

        # set up some variables; these should go in the Statement object and
        # be stored in a StatementCache
        sql = params.sql.strip()
        sql_bytes = sql.encode()
        sql_len = <uint8_t> len(sql_bytes)
        sql_keyword = sql[:10].split()[0].lower()
        options = 0x21                      # parse/execute
        if sql_keyword not in ("declare", "begin", "call"):
            options |= 0x8000               # statement is NOT PL/SQL
        elif params.params:
            options |= 0x400                # PL/SQL with parameters
        if sql_keyword in ("select", "with"):
            options |= 0x40                 # fetch
            num_iters = params.fetch_array_size
            is_query = 1
        if params.params:
            num_params = <uint32_t> len(params.params)
            options |= 0x08                 # bind variables present

        # write packet
        buf.write_uint16(0)                 # data flags
        buf.write_uint16(0x35e)             # function code
        self._increment_seq_num()
        buf.write_uint8(self._seq_num)
        buf.write_ub4(options)              # execute options
        buf.write_ub4(0)                    # cursor ID
        buf.write_uint8(1)                  # pointer (cursor id)
        buf.write_ub4(sql_len)              # length of SQL to execute
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
        buf.write_uint8(0)                  # pointer (al8pidmlrc)
        buf.write_ub4(0)                    # al8pidmlrcbl
        buf.write_uint8(0)                  # pointer (al8pidmlrcl)
        buf.write_uint8(0)                  # pointer (al8sqlsig)
        buf.write_ub4(0)                    # SQL signature length
        buf.write_uint8(0)                  # pointer (SQL ID)
        buf.write_ub4(0)                    # allocated size of SQL ID
        buf.write_uint8(0)                  # pointer (length of SQL ID)
        buf.write_bytes(sql_bytes)
        buf.write_ub4(1)                    # al8i4[0] parse
        if is_query:
            buf.write_ub4(0)                # al8i4[1] execution count
        else:
            buf.write_ub4(1)                # al8i4[1] execution count
        buf.write_ub4(0)                    # al8i4[2]
        buf.write_ub4(0)                    # al8i4[3]
        buf.write_ub4(0)                    # al8i4[4]
        buf.write_ub4(0)                    # al8i4[5] SCN (part 1)
        buf.write_ub4(0)                    # al8i4[6] SCN (part 2)
        buf.write_ub4(is_query)             # al8i4[7] is query
        buf.write_ub4(0)                    # al8i4[8]
        buf.write_ub4(0)                    # al8i4[9] DML row counts/implicit
        buf.write_ub4(0)                    # al8i4[10]
        buf.write_ub4(0)                    # al8i4[11]
        buf.write_ub4(0)                    # al8i4[12]
        if num_params > 0:
            self._populate_bind_params(buf, params.params)

    cdef int _populate_bind_params(self, WriteBuffer buf,
                                   list params) except -1:
        cdef:
            uint32_t num_params = <uint32_t> len(params)
            uint8_t ora_type_num
            bytes temp_bytes
            object value
            Var var

        # write parameter header information
        for i in range(num_params):
            var = <Var> cpython.PyList_GET_ITEM(params, i)
            buf.write_uint8(var.type._ora_type_num)
            buf.write_uint8(3)              # flag
            buf.write_uint8(var.precision)
            buf.write_uint8(var.scale)
            buf.write_ub4(var.buffer_size)
            buf.write_ub4(0)                # max num elements
            buf.write_ub4(0)                # cont flag
            buf.write_ub4(0)                # OID
            buf.write_ub4(0)                # version
            buf.write_ub4(873)              # character set id
            buf.write_uint8(var.type._csfrm)
            buf.write_ub4(var.size)
            buf.write_ub4(0)                # oaccolid

        # write parameter values
        buf.write_uint8(7)                  # data indicator
        for i in range(num_params):
            var = <Var> cpython.PyList_GET_ITEM(params, i)
            ora_type_num = var.type._ora_type_num
            value = var._values[0]
            if value is None:
                buf.write_uint8(0)
            elif ora_type_num == TNS_DATA_TYPE_VARCHAR \
                    or ora_type_num == TNS_DATA_TYPE_CHAR:
                if var.type._csfrm == 1:
                    temp_bytes = value.encode()
                else:
                    temp_bytes = value.encode("UTF-16BE")
                buf.write_uint8(<uint8_t> len(temp_bytes))
                buf.write_bytes(temp_bytes)
            elif ora_type_num == TNS_DATA_TYPE_RAW:
                buf.write_uint8(<uint8_t> len(value))
                buf.write_bytes(value)
            elif ora_type_num == TNS_DATA_TYPE_NUMBER:
                buf.write_oracle_number(str(value).encode())
            elif ora_type_num == TNS_DATA_TYPE_DATE \
                    or ora_type_num == TNS_DATA_TYPE_TIMESTAMP \
                    or ora_type_num == TNS_DATA_TYPE_TIMESTAMP_TZ \
                    or ora_type_num == TNS_DATA_TYPE_TIMESTAMP_LTZ:
                buf.write_oracle_date(value, var.type._buffer_size_factor)
            else:
                errors._raise_from_string(exceptions.NotSupportedError,
                                          f"unsupported type {var.type}")

    cdef int _populate_fetch_packet(self, WriteBuffer buf,
                                    object params) except -1:
        cdef Cursor cursor = params.cursor
        cursor._buffer_rowcount = 0
        cursor._buffer_index = 0
        buf.write_uint32(0x00000305)
        self._increment_seq_num()
        buf.write_uint8(self._seq_num)
        buf.write_ub4(cursor._cursor_id)
        buf.write_ub4(params.fetch_array_size)

    cdef int _populate_final_close_packet(self, WriteBuffer buf,
                                          object params) except -1:
        buf.write_uint16(0x0040)

    cdef int _populate_get_session_key_packet(self, WriteBuffer buf,
                                              object params) except -1:
        cdef:
            bytes user_bytes = params.user.encode()
            uint8_t user_len = <uint8_t> len(user_bytes)

        # write function code (0x76) and sequence number (0x02)
        buf.write_bytes(b'\x00\x00\x03\x76\x02')

        # write first part of authorization structure
        buf.write_uint8(1)                  # pointer (authusr)
        buf.write_ub4(user_len)             # length of user name
        buf.write_ub4(1)                    # authentication mode
        buf.write_uint8(1)                  # pointer (authivl)
        buf.write_ub4(5)                    # number of key/value pairs
        buf.write_uint8(0)                  # pointer (authovl)
        buf.write_uint8(1)                  # pointer (authovln)
        buf.write_bytes(user_bytes)         # user name

        # write key/value pairs
        self._populate_key_value(buf, "AUTH_TERMINAL", "pts/2", 0)
        self._populate_key_value(buf, "AUTH_PROGRAM_NM",
                "python3.8@atc (TNS V1-V3)", 0)
        self._populate_key_value(buf, "AUTH_MACHINE", "atc", 0)
        self._populate_key_value(buf, "AUTH_PID", "83274", 0)
        self._populate_key_value(buf, "AUTH_SID", "anthony", 0)

    cdef void _populate_key_value(self, WriteBuffer buf, str key, str value,
            uint32_t flags):
        cdef:
            bytes key_bytes = key.encode()
            bytes value_bytes = value.encode()
            uint8_t key_len = <uint8_t> cpython.PyBytes_GET_SIZE(key_bytes)
            uint8_t value_len = <uint8_t> cpython.PyBytes_GET_SIZE(value_bytes)
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

    cdef int _populate_rollback_packet(self, WriteBuffer buf,
                                       object params) except -1:
        buf.write_uint32(0x0000030f)
        self._increment_seq_num()
        buf.write_uint8(self._seq_num)

    cdef int _populate_services_packet(self, WriteBuffer buf,
                                       object params) except -1:
        buf.write_bytes(TNS_SERVICES_PACKET_DATA)

    def _print_packet(self, operation, view):
        offset = 0
        hex_data = view.hex().upper()
        print(operation)
        while hex_data:
            line_hex_data = hex_data[:16]
            hex_data = hex_data[16:]
            hex_dump_values = []
            printable_values = []
            for i in range(0, len(line_hex_data), 2):
                hex_byte = line_hex_data[i:i + 2]
                hex_dump_values.append(hex_byte)
                byte_val = ord(bytes.fromhex(hex_byte))
                char_byte = chr(byte_val)
                if char_byte.isprintable() and byte_val < 128 \
                        and char_byte != " ":
                    printable_values.append(char_byte)
                else:
                    printable_values.append(".")
            while len(hex_dump_values) < 8:
                hex_dump_values.append("  ")
                printable_values.append(" ")
            print("%.4d : %s  |%s|" % (offset, " ".join(hex_dump_values),
                    "".join(printable_values)))
            offset += 8
        print()

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
            buf.skip_bytes(num_bytes)
        buf.read_ub2()                      # version
        buf.read_ub2()                      # character set id
        csfrm = buf.read_uint8()            # character set form
        var.type = DbType._from_ora_type_and_csfrm(data_type, csfrm)
        var.size = buf.read_ub4()
        buf.read_ub4()                      # oaccolid
        var.nulls_allowed = buf.read_uint8()
        buf.skip_bytes(1)                   # v7 length of name
        num_bytes = buf.read_ub4()
        if num_bytes > 0:
            buf.skip_bytes(1)               # skip repeated length
            var.name = buf.read_str(num_bytes)
        num_bytes = buf.read_ub4()
        if num_bytes > 0:
            buf.skip_bytes(num_bytes)       # schema name
        num_bytes = buf.read_ub4()
        if num_bytes > 0:
            buf.skip_bytes(num_bytes)       # type name
        buf.read_ub2()                      # column position
        buf.read_ub4()                      # uds flag
        var.num_elements = cursor._fetch_array_size
        var._finalize_init()
        return var

    cdef int _process_error_info(self, ReadBuffer buf,
                                 _OracleErrorInfo *info) except -1:
        cdef uint32_t num_bytes
        buf.read_ub4()                      # end of call status
        buf.read_ub2()                      # end to end seq#
        buf.read_ub4()                      # current row number
        buf.read_ub2()                      # error number
        buf.read_ub2()                      # array elem error
        buf.read_ub2()                      # array elem error
        info.cursor_id = buf.read_ub2()     # cursor id
        buf.read_ub2()                      # error position
        buf.read_uint8()                    # sql type
        buf.read_uint8()                    # fatal?
        buf.read_ub2()                      # flags
        buf.read_ub2()                      # user cursor options
        buf.read_uint8()                    # UPI parameter
        buf.read_uint8()                    # warning flag
        buf.read_ub4()                      # RBA
        buf.read_ub2()                      # partition id
        buf.read_uint8()                    # table id
        buf.read_ub4()                      # block #
        buf.read_ub2()                      # slot #
        buf.read_ub4()                      # OS error
        buf.read_uint8()                    # statement number
        buf.read_uint8()                    # call number
        buf.read_ub2()                      # padding
        buf.read_ub4()                      # success iters
        num_bytes = buf.read_ub4()          # oerrdd
        if num_bytes > 0:
            buf.skip_bytes(num_bytes + 1)
        buf.read_ub2()                      # oerrarl
        buf.read_ub4()                      # oerepal
        buf.read_ub2()                      # oermarl
        info.num = buf.read_ub4()           # error number (extended)
        buf.read_ub8()                      # row number (extended)
        if info.num != 0:
            info.message_length = buf.read_uint8()
            info.message = buf._get_raw(info.message_length)

    cdef int _process_error_packet(self, ReadBuffer buf) except -1:
        cdef:
            _OracleErrorInfo error_info
            uint8_t num_bytes
        buf.skip_bytes(2)                   # skip data flag
        if buf.read_uint8() != 4:
            errors._raise_from_string(exceptions.DatabaseError,
                                      "TTC error: expecting error packet")
        self._process_error_info(buf, &error_info)
        message = error_info.message[:error_info.message_length].decode()
        errors._raise_from_string(exceptions.DatabaseError, message)

    cdef int _process_execute_packet(self, Cursor cursor,
                                     ReadBuffer buf) except -1:
        cdef:
            uint32_t num_columns, num_bytes, num_params, i, temp, row_index
            uint8_t message_type, bind_dir
            _OracleErrorInfo error_info
            bint in_fetch = False
            uint16_t num_bits
            list row_vars
            Var var
        buf.skip_bytes(2)
        row_vars = cursor._fetch_vars
        row_index = cursor._buffer_rowcount
        if cursor._fetch_vars is not None:
            in_fetch = True
        while buf.bytes_left() > 0:
            message_type = buf.read_uint8()
            if message_type == TNS_MSG_TYPE_DESCRIBE_INFO:
                num_bytes = buf.read_uint8()
                buf.skip_bytes(num_bytes)
                buf.read_ub4()              # max row size
                num_columns = buf.read_ub4()
                cursor._fetch_array_size = cursor.arraysize
                cursor._more_rows_to_fetch = True
                row_index = cursor._buffer_rowcount = 0
                cursor._buffer_index = 0
                in_fetch = True
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
                    row_vars.append(cursor._bind_vars[i])
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
                num_params = buf.read_ub2() # al8o4l (ignored)
                for i in range(num_params):
                    buf.read_ub4()
                num_bytes = buf.read_ub2()  # al8txl (ignored)
                if num_bytes > 0:
                    buf.skip_bytes(num_bytes)
                num_params = buf.read_ub2() # num key/value pairs
                num_bytes = buf.read_ub4()  # registration
                if num_bytes > 0:
                    buf.skip_bytes(num_bytes)
            elif message_type == TNS_MSG_TYPE_ERROR:
                self._process_error_info(buf, &error_info)
                cursor._cursor_id = error_info.cursor_id
                if error_info.num == 1403:
                    cursor._more_rows_to_fetch = False
            else:
                msg = f"unknown message type: {message_type}"
                errors._raise_from_string(exceptions.InternalError, msg)

    cdef int _process_row(self, ReadBuffer buf, list row_vars,
                          uint32_t row_index, bint in_fetch) except -1:
        cdef:
            uint8_t num_bytes, ora_type_num, csfrm
            ssize_t num_row_vars, i
            object column_value
            bytes temp_bytes
            const char *ptr
            Var var
        num_row_vars = cpython.PyList_GET_SIZE(row_vars)
        for i in range(num_row_vars):
            var = row_vars[i]
            ora_type_num = var.type._ora_type_num
            csfrm = var.type._csfrm
            num_bytes = buf.read_uint8()
            if num_bytes == 0:
                column_value = None
            elif ora_type_num == TNS_DATA_TYPE_VARCHAR \
                    or ora_type_num == TNS_DATA_TYPE_CHAR \
                    or ora_type_num == TNS_DATA_TYPE_LONG:
                temp_bytes = buf.read_bytes_chunked(num_bytes,
                                                    self._chunked_bytes_buf)
                if csfrm == 1:
                    column_value = temp_bytes.decode()
                else:
                    column_value = temp_bytes.decode("UTF-16BE")
                if ora_type_num == TNS_DATA_TYPE_LONG:
                    buf.skip_bytes(2)
            elif ora_type_num == TNS_DATA_TYPE_RAW:
                column_value = buf.read_bytes_chunked(num_bytes,
                                                      self._chunked_bytes_buf)
            elif ora_type_num == TNS_DATA_TYPE_NUMBER:
                column_value = buf.read_oracle_number(num_bytes)
            elif ora_type_num == TNS_DATA_TYPE_DATE \
                    or ora_type_num == TNS_DATA_TYPE_TIMESTAMP \
                    or ora_type_num == TNS_DATA_TYPE_TIMESTAMP_LTZ \
                    or ora_type_num == TNS_DATA_TYPE_TIMESTAMP_TZ:
                column_value = buf.read_oracle_date(num_bytes)
            elif ora_type_num == TNS_DATA_TYPE_ROWID:
                column_value = buf.read_rowid()
            else:
                msg = f"unhandled data type {var.type}"
                raise Exception(msg)
            var._values[row_index] = column_value
            if not in_fetch:
                buf.skip_bytes(1)       # skip trailing zero byte

    cdef int _process_session_data_packet(self, ReadBuffer buf,
                                          object params) except -1:
        cdef:
            int version_num, release_num, update_num, port_release_num
            uint32_t num_bytes, flags, full_version_num
            int port_update_num
            uint16_t num_params
            str key, value
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

    cdef ReadBuffer _receive_packet(self):
        cdef:
            ReadBuffer buf
            uint16_t packet_size
            uint8_t packet_type
            ssize_t bytes_read
        bytes_read = self._socket.recv_into(self._read_buf, MAX_PACKET_SIZE)
        buf = ReadBuffer(self._read_buf, bytes_read)
        packet_size = buf.read_uint16()
        buf.skip_bytes(2)               # skip packet checksum
        packet_type = buf.read_uint8()
        buf.skip_bytes(3)               # skip reserved byte, header checksum
        buf.set_size(packet_size)
        if self._debug_packets:
            self._print_packet("Receiving packet:", memoryview(buf))
        if packet_type == TNS_PACKET_TYPE_MARKER:
            self._send_packet(TNS_PACKET_TYPE_MARKER, None,
                              self._populate_marker_packet)
            self._process_error_packet(self._receive_packet())
        return buf

    cdef int _rollback(self) except -1:
        self._send_packet(TNS_PACKET_TYPE_DATA, None,
                          self._populate_rollback_packet)
        self._receive_packet()

    cdef _send_packet(self, uint8_t packet_type, object params,
            populate_func_type populate_func):
        cdef WriteBuffer buf = WriteBuffer()
        buf.write_uint32(0)
        buf.write_uint8(packet_type)
        buf.write_uint8(0)
        buf.write_uint16(0)
        populate_func(self, buf, params)
        view = memoryview(buf)
        buf.write_uint16_at_offset(view.nbytes, 0)
        if self._debug_packets:
            self._print_packet("Sending packet:", view)
        self._socket.send(view)
