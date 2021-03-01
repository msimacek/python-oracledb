#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# lob.pyx
#   Cython file defining the Lob class (embedded in driver.pyx).
#------------------------------------------------------------------------------

cdef class Lob(BaseLob):
    cdef:
        bytes _locator

    cdef int _close(self) except -1:
        cdef:
            ThinConnImpl conn = self._connection
            LobOpMessage message = LobOpMessage()
        message.operation = TNS_LOB_OP_CLOSE
        message.source_lob = self
        conn._protocol._process_message(message)

    @staticmethod
    cdef Lob _create_temp_lob(ThinConnImpl conn, DbType lob_type):
        cdef:
            LobOpMessage message = LobOpMessage()
            Lob lob = Lob.__new__(Lob)
        lob.type = lob_type
        lob._connection = conn
        lob._locator = bytes(40)
        message.operation = TNS_LOB_OP_CREATE_TEMP
        message.amount = TNS_DURATION_SESSION
        message.send_amount = True
        message.source_lob = lob
        message.source_offset = lob_type._csfrm
        message.dest_offset = lob_type._ora_type_num
        conn._protocol._process_message(message)
        return lob

    cdef str _get_encoding(self):
        if self.type._csfrm == TNS_CS_NCHAR \
                or self._locator[TNS_LOB_LOCATOR_OFFSET_FLAG_3] & \
                TNS_LOB_LOCATOR_VAR_LENGTH_CHARSET:
            return TNS_ENCODING_UTF16
        return TNS_ENCODING_UTF8

    cdef int _get_max_amount(self, uint64_t* max_amount) except -1:
        max_amount[0] = 2**32 - 1

    cdef int _get_is_open(self, bint* is_open) except -1:
        cdef:
            ThinConnImpl conn = self._connection
            LobOpMessage message = LobOpMessage()
        message.operation = TNS_LOB_OP_IS_OPEN
        message.source_lob = self
        conn._protocol._process_message(message)
        is_open[0] = message.bool_flag

    cdef int _get_size(self, uint64_t* size) except -1:
        cdef:
            ThinConnImpl conn = self._connection
            LobOpMessage message = LobOpMessage()
        message.operation = TNS_LOB_OP_GET_LENGTH
        message.source_lob = self
        message.send_amount = True
        conn._protocol._process_message(message)
        size[0] = message.amount

    cdef int _open(self) except -1:
        cdef:
            ThinConnImpl conn = self._connection
            LobOpMessage message = LobOpMessage()
        message.operation = TNS_LOB_OP_OPEN
        message.source_lob = self
        conn._protocol._process_message(message)

    cdef object _read(self, uint64_t offset, uint64_t amount):
        cdef:
            ThinConnImpl conn = self._connection
            LobOpMessage message = LobOpMessage()
        message.operation = TNS_LOB_OP_READ
        message.source_lob = self
        message.source_offset = offset
        message.amount = amount
        message.send_amount = True
        conn._protocol._process_message(message)
        if message.data is None:
            if self.type._ora_type_num == TNS_DATA_TYPE_BLOB:
                return b""
            return ""
        return message.data

    cdef int _trim(self, uint64_t new_size=0) except -1:
        cdef:
            ThinConnImpl conn = self._connection
            LobOpMessage message = LobOpMessage()
        message.operation = TNS_LOB_OP_TRIM
        message.source_lob = self
        message.amount = new_size
        message.send_amount = True
        conn._protocol._process_message(message)

    cdef int _write(self, object value, uint64_t offset) except -1:
        cdef:
            ThinConnImpl conn = self._connection
            LobOpMessage message = LobOpMessage()
        message.operation = TNS_LOB_OP_WRITE
        message.source_lob = self
        message.source_offset = offset
        message.amount = <uint64_t> len(value)
        message.send_amount = True
        if self.type._ora_type_num == TNS_DATA_TYPE_BLOB:
            message.data = value
        else:
            message.data = value.encode(self._get_encoding())
        conn._protocol._process_message(message)
