#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# buffer.pyx
#   Cython file for the StringBuffer class (embedded in driver.pyx).
#------------------------------------------------------------------------------

cdef class StringBuffer:
    cdef:
        bytes obj
        const char *ptr
        uint32_t length
        uint32_t size_in_chars

    cdef int set_value(self, value) except -1:
        if value is None:
            self.obj = None
            self.ptr = NULL
            self.length = self.size_in_chars = 0
            return 0
        elif isinstance(value, str):
            self.obj = value.encode()
            self.size_in_chars = <uint32_t> len(value)
        elif isinstance(value, bytes):
            self.obj = value
            self.size_in_chars = <uint32_t> len(value)
        else:
            raise TypeError("expecting string or bytes")
        self.ptr = self.obj
        self.length = <uint32_t> len(self.obj)
