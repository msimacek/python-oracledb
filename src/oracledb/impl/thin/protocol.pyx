#------------------------------------------------------------------------------
# Copyright (c) 2020, 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class Protocol:

    cdef:
        uint8_t _seq_num
        object _socket
        Capabilities _caps
        ReadBuffer _read_buf
        WriteBuffer _write_buf
        object _request_lock
        bint _txn_in_progress
        bint _break_in_progress
        bint _oob_check_in_progress

    def __init__(self, sock):
        self._caps = Capabilities()
        self.__set_socket(sock)
        self._request_lock = threading.Lock()

    cdef int __set_socket(self, sock):
        self._socket = sock
        self._read_buf = ReadBuffer(sock, TNS_SDU, self._caps)
        self._write_buf = WriteBuffer(sock, TNS_SDU, self._caps)

    cdef int _break_external(self):
        """
        Method for sending a break to the server from an external request. A
        separate write buffer is used in order to avoid a potential conflict
        with any in progress writes.
        """
        cdef WriteBuffer buf
        if not self._break_in_progress and self._request_lock.locked():
            self._break_in_progress = True
            if self._caps.can_use_oob:
                if DEBUG_PACKETS:
                    now = datetime.datetime.now()
                    print(now.isoformat(sep=" ", timespec="milliseconds"),
                          f"[socket: {self._socket.fileno()}]",
                          "Sending out of band break")
                    print()
                self._socket.send(b"!", socket.MSG_OOB)
            else:
                buf = WriteBuffer(self._socket, TNS_SDU, self._caps)
                self._send_marker(buf, TNS_MARKER_TYPE_INTERRUPT)

    cpdef int _close(self, bint drcp_enabled) except -1:
        cdef WriteBuffer buf = self._write_buf
        if self._read_buf._socket is None:
            return 0
        with self._request_lock:
            if self._txn_in_progress:
                self._process_message(RollbackMessage())
            if not drcp_enabled:
                self._process_message(LogoffMessage())

            # if using DRCP, send session release
            if drcp_enabled:
                buf.start_request(TNS_PACKET_TYPE_DATA)
                buf.write_uint8(TNS_MSG_TYPE_ONEWAY_FN)
                buf.write_uint8(TNS_FUNC_SESSION_RELEASE)
                buf.write_uint8(0)          # seq number
                buf.write_uint8(0)          # pointer (tag name)
                buf.write_uint8(0)          # tag name length
                buf.write_ub4(0)            # mode
                buf.end_request()

            # send final close
            buf.start_request(TNS_PACKET_TYPE_DATA, 0x0040)
            buf.end_request()
            self._socket.shutdown(socket.SHUT_RDWR)
            self._socket.close()

    cdef int _commit(self) except -1:
        with self._request_lock:
            self._process_message(CommitMessage())

    cdef _connect(self, ThinConnImpl conn, bint secure_transport,
                  str connect_string, str password, uint32_t auth_mode,
                  bint can_use_oob):
        cdef:
            ConnectMessage connect_message
            object temp_sock, ssl_context
            AuthMessage auth_message
            uint8_t packet_type

        # verify that a password has been specified first
        if password is None:
            errors._raise_from_string(exceptions.DatabaseError,
                                      "no password specified")

        # store whether OOB processing is possible or not
        self._caps.can_use_oob = can_use_oob

        # send connect message and process response; this requests the message
        # to be resent so the message is sent again; however, if a secure
        # transport is being used, a new socket needs to be created in order
        # for the TLS negotiation to be repeated (since the socket is handed
        # over to a different process)
        connect_message = ConnectMessage(connect_string)
        self._process_message(connect_message)
        if connect_message.redirect_data is not None:
            return connect_message.redirect_data
        if secure_transport:
            ssl_context = self._socket.context
            temp_sock = socket.socket(fileno=self._socket.detach())
            self.__set_socket(ssl_context.wrap_socket(temp_sock))
        self._process_message(connect_message)

        # if we can use OOB, send an urgent message now followed by a reset
        # marker to see if the server understands it
        if self._caps.can_use_oob \
                and self._caps.protocol_version >= TNS_VERSION_MIN_OOB_CHECK:
            self._oob_check_in_progress = True
            self._socket.send(b"!", socket.MSG_OOB)
            self._send_marker(self._write_buf, TNS_MARKER_TYPE_RESET)

        # send services, protocol and data types messages and process responses
        self._process_message(NetworkServicesMessage())
        self._process_message(ProtocolMessage())
        self._process_message(DataTypesMessage())

        # OOB check has at this point received the control message so flag can
        # be cleared
        self._oob_check_in_progress = False

        # send authorization packet twice, the first time to get the session
        # key and the second time to return the response to the challenge
        auth_message = AuthMessage(conn, password)
        auth_message._set_auth_mode(auth_mode)
        self._process_message(auth_message)
        self._process_message(auth_message)

    cdef int _execute(self, object cursor, uint32_t num_execs=1,
                      bint arraydmlrowcounts=False,
                      bint batcherrors=False) except -1:
        cdef:
            ThinCursorImpl cursor_impl = cursor._impl
            Statement stmt = cursor_impl._statement
            MessageWithData message
        with self._request_lock:
            if stmt._cursor_id and not stmt._requires_full_execute:
                message = ReExecuteMessage(cursor)
            else:
                message = ExecuteMessage(cursor)
            message.arraydmlrowcounts = arraydmlrowcounts
            message.batcherrors = batcherrors
            message.num_execs = num_execs
            self._process_message(message)
            if message.requires_define:
                message.processed_error = False
                self._process_message(message)
            stmt._requires_full_execute = False
            if cursor_impl._statement._is_query:
                cursor_impl.rowcount = 0

    cdef int _fetch(self, object cursor) except -1:
        cdef:
            ThinCursorImpl cursor_impl = cursor._impl
            MessageWithData message
        with self._request_lock:
            if cursor_impl._requires_full_execute:
                message = ExecuteMessage(cursor)
                message.num_execs = cursor_impl._fetch_array_size
            else:
                message = FetchMessage(cursor)
            self._process_message(message)

    cdef int _parse(self, object cursor) except -1:
        cdef MessageWithData message
        with self._request_lock:
            message = ExecuteMessage(cursor)
            message.parse_only = True
            self._process_message(message)

    cdef int _ping(self) except -1:
        with self._request_lock:
            self._process_message(PingMessage())

    cdef int _process_message(self, Message message) except -1:
        try:
            message.send(self._write_buf)
            self._receive_packet(message)
            message.process(self._read_buf)
        except:
            if self._write_buf._packet_sent \
                    and self._read_buf._socket is not None:
                self._send_marker(self._write_buf, TNS_MARKER_TYPE_BREAK)
                self._receive_packet(message)
            raise
        if self._break_in_progress:
            if self._caps.can_use_oob:
                self._send_marker(self._write_buf, TNS_MARKER_TYPE_INTERRUPT)
            self._receive_packet(message)
            message.process(self._read_buf)
            self._break_in_progress = False
        self._txn_in_progress = message.call_status & TNS_TXN_IN_PROGRESS
        if message.error_occurred:
            error = errors._Error(message.error_info.message,
                                  code=message.error_info.num,
                                  offset=message.error_info.pos)
            exc_type = get_exception_class(message.error_info.num)
            raise exc_type(error)

    cdef int _receive_packet(self, Message message) except -1:
        self._read_buf.receive_packet(&message.packet_type)
        if message.packet_type == TNS_PACKET_TYPE_MARKER:
            self._reset(message)
            message.error_occurred = True
        elif message.packet_type == TNS_PACKET_TYPE_CONTROL:
            if self._oob_check_in_progress:
                self._caps.can_use_oob = False
            self._read_buf.receive_packet(&message.packet_type)
        elif message.packet_type == TNS_PACKET_TYPE_REFUSE:
            self._write_buf._packet_sent = False
            self._read_buf.skip_bytes(3)
            response = self._read_buf.read_str(self._read_buf.read_uint8())
            error_code = "unknown"
            error_code_int = 0
            pos = response.find("(ERR=")
            if pos > 0:
                end_pos = response.find(")", pos)
                if end_pos > 0:
                    error_code = response[pos + 5:end_pos]
                    error_code_int = int(error_code)
            error_msg = f"server refused connection with error {error_code}"
            error = errors._Error(message=error_msg, code=error_code_int)
            exc_type = get_exception_class(error_code_int)
            raise exc_type(error)

    cdef int _reset(self, Message message) except -1:

        # send reset marker
        self._send_marker(self._write_buf, TNS_MARKER_TYPE_RESET)

        # read and discard all packets until a marker packet is received
        while True:
            if message.packet_type == TNS_PACKET_TYPE_MARKER:
                self._read_buf.skip_bytes(2)
                if self._read_buf.read_uint8() == TNS_MARKER_TYPE_RESET:
                    break
            self._read_buf.receive_packet(&message.packet_type)

        # read error packet; first skip as many marker packets as may be sent
        # by the server; if the server doesn't handle out-of-band breaks
        # properly, some quit immediately and others send multiple reset
        # markers (this addresses both situations without resulting in strange
        # errors)
        while message.packet_type == TNS_PACKET_TYPE_MARKER:
            self._read_buf.receive_packet(&message.packet_type)
        self._break_in_progress = False

    cdef int _rollback(self) except -1:
        with self._request_lock:
            self._process_message(RollbackMessage())

    cdef int _send_marker(self, WriteBuffer buf, uint8_t marker_type):
        """
        Sends a marker of the specified type to the server.
        Internal method for sending a break to the server.
        """
        buf.start_request(TNS_PACKET_TYPE_MARKER)
        buf.write_uint8(1)
        buf.write_uint8(0)
        buf.write_uint8(marker_type)
        buf.end_request()
