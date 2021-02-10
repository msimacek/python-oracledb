#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef extern from "impl/thin/bswap.c":

    int BYTE_ORDER_LSB
    int BYTE_ORDER_MSB

    cdef void pack_uint16(char_type *buf, uint16_t x, int order);
    cdef void pack_uint32(char_type *buf, uint32_t x, int order);
    cdef void pack_uint64(char_type *buf, uint64_t x, int order);
    cdef uint16_t unpack_uint16(const char_type *buf, int order);
    cdef uint32_t unpack_uint32(const char_type *buf, int order);
    cdef uint64_t unpack_uint64(const char_type *buf, int order);
