#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# var.pyx
#   Cython file defining the variable class (embedded in driver.pyx).
#------------------------------------------------------------------------------

cdef class Var(BaseVar):
    cdef:
        readonly uint32_t buffer_size
        dpiVar *_handle
        dpiData *_data
        Connection _connection
        uint32_t _native_type_num
        bint _number_as_int

    def __dealloc__(self):
        if self._handle != NULL:
            dpiVar_release(self._handle)

    cdef uint32_t _get_actual_elements(self) except *:
        cdef uint32_t num_elements
        if not self.is_array:
            return self.num_elements
        if dpiVar_getNumElementsInArray(self._handle, &num_elements) < 0:
            _raise_from_odpi()
        return num_elements

    cdef list _get_array_value(self, uint32_t num_elements, dpiData *data):
        cdef:
            list return_value
            object element_value
            uint32_t i
        return_value = cpython.PyList_New(num_elements)
        for i in range(num_elements):
            element_value = self._get_single_value(data, i)
            cpython.Py_INCREF(element_value)
            cpython.PyList_SET_ITEM(return_value, i, element_value)
        return return_value

    cdef object _get_single_value(self, dpiData *data, uint32_t pos):
        cdef object value
        if data:
            data = &data[pos]
        else:
            data = &self._data[pos]
        if data.isNull:
            return None
        value = _convert_to_python(self._connection, self.type, &data.value,
                                   self._number_as_int)
        if self.outconverter:
            value = self.outconverter(value)
        return value

    @staticmethod
    cdef Var new_var(Connection connection, DbType dbtype,
                     uint32_t num_elements, uint32_t size,
                     bint is_array=False):
        cdef Var var = Var.__new__(Var)
        var._connection = connection
        var.type = dbtype
        var.size = size
        var.num_elements = num_elements
        var.is_array = is_array
        var._native_type_num = _get_native_type_num(dbtype)
        if dpiConn_newVar(connection._handle, dbtype.num, var._native_type_num,
                          num_elements, size, 0, is_array, NULL,
                          &var._handle, &var._data) < 0:
            _raise_from_odpi()
        if dpiVar_getSizeInBytes(var._handle, &var.buffer_size) < 0:
            _raise_from_odpi()
        return var

    @property
    def actualElements(self):
        return self._get_actual_elements()

    @property
    def bufferSize(self):
        return self.buffer_size

    @property
    def numElements(self):
        return self.num_elements

    @property
    def values(self):
        pass
