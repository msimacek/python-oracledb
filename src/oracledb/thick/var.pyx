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
        bint _is_value_set
        bint _get_returned_data

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
        if thick_cursor._stmt_info.isReturning and not self._is_value_set:
            self._get_returned_data = True

    cdef int _finalize_init(self) except -1:
        cdef:
            dpiObjectType *obj_type_handle = NULL
            DbObjectType obj_type
        if self.num_elements == 0:
            self.num_elements = 1
        if self._objtype is not None:
            obj_type = <DbObjectType> self._objtype
            obj_type_handle = obj_type._handle
        self._native_type_num = _get_native_type_num(self._dbtype)
        if dpiConn_newVar(self._connection._handle, self._dbtype.num,
                          self._native_type_num, self.num_elements, self.size,
                          0, self.is_array, obj_type_handle, &self._handle,
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
        return self._get_array_value_with_data(num_elements, NULL)

    cdef object _get_array_value_with_data(self, uint32_t num_elements,
                                           dpiData *data):
        cdef:
            object element_value
            list return_value
            uint32_t i
        return_value = cpython.PyList_New(num_elements)
        for i in range(num_elements):
            element_value = self._get_single_value_with_data(i, data)
            cpython.Py_INCREF(element_value)
            cpython.PyList_SET_ITEM(return_value, i, element_value)
        return return_value

    cdef object _get_single_value(self, uint32_t pos):
        return self._get_single_value_with_data(pos, NULL)

    cdef object _get_single_value_with_data(self, uint32_t pos, dpiData *data):
        cdef:
            uint32_t num_returned_rows
            dpiData *returned_data
            object value

        # handle DML returning
        if data == NULL and self._get_returned_data:
            if dpiVar_getReturnedData(self._handle, pos, &num_returned_rows,
                                      &returned_data) < 0:
                _raise_from_odpi()
            return self._get_array_value_with_data(num_returned_rows,
                                                   returned_data)
        # in all other cases, just get the value at the specified position
        if data != NULL:
            data = &data[pos]
        else:
            data = &self._data[pos]
        if not data.isNull:
            value = _convert_to_python(self._connection, self._dbtype,
                                       self._objtype, &data.value,
                                       self._number_as_int)
            if self.outconverter:
                value = self.outconverter(value)
            return value

    cdef int _resize(self, uint32_t new_size, uint32_t pos) except -1:
        cdef:
            uint32_t num_elements, i
            dpiData *source_data
            dpiVar *temp_handle
            dpiData *temp_data
            const char *ptr
        if dpiConn_newVar(self._connection._handle, self.type.num,
                          self._native_type_num, self.num_elements, new_size,
                          1, self.is_array, NULL, &temp_handle,
                          &temp_data) < 0:
            _raise_from_odpi()
        try:
            if self.is_array:
                if dpiVar_getNumElementsInArray(self._handle,
                                                &num_elements) < 0:
                    _raise_from_odpi()
                if dpiVar_setNumElementsInArray(temp_handle, num_elements) < 0:
                    _raise_from_odpi()
            for i in range(self.num_elements):
                source_data = &self._data[i]
                if i == pos or source_data.isNull:
                    continue
                if dpiVar_setFromBytes(temp_handle, i,
                                       source_data.value.asBytes.ptr,
                                       source_data.value.asBytes.length) < 0:
                    _raise_from_odpi()
            self._handle, temp_handle = temp_handle, self._handle
            self._data = temp_data
            self.size = new_size
            self.buffer_size = new_size
        finally:
            dpiVar_release(temp_handle)

    cdef int _set_array_value(self, list value) except -1:
        cdef:
            uint32_t num_elements = <uint32_t> len(value)
            object element_value
            uint32_t i
        if dpiVar_setNumElementsInArray(self._handle, num_elements) < 0:
            _raise_from_odpi()
        for i in range(num_elements):
            self._set_single_value(i, value[i])

    cdef int _set_cursor_value(self, Cursor cursor, uint32_t pos) except -1:
        cdef:
            dpiStmtInfo stmt_info
            dpiData *data

        # if the cursor already has a handle, use it directly
        if cursor._handle != NULL:
            if dpiVar_setFromStmt(self._handle, pos, cursor._handle) < 0:
                _raise_from_odpi()

        # otherwise, make use of the statement handle allocated by the variable
        # BUT, make sure the statement handle is still valid as it may have
        # been closed by some other code; the call to dpiStmt_getInfo() will
        # ensure the statement is still open; if an error occurs, this bind
        # will be discarded and a second attempt will be made with a new cursor
        else:
            data = &self._data[pos]
            if dpiStmt_getInfo(data.value.asStmt, &stmt_info) < 0:
                _raise_from_odpi()
            if dpiStmt_addRef(data.value.asStmt) < 0:
                _raise_from_odpi()
            cursor._handle = data.value.asStmt
        cursor._fixup_ref_cursor = True

    cdef int _set_single_value(self, uint32_t pos, object value) except -1:
        cdef:
            StringBuffer buf = StringBuffer()
            dpiDataBuffer temp_dbvalue
            dpiDataBuffer *dbvalue
            dpiBytes *as_bytes
            dpiData *data
            object x
        self._is_value_set = True
        if self.inconverter:
            value = self.inconverter(value)
        data = &self._data[pos]
        data.isNull = (value is None)
        if not data.isNull:
            if self._native_type_num == DPI_NATIVE_TYPE_STMT:
                self._set_cursor_value(value, pos)
            else:
                if self._native_type_num == DPI_NATIVE_TYPE_BYTES:
                    dbvalue = &temp_dbvalue
                else:
                    dbvalue = &data.value
                _convert_from_python(value, self._dbtype, self._objtype,
                                     dbvalue, buf, self, pos)
                if self._native_type_num == DPI_NATIVE_TYPE_BYTES:
                    as_bytes = &dbvalue.asBytes
                    if as_bytes.length > self.buffer_size:
                        self._resize(as_bytes.length, pos)
                    if dpiVar_setFromBytes(self._handle, pos, as_bytes.ptr,
                                           as_bytes.length) < 0:
                        _raise_from_odpi()
