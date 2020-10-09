#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class BaseVar:

    def __repr__(self):
        if self.is_array:
            num_elems = self._get_actual_elements()
            value = self._get_array_value(num_elems)
        elif self.num_elements == 1:
            value = self._get_single_value(0)
        else:
            value = self._get_array_value(self.num_elements)
        return f"Var of type {self.type.name} with value {repr(value)}"

    cdef int _bind(self, BaseCursor cursor, str name=None,
                   uint32_t pos=0) except -1:
        """
        Binds a variable to the cursor. Intended to be overridden by the
        subclass.
        """

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

    cdef int _set_array_value(self, list value) except -1:
        """
        Set the array elements to the value of the list.
        """

    cdef int _set_single_value(self, uint32_t pos, object value) except -1:
        """
        Set a single element of the variable to the specified value.
        """

    cdef int _set_value(self, uint32_t pos, object value) except -1:
        """
        Internal method for setting the value of a variable which peforms all
        necessary checks.
        """
        if self.is_array:
            if pos > 0:
                errors._raise_from_string(exceptions.NotSupportedError,
                                          "arrays of arrays not supported")
            if not isinstance(value, list):
                raise TypeError("expecting list")
            elif len(value) > self.num_elements:
                raise TypeError("list too large for variable")
            self._set_array_value(value)
        else:
            if pos >= self.num_elements:
                raise IndexError("position out of range")
            self._set_single_value(pos, value)

    @property
    def actualElements(self):
        return self._get_actual_elements()

    @property
    def actual_elements(self):
        return self._get_actual_elements()

    @property
    def bufferSize(self):
        return self.buffer_size

    @property
    def description(self):
        if self.size > 0:
            display_size = self.size
        elif self.type is DB_TYPE_DATE or self.type is DB_TYPE_TIMESTAMP \
                or self.type is DB_TYPE_TIMESTAMP_LTZ \
                or self.type is DB_TYPE_TIMESTAMP_TZ:
            display_size = 23
        elif self.type is DB_TYPE_BINARY_FLOAT \
                or self.type is DB_TYPE_BINARY_DOUBLE \
                or self.type is DB_TYPE_BINARY_INTEGER \
                or self.type is DB_TYPE_NUMBER:
            if self.precision:
                display_size = self.precision + 1
                if self.scale > 0:
                    display_size += self.scale + 1
            else:
                display_size = 127
        else:
            display_size = 0
        size_in_bytes = self.buffer_size if self.type.default_size != 0 else 0
        if self.precision or self.scale:
            precision = self.precision
            scale = self.scale
        else:
            scale = precision = None
        return (self.name, self.type, display_size or None,
                size_in_bytes or None, precision, scale, self.nulls_allowed)

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

    def setvalue(self, pos=0, value=None):
        """
        Set the value at the specified position in the variable.
        """
        self._set_value(pos, value)

    @property
    def values(self):
        num_elems = self._get_actual_elements()
        return self._get_array_value(num_elems)
