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

    cdef int _get_size(self, uint64_t* size) except -1:
        cdef Connection conn = self._connection
        conn._protocol._process_lob_op(TNS_LOB_OP_GET_LENGTH, source_lob=self,
                                       source_offset=0, dest_lob=None,
                                       dest_offset=0, amount=size)

    cdef object _read(self, uint64_t offset, uint64_t amount):
        cdef Connection conn = self._connection
        return conn._protocol._process_lob_op(TNS_LOB_OP_READ, source_lob=self,
                                              source_offset=offset,
                                              dest_lob=None, dest_offset=0,
                                              amount=&amount)
