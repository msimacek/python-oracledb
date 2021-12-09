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
        bint _in_connect
        bint _txn_in_progress
        bint _break_in_progress
        bint _session_needs_to_be_closed

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
            if self._caps.supports_oob:
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

    cdef _change_password(self, ThinConnImpl conn, str old_password,
                          str new_password):
        cdef AuthMessage auth_message
        auth_message = AuthMessage(conn, old_password, new_password)
        self._process_message(auth_message)
        self._process_message(auth_message)

    cdef _connect(self, ThinConnImpl conn, object params, str connect_string,
                  str password, str newpassword):
        cdef:
            ConnectMessage connect_message
            object temp_sock, ssl_context
            AuthMessage auth_message
            uint8_t packet_type

        # mark protocol to indicate that connect is in progress; this prevents
        # the normal break/reset mechanism from firing, which is unnecessary
        # since the connection is going to be immediately closed anyway!
        self._in_connect = True

        # store whether OOB processing is possible or not
        self._caps.supports_oob = params._supports_oob()

        # send connect message and process response; this may request the
        # message to be resent multiple times; if a redirect packet is
        # detected, however, the process terminates and is restarted using the
        # supplied redirect data
        connect_message = ConnectMessage(connect_string)
        while True:
            self._process_message(connect_message)
            if connect_message.redirect_data is not None:
                return connect_message.redirect_data
            if connect_message.packet_type == TNS_PACKET_TYPE_ACCEPT:
                break
            if params.protocol == "tcps" \
                    and params.wallet_location is not None:
                ssl_context = self._socket.context
                sock = socket.socket(fileno=self._socket.detach())
                sock = ssl_context.wrap_socket(sock)
                self.__set_socket(sock)

        # check if the protocol version supported by the database is high
        # enough; if not, reject the connection immediately
        if self._caps.protocol_version < TNS_VERSION_MIN_ACCEPTED:
            errors._raise_err(errors.ERR_SERVER_VERSION_NOT_SUPPORTED)

        # if we can use OOB, send an urgent message now followed by a reset
        # marker to see if the server understands it
        if self._caps.supports_oob \
                and self._caps.protocol_version >= TNS_VERSION_MIN_OOB_CHECK:
            self._socket.send(b"!", socket.MSG_OOB)
            self._send_marker(self._write_buf, TNS_MARKER_TYPE_RESET)

        # send services, protocol and data types messages and process responses
        self._process_message(NetworkServicesMessage())
        self._process_message(ProtocolMessage())
        self._process_message(DataTypesMessage())

        # send authorization packet twice, the first time to get the session
        # key and the second time to return the response to the challenge
        auth_message = AuthMessage(conn, password, newpassword)
        auth_message._set_auth_mode(params.mode)
        auth_message.cclass = params.cclass
        auth_message.purity = params.purity
        self._process_message(auth_message)
        self._process_message(auth_message)

        # mark protocol to indicate that connect is no longer in progress; this
        # allows the normal break/reset mechanism to fire
        self._in_connect = False

    cdef int _execute(self, object cursor, uint32_t num_execs=1,
                      bint arraydmlrowcounts=False,
                      bint batcherrors=False, uint32_t offset=0) except -1:
        cdef:
            ThinCursorImpl cursor_impl = cursor._impl
            Statement stmt = cursor_impl._statement
            MessageWithData message
        with self._request_lock:
            if stmt._cursor_id and not stmt._requires_full_execute \
                    and not stmt._is_ddl:
                message = ReExecuteMessage(cursor)
            else:
                message = ExecuteMessage(cursor)
            message.arraydmlrowcounts = arraydmlrowcounts
            message.batcherrors = batcherrors
            message.num_execs = num_execs
            message.offset = offset
            self._process_message(message)
            if cursor_impl._statement._requires_define:
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

    cdef int _process_control_packet(self, ReadBuffer buf) except -1:
        cdef uint16_t control_type, error_num
        control_type = buf.read_uint16()
        if control_type == TNS_CONTROL_TYPE_RESET_OOB:
            self._caps.supports_oob = False
        elif control_type == TNS_CONTROL_TYPE_INBAND_NOTIFICATION:
            buf.skip_bytes(6)           # skip flags
            error_num = buf.read_uint16()
            if error_num == TNS_ERR_SESSION_SHUTDOWN \
                    or error_num == TNS_ERR_INBAND_MESSAGE:
                self._session_needs_to_be_closed = True
            else:
                errors._raise_err(errors.ERR_UNSUPPORTED_INBAND_NOTIFICATION,
                                  error_num)

    cdef int _process_message(self, Message message) except -1:
        try:
            message.send(self._write_buf)
            self._receive_packet(message)
            message.process(self._read_buf)
        except:
            if not self._in_connect \
                    and self._write_buf._packet_sent \
                    and self._read_buf._socket is not None:
                self._send_marker(self._write_buf, TNS_MARKER_TYPE_BREAK)
                self._reset(message)
            raise
        if message.flush_out_binds:
            self._write_buf.start_request(TNS_PACKET_TYPE_DATA)
            self._write_buf.write_uint8(TNS_MSG_TYPE_FLUSH_OUT_BINDS)
            self._write_buf.end_request()
            self._reset(message)
            message.process(self._read_buf)
        if self._break_in_progress:
            if self._caps.supports_oob:
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
            self._process_control_packet(self._read_buf)
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
            if error_code_int == TNS_ERR_INVALID_SERVICE_NAME:
                errors._raise_err(errors.ERR_INVALID_SERVICE_NAME,
                                  f"see ORA-{error_code}")
            elif error_code_int == TNS_ERR_INVALID_SID:
                errors._raise_err(errors.ERR_INVALID_SID,
                                  f"see ORA-{error_code}")
            errors._raise_err(errors.ERR_LISTENER_REFUSED_CONNECTION,
                              error_code=error_code)

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
