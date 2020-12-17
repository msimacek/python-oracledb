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
        cdef Connection conn = self._connection
        conn._protocol._process_lob_op(TNS_LOB_OP_CLOSE, source_lob=self,
                                       source_offset=0, dest_lob=None,
                                       dest_offset=0, amount=NULL, data=None)

    @staticmethod
    cdef Lob _create_temp_lob(Connection conn, DbType lob_type):
        cdef:
            uint64_t amount = TNS_DURATION_SESSION
            Lob lob = Lob.__new__(Lob)
        lob.type = lob_type
        lob._connection = conn
        lob._locator = bytes(40)
        conn._protocol._process_lob_op(TNS_LOB_OP_CREATE_TEMP, source_lob=lob,
                                       source_offset=lob_type._csfrm,
                                       dest_lob=None,
                                       dest_offset=lob_type._ora_type_num,
                                       amount=&amount, data=None)
        return lob

    cdef int _get_max_amount(self, uint64_t* max_amount) except -1:
        max_amount[0] = 2**32 - 1

    cdef int _get_is_open(self, bint* is_open) except -1:
        cdef Connection conn = self._connection
        is_open[0] = conn._protocol._process_lob_op(TNS_LOB_OP_IS_OPEN,
                                                    source_lob=self,
                                                    source_offset=0,
                                                    dest_lob=None,
                                                    dest_offset=0,
                                                    amount=NULL, data=None)

    cdef int _get_size(self, uint64_t* size) except -1:
        cdef Connection conn = self._connection
        conn._protocol._process_lob_op(TNS_LOB_OP_GET_LENGTH, source_lob=self,
                                       source_offset=0, dest_lob=None,
                                       dest_offset=0, amount=size, data=None)

    cdef int _open(self) except -1:
        cdef Connection conn = self._connection
        conn._protocol._process_lob_op(TNS_LOB_OP_OPEN, source_lob=self,
                                       source_offset=0, dest_lob=None,
                                       dest_offset=0, amount=NULL, data=None)

    cdef object _read(self, uint64_t offset, uint64_t amount):
        cdef Connection conn = self._connection
        val = conn._protocol._process_lob_op(TNS_LOB_OP_READ, source_lob=self,
                                             source_offset=offset,
                                             dest_lob=None, dest_offset=0,
                                             amount=&amount, data=None)
        if val is None:
            if self.type._ora_type_num == TNS_DATA_TYPE_BLOB:
                return b""
            return ""
        return val

    cdef int _trim(self, uint64_t new_size=0) except -1:
        cdef Connection conn = self._connection
        conn._protocol._process_lob_op(TNS_LOB_OP_TRIM, source_lob=self,
                                       source_offset=0, dest_lob=None,
                                       dest_offset=0, amount=&new_size,
                                       data=None)

    cdef int _write(self, object value, uint64_t offset) except -1:
        cdef:
            Connection conn = self._connection
            uint64_t amount = <uint64_t> len(value)
            bytes data
        if self.type._ora_type_num == TNS_DATA_TYPE_BLOB:
            data = value
        else:
            data = value.encode(TNS_ENCODING_UTF16)
        conn._protocol._process_lob_op(TNS_LOB_OP_WRITE, source_lob=self,
                                       source_offset=offset, dest_lob=None,
                                       dest_offset=0, amount=&amount,
                                       data=data)
