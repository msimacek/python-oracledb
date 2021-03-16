#------------------------------------------------------------------------------
# Copyright (c) 2020, 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class Protocol:

    cdef:
        uint8_t _seq_num
        object _socket
        ReadBuffer _read_buf
        WriteBuffer _write_buf

    def __init__(self, sock):
        self._socket = sock
        caps = Capabilities()
        self._read_buf = ReadBuffer(sock, TNS_SDU, caps)
        self._write_buf = WriteBuffer(sock, TNS_SDU, caps)

    cdef int _break(self):
        cdef WriteBuffer buf = self._write_buf
        buf.start_request(TNS_PACKET_TYPE_MARKER)
        buf.write_uint8(1)
        buf.write_uint8(0)
        buf.write_uint8(TNS_MARKER_TYPE_BREAK)
        buf.end_request()

    cpdef int _close(self) except -1:
        self._rollback()                    # rollback any transaction first
        self._process_message(LogoffMessage())

        # send final close
        self._write_buf.start_request(TNS_PACKET_TYPE_DATA, 0x0040)
        self._write_buf.end_request()
        self._socket.shutdown(socket.SHUT_RDWR)
        self._socket.close()

    cdef int _commit(self) except -1:
        self._process_message(CommitMessage())

    cdef _connect(self, ThinConnImpl conn, str connect_string, str password):
        cdef:
            ConnectMessage connect_message
            AuthMessage auth_message

        # verify that a password has been specified first
        if password is None:
            errors._raise_from_string(exceptions.DatabaseError,
                                      "no password specified")

        # send connect message and process response; this requests the message
        # to be resent so the message is sent again
        connect_message = ConnectMessage(connect_string)
        self._process_message(connect_message)
        self._process_message(connect_message)

        # send services, protocol and data types messages and process responses
        self._process_message(NetworkServicesMessage())
        self._process_message(ProtocolMessage())
        self._process_message(DataTypesMessage())

        # send authorization packet twice, the first time to get the session
        # key and the second time to return the response to the challenge
        auth_message = AuthMessage(conn, password)
        self._process_message(auth_message)
        self._process_message(auth_message)

    cdef int _execute(self, object cursor, uint32_t num_execs=1,
                      bint arraydmlrowcounts=False,
                      bint batcherrors=False) except -1:
        cdef:
            ThinCursorImpl cursor_impl = cursor._impl
            Statement stmt = cursor_impl._statement
            MessageWithData message
        if stmt._cursor_id and not stmt._requires_full_execute:
            message = <MessageWithData> ReExecuteMessage(cursor)
        else:
            message = <MessageWithData> ExecuteMessage(cursor)
        message.arraydmlrowcounts = arraydmlrowcounts
        message.batcherrors = batcherrors
        message.num_execs = num_execs
        self._process_message(message)
        if message.requires_define:
            self._process_message(message)
        stmt._requires_full_execute = False
        if cursor_impl._statement._is_query:
            cursor_impl.rowcount = 0

    cdef int _fetch(self, object cursor) except -1:
        cdef:
            ThinCursorImpl cursor_impl = cursor._impl
            MessageWithData message
        if cursor_impl._requires_full_execute:
            message = <MessageWithData> ExecuteMessage(cursor)
            message.num_execs = cursor_impl._fetch_array_size
            self._process_message(message)
        else:
            self._process_message(FetchMessage(cursor))

    cdef int _ping(self) except -1:
        self._process_message(PingMessage())

    cdef int _process_message(self, Message message) except -1:
        try:
            message.send(self._write_buf)
            self._receive_packet(message)
            message.process(self._read_buf)
        except:
            if self._write_buf._packet_sent \
                    and self._read_buf._socket is not None:
                self._break()
                self._reset()
            raise
        if message.error_occurred:
            error = errors._Error(message.error_info.message,
                                  code=message.error_info.num,
                                  offset=message.error_info.pos)
            exc_type = get_exception_class(message.error_info.num)
            raise exc_type(error)

    cdef int _receive_packet(self, Message message) except -1:
        cdef:
            WriteBuffer buf = self._write_buf
            uint8_t packet_type
        self._read_buf.receive_packet(&packet_type)
        if packet_type == TNS_PACKET_TYPE_MARKER:
            self._reset()
            message.error_occurred = True

    cdef int _reset(self):
        cdef:
            WriteBuffer buf = self._write_buf
            uint8_t packet_type

        # send marker packet indicating a reset is desired
        buf.start_request(TNS_PACKET_TYPE_MARKER)
        buf.write_uint8(1)
        buf.write_uint8(0)
        buf.write_uint8(TNS_MARKER_TYPE_RESET)
        buf.end_request()

        # read and discard all packets until a marker packet is received
        while True:
            self._read_buf.receive_packet(&packet_type)
            if packet_type == TNS_PACKET_TYPE_MARKER:
                break

        # read error packet
        self._read_buf.receive_packet(&packet_type)

    cdef int _rollback(self) except -1:
        self._process_message(RollbackMessage())
