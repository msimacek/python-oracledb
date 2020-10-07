#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# var.pyx
#   Cython file defining the variable class (embedded in driver.pyx).
#------------------------------------------------------------------------------

cdef class Var(BaseVar):
    cdef:
        Connection _connection
        str _name
        int16_t _precision
        int16_t _scale
        list _values
        char_type *_buf

    def __cinit__(self, connection):
        self._connection = connection

    def __dealloc__(self):
        cpython.PyMem_Free(self._buf)

    cdef int _finalize_init(self) except -1:
        if self.type.default_size > 0:
            self._buf = <char_type*> cpython.PyMem_Malloc(self.buffer_size)
            if not self._buf:
                raise MemoryError()
        self._values = [None] * self.num_elements

    cdef object _get_single_value(self, uint32_t pos):
        return self._values[pos]

    cdef int _set_single_value(self, uint32_t pos, object value) except -1:
        if self.inconverter:
            value = self.inconverter(value)
        self._values[pos] = value
