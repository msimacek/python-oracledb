#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class BaseVar:

    def __repr__(self):
        return f"<Var {self.name}>"

    cdef int _finalize_init(self) except -1:
        """
        Finalizes initialization.
        """

    cdef uint32_t _get_actual_elements(self) except *:
        """
        Return the number of elements in the variable. This will either be the
        number of elements in a PL/SQL array or the number of elements that
        were originally allocated for the variable.
        """

    cdef list _get_array_value(self, uint32_t num_elements):
        """
        Return the values stored in the variable as a list.
        """
    
    cdef object _get_single_value(self, uint32_t pos):
        """
        Return the value stored in the variable at the specified position.
        """

    def __repr__(self):
        if self.is_array:
            num_elems = self._get_actual_elements()
            value = self._get_array_value(num_elems)
        elif self.num_elements == 1:
            value = self._get_single_value(0)
        else:
            value = self._get_array_value(self.num_elements)
        return f"Var of type {self.type.name} with value {repr(value)}"

    @property
    def actualElements(self):
        return self._get_actual_elements()

    @property
    def actual_elements(self):
        return self._get_actual_elements()

    @property
    def bufferSize(self):
        return self.buffer_size

    def getvalue(self, pos=0):
        """
        Return the value at the given position in the variable.
        """
        if self.is_array:
            num_elems = self._get_actual_elements()
            return self._get_array_value(num_elems)
        if pos >= self.num_elements:
            raise IndexError("position out of range")
        return self._get_single_value(pos)

    @property
    def numElements(self):
        return self.num_elements

    @property
    def values(self):
        num_elems = self._get_actual_elements()
        return self._get_array_value(num_elems)
