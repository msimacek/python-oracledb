#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# var.pyx
#   Cython file defining the variable class (embedded in driver.pyx).
#------------------------------------------------------------------------------

cdef class Var(BaseVar):
    cdef:
        dpiVar *_handle
        dpiData *_data
        Connection _connection
        uint32_t _native_type_num
        bint _number_as_int

    def __cinit__(self, connection):
        self._connection = connection

    def __dealloc__(self):
        if self._handle != NULL:
            dpiVar_release(self._handle)

    cdef int _bind(self, BaseCursor cursor, str name=None,
                   uint32_t pos=0) except -1:
        cdef:
            const char *name_ptr
            uint32_t name_length
            Cursor thick_cursor
            bytes name_bytes
        thick_cursor = <Cursor> cursor
        if name is not None:
            name_bytes = name.encode()
            name_ptr = name_bytes
            name_length = <uint32_t> len(name_bytes)
            if dpiStmt_bindByName(thick_cursor._handle, name_ptr,
                                  name_length, self._handle) < 0:
                _raise_from_odpi()
        else:
            if dpiStmt_bindByPos(thick_cursor._handle, pos, self._handle) < 0:
                _raise_from_odpi()

    cdef int _finalize_init(self) except -1:
        self._native_type_num = _get_native_type_num(self.type)
        if dpiConn_newVar(self._connection._handle, self.type.num,
                          self._native_type_num, self.num_elements, self.size,
                          0, self.is_array, NULL, &self._handle,
                          &self._data) < 0:
            _raise_from_odpi()
        if dpiVar_getSizeInBytes(self._handle, &self.buffer_size) < 0:
            _raise_from_odpi()

    cdef uint32_t _get_actual_elements(self) except *:
        cdef uint32_t num_elements
        if not self.is_array:
            return self.num_elements
        if dpiVar_getNumElementsInArray(self._handle, &num_elements) < 0:
            _raise_from_odpi()
        return num_elements

    cdef list _get_array_value(self, uint32_t num_elements):
        cdef:
            object element_value
            list return_value
            uint32_t i
        return_value = cpython.PyList_New(num_elements)
        for i in range(num_elements):
            element_value = self._get_single_value(i)
            cpython.Py_INCREF(element_value)
            cpython.PyList_SET_ITEM(return_value, i, element_value)
        return return_value

    cdef object _get_single_value(self, uint32_t pos):
        cdef:
            dpiData *data
            object value
        data = &self._data[pos]
        if not data.isNull:
            value = _convert_to_python(self._connection, self.type,
                                       &data.value, self._number_as_int)
            if self.outconverter:
                value = self.outconverter(value)
            return value

    cdef int _set_array_value(self, list value) except -1:
        cdef:
            uint32_t num_elements = <uint32_t> len(value)
            object element_value
            uint32_t i
        if dpiVar_setNumElementsInArray(self._handle, num_elements) < 0:
            _raise_from_odpi()
        for i in range(num_elements):
            self._set_single_value(i, value[i])

    cdef int _set_from_bytes(self, uint32_t pos, bytes value) except -1:
        cdef:
            uint32_t length, num_elements, i
            dpiData *source_data
            dpiVar *temp_handle
            dpiData *temp_data
            dpiBytes *as_bytes
            const char *ptr
        ptr = value
        length = <uint32_t> len(value)
        if length > self.buffer_size:
            if dpiConn_newVar(self._connection._handle, self.type.num,
                              self._native_type_num, self.num_elements,
                              length, 1, self.is_array, NULL, &temp_handle,
                              &temp_data) < 0:
                _raise_from_odpi()
            try:
                if self.is_array:
                    if dpiVar_getNumElementsInArray(self._handle,
                                                    &num_elements) < 0:
                        _raise_from_odpi()
                    if dpiVar_setNumElementsInArray(temp_handle,
                                                    num_elements) < 0:
                        _raise_from_odpi()
                for i in range(self.num_elements):
                    source_data = &self._data[i]
                    if i == pos or source_data.isNull:
                        continue
                    as_bytes = &source_data.value.asBytes
                    if dpiVar_setFromBytes(temp_handle, i, as_bytes.ptr,
                                           as_bytes.length) < 0:
                        _raise_from_odpi()
            except:
                dpiVar_release(temp_handle)
                raise
            dpiVar_release(self._handle)
            self._handle = temp_handle
            self._data = temp_data
            self.size = length
            self.buffer_size = length
        if dpiVar_setFromBytes(self._handle, pos, ptr, length) < 0:
            _raise_from_odpi()

    cdef int _set_single_value(self, uint32_t pos, object value) except -1:
        cdef:
            dpiData *data
            object x
        if self.inconverter:
            value = self.inconverter(value)
        data = &self._data[pos]
        data.isNull = (value is None)
        if not data.isNull:
            _convert_from_python(value, self.type, &data.value, self, pos)

    @staticmethod
    cdef Var new_var(Connection connection, DbType dbtype,
                     uint32_t num_elements, uint32_t size,
                     bint is_array=False):
        cdef Var var = Var.__new__(Var, connection)
        var.type = dbtype
        var.size = size
        var.num_elements = num_elements
        var.is_array = is_array
        var._finalize_init()
        return var
