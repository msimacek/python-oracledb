#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class Protocol:

    cdef:
        uint8_t _seq_num
        object _socket
        ReadBuffer _read_buf
        WriteBuffer _write_buf
        _OracleErrorInfo _error_info

    def __init__(self, sock):
        self._socket = sock
        self._read_buf = ReadBuffer(sock, TNS_SDU)
        self._write_buf = WriteBuffer(sock, TNS_SDU)

    cdef int _close(self) except -1:
        self._rollback()                    # rollback any transaction first
        self._process_message(LogoffMessage())

        # send final close
        self._write_buf.start_request(TNS_PACKET_TYPE_DATA, 0x0040)
        self._write_buf.end_request()
        self._socket.close()

    cdef int _commit(self) except -1:
        self._process_message(CommitMessage())

    cdef _connect(self, Connection conn, str connect_string, str password):
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
        self._read_buf._protocol_version = connect_message.version
        self._write_buf._protocol_version = connect_message.version

        # send services, protocol and data types messages and process responses
        self._process_message(NetworkServicesMessage())
        self._process_message(ProtocolMessage())
        self._process_message(DataTypesMessage())

        # send authorization packet twice, the first time to get the session
        # key and the second time to return the response to the challenge
        auth_message = AuthMessage(conn, password)
        self._process_message(auth_message)
        self._process_message(auth_message)

    cdef int _execute(self, Cursor cursor, uint32_t num_execs=1,
                      bint arraydmlrowcounts=False,
                      bint batcherrors=False) except -1:
        cdef ExecuteMessage message = ExecuteMessage(cursor)
        message.arraydmlrowcounts = arraydmlrowcounts
        message.batcherrors = batcherrors
        message.num_execs = num_execs
        self._process_message(message)

    cdef int _fetch(self, Cursor cursor) except -1:
        self._process_message(FetchMessage(cursor))

    cdef int _ping(self) except -1:
        self._process_message(PingMessage())

    cdef int _process_message(self, Message message) except -1:
        message.send(self._write_buf)
        self._receive_packet(message)
        message.process(self._read_buf)
        if message.error_occurred:
            error = errors._Error(message.error_info.message,
                                  code=message.error_info.num,
                                  offset=message.error_info.pos)
            exc_type = get_exception_class(message.error_info.num)
            raise exc_type(error)

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

    cdef int _receive_packet(self, Message message) except -1:
        cdef:
            WriteBuffer buf = self._write_buf
            uint8_t packet_type
        self._read_buf.receive_packet(&packet_type)
        if packet_type == TNS_PACKET_TYPE_MARKER:

            # on error a second packet is sent which is ignored
            self._read_buf.receive_packet(&packet_type)

            # write error request
            buf.start_request(TNS_PACKET_TYPE_MARKER)
            buf.write_bytes(b'\x01\x00\x02')
            buf.end_request()
            self._read_buf.receive_packet(&packet_type)
            message.error_occurred = True

    cdef int _rollback(self) except -1:
        self._process_message(RollbackMessage())
