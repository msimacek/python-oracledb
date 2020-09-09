#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef int MAX_PACKET_SIZE = 65535

ctypedef int (*populate_func_type)(Protocol self, WriteBuffer buf,
        object params) except -1

cdef class Protocol:

    cdef:
        uint32_t _session_id, _serial_num
        uint8_t _seq_num, _debug_packets
        str _server_version
        object _socket
        bytearray _read_buffer
        int _read_buffer_offset

    def __init__(self, socket):
        self._seq_num = 3
        self._socket = socket
        self._debug_packets = <uint8_t> ("PYO_DEBUG_PACKETS" in os.environ)
        self._read_buffer = bytearray(MAX_PACKET_SIZE * 2)

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
        cdef uint8_t user_len = <uint8_t> len(params.user)

        # generate authentication response
        password, session_key = self._generate_auth_response(params)

        # write function code (0x73) and sequence number (0x03)
        buf.write_bytes(b'\x00\x00\x03\x73\x03')

        # write first aprt of authentication structure
        buf.write_native_uint64(TNS_PACKET_IND_PTR)
        buf.write_native_uint32(user_len)
        buf.write_native_uint32(257)
        buf.write_native_uint64(TNS_PACKET_IND_PTR)
        buf.write_native_uint32(4)              # number of key/value pairs
        buf.write_native_uint32(0x7ffc)
        buf.write_native_uint64(TNS_PACKET_IND_PTR)
        buf.write_native_uint64(TNS_PACKET_IND_PTR)
        buf.write_uint8(user_len)
        buf.write_str(params.user)

        # write key/value pairs
        self._populate_key_value(buf, "AUTH_SESSKEY", session_key, 1)
        self._populate_key_value(buf, "AUTH_PASSWORD", password, 0)
        self._populate_key_value(buf, "SESSION_CLIENT_CHARSET", "873", 0)
        self._populate_key_value(buf, "SESSION_CLIENT_DRIVER_NAME",
                constants.DRIVER_NAME, 0)

    cdef int _populate_connect_packet(self, WriteBuffer buf,
                                      object params) except -1:
        cdef:
            uint16_t connect_string_length
            bytes connect_string_bytes
        connect_string_bytes = params.connect_string.encode()
        connect_string_length = <uint16_t> len(connect_string_bytes)
        buf.write_uint16(314)           # version
        buf.write_uint16(300)           # compatible with version
        buf.write_uint16(0xc41)         # service options
        buf.write_uint16(8192)          # SDU
        buf.write_uint16(65535)         # TDU
        buf.write_uint16(0x7f08)        # protocol characteristics
        buf.write_uint16(0)             # line turnaround
        buf.write_native_uint16(1)      # value of 1
        buf.write_uint16(connect_string_length)
        buf.write_uint16(58)            # offset to connect data
        buf.write_uint32(2048)          # max receivable data
        buf.write_uint16(0x4141)        # connect flags
        buf.write_uint32(0)             # trace facility item 1
        buf.write_uint32(0)             # trace facility item 2
        buf.write_uint64(0)             # trace unique conn id
        buf.write_uint64(0)
        buf.write_bytes(connect_string_bytes)

    cdef int _populate_data_types_packet(self, WriteBuffer buf,
                                         object params) except -1:

        # write character set information (use UTF-8)
        buf.write_bytes(b'\x00\x00\x02\x69\x03\x69\x03\x83')

        # send compile time capabilities (first byte is length)
        buf.write_bytes(b'\x27\x06\x01\x01\x01\x0f\x01\x01\x06\x01\x01\x01' +
                b'\x01\x01\x01\x01\x7f\xff\x03\x0a\x03\x07\x01\x01\x7f\x01' +
                b'\x7f\xff\x01\x09\x01\x01\xbf\x01\x05\x06\x00\x01\x07\x04')

        # send runtime capabilities (first byte is length)
        buf.write_bytes(b'\x07\x02\x01\x00\x00\x18\x00\x03')

        # send timezone information (offset + file version)
        buf.write_bytes(b'\x80\x00\x00\x00\x3c\x3c\x3c\x80\x00\x00\x00\x00' +
                b'\x00\x00\x0e\xd0\x07')

    cdef int _populate_execute_packet(self, WriteBuffer buf,
                                      object params) except -1:
        cdef:
            uint32_t flags, num_params = 0, num_iters = 1
            bint is_query = 0
            bytes sql_bytes
            uint8_t sql_len

        # set up some variables; these should go in the Statement object and
        # be stored in a StatementCache
        sql = params.sql.strip()
        sql_bytes = sql.encode()
        sql_len = <uint8_t> len(sql_bytes)
        sql_keyword = sql[:10].split()[0].lower()
        flags = 0x21                # parse/execute
        if sql_keyword in ("select", "with"):
            flags |= 0x40           # fetch
            num_iters = params.fetch_array_size
            is_query = 1
        elif sql_keyword not in ("declare", "begin", "call"):
            flags |= 0x8000         # statement is NOT PL/SQL
        if params.params:
            num_params = <uint32_t> len(params.params)
            flags |= 0x08           # bind variables present

        # write switch session section; this is only needed the first time
        buf.write_uint32(0x0000116b)
        self._increment_seq_num()
        buf.write_uint8(self._seq_num)
        buf.write_native_uint32(self._session_id)
        buf.write_native_uint32(self._serial_num)
        buf.write_native_uint32(1)

        # write execute section
        buf.write_uint8(3)
        buf.write_uint8(94)
        self._increment_seq_num()
        buf.write_uint8(self._seq_num)
        buf.write_native_uint32(flags)
        buf.write_native_uint32(0)
        buf.write_native_uint64(TNS_PACKET_IND_PTR)
        buf.write_native_uint32(sql_len)
        buf.write_native_uint64(TNS_PACKET_IND_PTR)
        buf.write_native_uint32(13)
        buf.write_native_uint64(TNS_PACKET_IND_PTR)
        buf.write_native_uint64(TNS_PACKET_IND_PTR)
        buf.write_native_uint32(0)
        buf.write_native_uint32(num_iters)
        buf.write_native_uint32(0)
        if num_params == 0:
            buf.write_native_uint64(0)
            buf.write_native_uint32(0)
        else:
            buf.write_native_uint64(TNS_PACKET_IND_PTR)
            buf.write_native_uint32(num_params)
        buf.write_native_uint32(0)
        buf.write_native_uint32(0)
        buf.write_native_uint64(TNS_PACKET_IND_PTR)
        buf.write_native_uint32(0)
        buf.write_native_uint32(0)
        buf.write_native_uint64(TNS_PACKET_IND_PTR)
        buf.write_native_uint64(TNS_PACKET_IND_PTR)
        buf.write_native_uint64(TNS_PACKET_IND_PTR)
        buf.write_native_uint32(0)
        buf.write_native_uint32(0)
        buf.write_native_uint64(TNS_PACKET_IND_PTR)
        buf.write_native_uint64(TNS_PACKET_IND_PTR)
        for i in range(7):
            buf.write_native_uint32(0)
        buf.write_uint8(sql_len)
        buf.write_bytes(sql_bytes)
        buf.write_native_uint32(1)
        if is_query:
            buf.write_native_uint32(0)
        else:
            buf.write_native_uint32(1)
        for i in range(5):
            buf.write_native_uint32(0)
        if is_query:
            buf.write_native_uint32(1)
        else:
            buf.write_native_uint32(4)
        for i in range(5):
            buf.write_native_uint32(0)
        if num_params > 0:
            self._populate_bind_params(buf, params.params)

    cdef int _populate_bind_params(self, WriteBuffer buf,
                                   list params) except -1:
        cdef:
            uint32_t num_params = <uint32_t> len(params)
            bytes temp_bytes
            object value
            Var var

        # write parameter header information
        for i in range(num_params):
            var = <Var> cpython.PyList_GET_ITEM(params, i)
            buf.write_uint8(1)
            buf.write_uint8(var.type._ora_type_num)
            buf.write_uint8(7)
            buf.write_uint8(var._precision)
            buf.write_uint8(var._scale)
            buf.write_native_uint32(var.buffer_size)
            buf.write_native_uint32(0)
            buf.write_native_uint32(16)
            buf.write_native_uint32(0)
            buf.write_native_uint32(0)
            buf.write_native_uint32(0)
            buf.write_native_uint16(873)        # UTF-8
            buf.write_uint8(var.type._csfrm)    # charset form
            buf.write_uint8(0)
            buf.write_native_uint32(0)
            buf.write_native_uint32(0)

        # write parameter values
        buf.write_uint8(7)
        for i in range(num_params):
            var = <Var> cpython.PyList_GET_ITEM(params, i)
            value = var._values[0]
            if var.type._ora_type_num == TNS_DATA_TYPE_VARCHAR:
                temp_bytes = value.encode()
                buf.write_uint8(<uint8_t> len(temp_bytes))
                buf.write_bytes(temp_bytes)
            else:
                errors._raise_from_string(exceptions.NotSupportedError,
                                          f"unsupported type {var.type}")

    cdef int _populate_get_session_key_packet(self, WriteBuffer buf,
                                              object params) except -1:
        cdef uint8_t user_len = <uint8_t> len(params.user)

        # write function code (0x76) and sequence number (0x02)
        buf.write_bytes(b'\x00\x00\x03\x76\x02')

        # write first part of authorization structure
        buf.write_native_uint64(TNS_PACKET_IND_PTR)
        buf.write_native_uint32(user_len)
        buf.write_native_uint32(1)
        buf.write_native_uint64(TNS_PACKET_IND_PTR)
        buf.write_native_uint32(5)              # number of key/value pairs
        buf.write_native_uint32(0)
        buf.write_native_uint64(TNS_PACKET_IND_PTR)
        buf.write_native_uint64(TNS_PACKET_IND_PTR)
        buf.write_uint8(user_len)
        buf.write_str(params.user)

        # write key/value pairs
        self._populate_key_value(buf, "AUTH_TERMINAL", "pts/2", 0)
        self._populate_key_value(buf, "AUTH_PROGRAM_NM",
                "python3.8@atc (TNS V1-V3)", 0)
        self._populate_key_value(buf, "AUTH_MACHINE", "atc", 0)
        self._populate_key_value(buf, "AUTH_PID", "83274", 0)
        self._populate_key_value(buf, "AUTH_SID", "anthony", 0)

    cdef void _populate_key_value(self, WriteBuffer buf, str key, str value,
            uint32_t flags):
        cdef bytes key_bytes = key.encode()
        cdef bytes value_bytes = value.encode()
        cdef uint8_t key_len = <uint8_t> cpython.PyBytes_GET_SIZE(key_bytes)
        cdef uint8_t value_len = \
                <uint8_t> cpython.PyBytes_GET_SIZE(value_bytes)
        buf.write_native_uint32(key_len)
        buf.write_uint8(key_len)
        buf.write_bytes(key_bytes)
        buf.write_native_uint32(value_len)
        if value_len > 0:
            buf.write_uint8(value_len)
            buf.write_bytes(value_bytes)
        buf.write_native_uint32(flags)

    cdef int _populate_marker_packet(self, WriteBuffer buf,
                                     object params) except -1:
        buf.write_uint8(1)
        buf.write_uint8(0)
        buf.write_uint8(2)

    cdef int _populate_protocol_packet(self, WriteBuffer buf,
                                       object params) except -1:
        buf.write_bytes(b'\x00\x00\x01\x06\x05\x04\x03\x02\x01\x00')
        buf.write_bytes(b'x86_64/Linux 2.4.xx')
        buf.write_uint8(0)

    cdef int _populate_services_packet(self, WriteBuffer buf,
                                       object params) except -1:
        buf.write_bytes(b'\x00\x00\xde\xad\xbe\xef\x00\x97\x00\x00\x00\x00' +
                b'\x00\x04\x00\x00\x04\x00\x03\x00\x00\x00\x00\x00\x04\x00' +
                b'\x05\x0b\x20\x04\x00\x00\x08\x00\x01\x00\x01\x45\x4a\x1b' +
                b'\x60\x09\x2a\x00\x12\x00\x01\xde\xad\xbe\xef\x00\x03\x00' +
                b'\x00\x00\x04\x00\x04\x00\x01\x00\x01\x00\x02\x00\x01\x00' +
                b'\x03\x00\x00\x00\x00\x00\x04\x00\x05\x0b\x20\x04\x00\x00' +
                b'\x02\x00\x03\xe0\xe1\x00\x02\x00\x06\xfc\xff\x00\x02\x00' +
                b'\x03\x00\x00\x00\x00\x00\x04\x00\x05\x0b\x20\x04\x00\x00' +
                b'\x0c\x00\x01\x00\x11\x06\x10\x0c\x0f\x0a\x0b\x08\x02\x01' +
                b'\x03\x00\x01\x00\x02\x01\x00\x03\x00\x02\x00\x00\x00\x00' +
                b'\x00\x04\x00\x05\x0b\x20\x04\x00\x00\x03\x00\x01\x00\x03' +
                b'\x01')

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
            uint32_t name_length
            uint16_t charset_id
            Var var
        var = cursor._create_var()
        buf.skip_bytes(1)
        data_type = buf.read_uint8()
        buf.skip_bytes(1)
        var._precision = buf.read_uint8()
        var._scale = buf.read_int8()
        var.buffer_size = buf.read_native_uint32()
        buf.skip_bytes(20)
        charset_id = buf.read_native_uint16()
        csfrm = buf.read_uint8()
        buf.skip_bytes(1)
        var.type = DbType._from_ora_type_and_csfrm(data_type, csfrm)
        var.size = buf.read_native_uint32()
        buf.skip_bytes(6)
        name_length = buf.read_native_uint32()
        buf.skip_bytes(1)               # skip repeated info
        var._name = buf.read_str(name_length)
        buf.skip_bytes(14)
        var.num_elements = cursor._fetch_array_size
        var._finalize_init()
        return var

    cdef int _process_error_packet(self, ReadBuffer buf) except -1:
        cdef:
            uint8_t num_bytes
            str message
        buf.skip_bytes(138)
        num_bytes = buf.read_uint8()
        message = buf.read_str(num_bytes)
        errors._raise_from_string(exceptions.DatabaseError, message)

    cdef int _process_execute_packet(self, Cursor cursor,
                                     ReadBuffer buf) except -1:
        cdef:
            uint32_t num_columns, i
            Var var
        buf.skip_bytes(34)
        num_columns = buf.read_native_uint32()
        cursor._fetch_array_size = cursor.arraysize
        buf.skip_bytes(1)
        cursor._more_rows_to_fetch = True
        cursor._fetch_vars = cpython.PyList_New(num_columns)
        for i in range(num_columns):
            var = self._process_column_info(cursor, buf)
            cpython.Py_INCREF(var)
            cpython.PyList_SET_ITEM(cursor._fetch_vars, i, var)
        buf.skip_bytes(32)
        self._process_fetch_data(cursor, buf)

    cdef int _process_fetch_data(self, Cursor cursor,
                                 ReadBuffer buf) except -1:
        cdef:
            uint16_t num_bits, num_bytes
            uint32_t row_index = 0
            uint8_t message_type
        cursor._buffer_rowcount = 0
        cursor._buffer_index = 0
        while buf.bytes_left() > 0:
            message_type = buf.read_uint8()
            if message_type == TNS_MSG_TYPE_ROW_HEADER:
                buf.skip_bytes(49)
            elif message_type == TNS_MSG_TYPE_ROW_DATA:
                self._process_row(buf, cursor._fetch_vars, row_index)
                cursor._buffer_rowcount += 1
            elif message_type == TNS_MSG_TYPE_BIT_VECTOR:
                num_bits = buf.read_native_uint16()
                num_bytes = num_bits // 8
                if num_bits % 8 > 0:
                    num_bytes += 1
                buf.skip_bytes(num_bytes)
            else:
                break

    cdef int _process_row(self, ReadBuffer buf, list columns,
                          uint32_t row_index) except -1:
        cdef:
            uint8_t num_bytes, ora_type_num, csfrm
            ssize_t num_columns, i
            object column_value
            bytes temp_bytes
            const char *ptr
            Var var
        num_columns = cpython.PyList_GET_SIZE(columns)
        for i in range(num_columns):
            var = columns[i]
            ora_type_num = var.type._ora_type_num
            csfrm = var.type._csfrm
            num_bytes = buf.read_uint8()
            if num_bytes == 0:
                column_value = None
            elif ora_type_num == TNS_DATA_TYPE_VARCHAR \
                    or ora_type_num == TNS_DATA_TYPE_CHAR:
                temp_bytes = buf.read_bytes_chunked(num_bytes, var._buf,
                                                    var.buffer_size)
                if csfrm == 1:
                    column_value = temp_bytes.decode()
                else:
                    column_value == temp_bytes.decode("UTF16-BE")
            elif ora_type_num == TNS_DATA_TYPE_RAW:
                column_value = buf.read_bytes_chunked(num_bytes, var._buf,
                                                      var.buffer_size)
            elif ora_type_num == TNS_DATA_TYPE_NUMBER:
                column_value = buf.read_oracle_number(num_bytes)
            else:
                msg = f"unhandled data type {var.type}"
                raise Exception(msg)
            var._values[row_index] = column_value

    cdef int _process_session_data_packet(self, ReadBuffer buf,
                                          object params) except -1:
        cdef:
            int version_num, release_num, update_num, port_release_num
            uint32_t num_bytes, flags, full_version_num
            int port_update_num
            uint16_t num_params
            str key, value
        buf.skip_bytes(3)               # skip data flag, data id
        num_params = buf.read_native_uint16()
        for i in range(num_params):
            num_bytes = buf.read_native_uint32()
            buf.skip_bytes(1)           # skip redundant length
            key = buf.read_str(num_bytes)
            num_bytes = buf.read_native_uint32()
            if num_bytes > 0:
                buf.skip_bytes(1)           # skip redundant length
                value = buf.read_str(num_bytes)
            else:
                value = ""
            flags = buf.read_native_uint32()
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
        self._socket.recv_into(self._read_buffer, MAX_PACKET_SIZE)
        buf = ReadBuffer(self._read_buffer)
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
