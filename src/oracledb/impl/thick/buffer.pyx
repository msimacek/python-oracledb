#------------------------------------------------------------------------------
# Copyright (c) 2020, 2022, Oracle and/or its affiliates.
# This program is free software: you can modify it and/or redistribute it
# under the terms of:
#
# (i)  the Universal Permissive License v 1.0 or at your option, any
#      later version (http://oss.oracle.com/licenses/upl); and/or
#
# (ii) the Apache License v 2.0. (http://www.apache.org/licenses/LICENSE-2.0)
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# buffer.pyx
#
# Cython file defining the StringBuffer class, used for transforming Python
# "str" and "bytes" objects into the C buffer representation required by ODPI-C
# (embedded in thick_impl.pyx).
#------------------------------------------------------------------------------

@cython.freelist(20)
cdef class StringBuffer:
    cdef:
        bytes obj
        char *ptr
        uint32_t length
        uint32_t size_in_chars

    cdef int set_value(self, value) except -1:
        if value is None:
            self.obj = None
            self.ptr = NULL
            self.length = self.size_in_chars = 0
            return 0
        elif isinstance(value, str):
            self.obj = (<str> value).encode()
            self.size_in_chars = <uint32_t> len(<str> value)
        elif isinstance(value, bytes):
            self.obj = value
            self.size_in_chars = <uint32_t> len(<bytes> value)
        else:
            raise TypeError("expecting string or bytes")
        self.ptr = self.obj
        self.length = <uint32_t> len(self.obj)
