#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

# cython: language_level=3

from libc.stdint cimport int8_t, int16_t, int32_t, int64_t
from libc.stdint cimport uint8_t, uint16_t, uint32_t, uint64_t

from .. import exceptions

cdef int32_t* INTEGRITY_CODES = [
        1,          # unique constraint violated
        1400,       # cannot insert NULL
        2290,       # check constraint violated
        2291,       # integrity constraint violated - parent key not found
        2292,       # integrity constraint violated - child record found
        40479,      # internal JSON serializer error
        0
]


cdef int is_code_in_array(int32_t code, int32_t *ptr):
    cdef int ix = 0
    while ptr[ix] != 0:
        print("Checking error code:", ptr[ix])
        if ptr[ix] == code:
            return 1
        ix += 1
    return 0


cdef object get_exception_class(int32_t code):
    if is_code_in_array(code, INTEGRITY_CODES):
        return exceptions.IntegrityError
    return exceptions.DatabaseError


cdef class Connection:

    def __init__(self, user, dsn):
        self.user = user
        self.dsn = dsn

    def __repr__(self):
        cls_name = type(self).__name__
        if self.user is None:
            return f"{cls_name} to externally identified user"
        return f"{cls_name} to {self.user}@{self.dsn}"
