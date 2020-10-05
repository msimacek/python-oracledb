#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef extern from "./hton.c":
    cdef void pack_int16(char_type *buf, int16_t x);
    cdef void pack_uint16(char_type *buf, uint16_t x);
    cdef void pack_int32(char_type *buf, int32_t x);
    cdef void pack_uint32(char_type *buf, uint32_t x);
    cdef void pack_int64(char_type *buf, int64_t x);
    cdef void pack_uint64(char_type *buf, uint64_t x);
    cdef int16_t unpack_int16(const char_type *buf);
    cdef uint16_t unpack_uint16(const char_type *buf);
    cdef int32_t unpack_int32(const char_type *buf);
    cdef uint32_t unpack_uint32(const char_type *buf);
    cdef int64_t unpack_int64(const char_type *buf);
    cdef uint64_t unpack_uint64(const char_type *buf);
