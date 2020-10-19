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
        list _values

    def __cinit__(self, connection):
        self._connection = connection

    cdef int _finalize_init(self) except -1:
        self._values = [None] * self.num_elements

    cdef object _get_single_value(self, uint32_t pos):
        return self._values[pos]

    cdef int _set_single_value(self, uint32_t pos, object value) except -1:
        if self.inconverter:
            value = self.inconverter(value)
        self._values[pos] = value
