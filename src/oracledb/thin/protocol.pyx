#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef int MAX_PACKET_SIZE = 65535

ctypedef int (*populate_func_type)(Protocol self, WriteBuffer buf,
        object params)

cdef class Protocol:

    cdef:
        uint32_t _session_id, _serial_num
        uint8_t _seq_num, _debug_packets
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

    cdef int _populate_auth_packet(self, WriteBuffer buf, object params):
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

    cdef int _populate_connect_packet(self, WriteBuffer buf, object params):
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

    cdef int _populate_data_types_packet(self, WriteBuffer buf, object params):

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

    cdef int _populate_get_session_key_packet(self, WriteBuffer buf,
                                              object params):
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

    cdef int _populate_marker_packet(self, WriteBuffer buf, object params):
        buf.write_uint8(1)
        buf.write_uint8(0)
        buf.write_uint8(2)

    cdef int _populate_protocol_packet(self, WriteBuffer buf, object params):
        buf.write_bytes(b'\x00\x00\x01\x06\x05\x04\x03\x02\x01\x00')
        buf.write_bytes(b'x86_64/Linux 2.4.xx')
        buf.write_uint8(0)

    cdef int _populate_services_packet(self, WriteBuffer buf, object params):
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

    cdef int _process_error_packet(self, ReadBuffer buf) except -1:
        cdef:
            uint8_t num_bytes
            str message
        buf.skip_bytes(138)
        num_bytes = buf.read_uint8()
        message = buf.read_str(num_bytes)
        errors._raise_from_string(exceptions.DatabaseError, message)

    cdef int _process_session_data_packet(self, ReadBuffer buf,
                                          object params) except -1:
        cdef uint32_t num_bytes, flags
        cdef uint16_t num_params
        cdef str key, value
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
