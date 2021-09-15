#------------------------------------------------------------------------------
# Copyright (c) 2020, 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# var.pyx
#   Cython file defining the variable class (embedded in driver.pyx).
#------------------------------------------------------------------------------

cdef class ThickVarImpl(BaseVarImpl):
    cdef:
        dpiVar *_handle
        dpiData *_data
        uint32_t _native_type_num
        bint _get_returned_data
        uint32_t _last_size

    def __dealloc__(self):
        if self._handle != NULL:
            dpiVar_release(self._handle)

    cdef int _bind(self, object conn, BaseCursorImpl cursor_impl,
                   uint32_t num_execs, str name=None,
                   uint32_t pos=0) except -1:
        cdef:
            ThickCursorImpl thick_cursor_impl = <ThickCursorImpl> cursor_impl
            uint32_t name_length, i
            const char *name_ptr
            bytes name_bytes
        self._check_handle(thick_cursor_impl._conn_impl)
        if self._is_value_set:
            self._transform_from_python(num_execs)
        if self._native_type_num == DPI_NATIVE_TYPE_STMT:
            for value in self.values:
                if value is not None and value._impl is thick_cursor_impl:
                    errors._raise_err(errors.ERR_SELF_BIND_NOT_SUPPORTED)
        if name is not None:
            name_bytes = name.encode()
            name_ptr = name_bytes
            name_length = <uint32_t> len(name_bytes)
            if dpiStmt_bindByName(thick_cursor_impl._handle, name_ptr,
                                  name_length, self._handle) < 0:
                _raise_from_odpi()
        else:
            if dpiStmt_bindByPos(thick_cursor_impl._handle, pos,
                                 self._handle) < 0:
                _raise_from_odpi()
        if thick_cursor_impl._stmt_info.isReturning and not self._is_value_set:
            self._get_returned_data = True
        self._is_value_set = False

    cdef int _check_handle(self, ThickConnImpl conn_impl) except -1:
        """
        Check to see if a handle needs to be created. This will be true if:
            - a handle has never been created before
            - the size of strings/bytes bound is larger than previously bound
            - a bound cursor has been closed since it was last bound
        """
        cdef:
            ThickCursorImpl cursor_impl
            dpiStmtInfo stmt_info
            dpiData *data
            object cursor
            uint32_t i
        if self._handle == NULL or self._last_size < self.size:
            return self._create_handle(conn_impl)
        if self._native_type_num == DPI_NATIVE_TYPE_STMT:
            for i in range(self.num_elements):
                cursor = self.values[i]
                if cursor is not None:
                    cursor_impl = <ThickCursorImpl> cursor._impl
                    if cursor_impl._handle != NULL:
                        continue
                data = &self._data[i]
                if dpiStmt_getInfo(data.value.asStmt, &stmt_info) < 0:
                    return self._create_handle(conn_impl)

    cdef int _create_handle(self, ThickConnImpl conn_impl) except -1:
        cdef:
            dpiObjectType *obj_type_handle = NULL
            ThickDbObjectTypeImpl obj_type_impl
        if self._handle != NULL:
            dpiVar_release(self._handle)
            self._handle = NULL
        if self._objtype is not None:
            obj_type_impl = <ThickDbObjectTypeImpl> self._objtype
            obj_type_handle = obj_type_impl._handle
        self._native_type_num = _get_native_type_num(self.dbtype)
        if dpiConn_newVar(conn_impl._handle, self.dbtype.num,
                          self._native_type_num, self.num_elements, self.size,
                          0, self.is_array, obj_type_handle, &self._handle,
                          &self._data) < 0:
            _raise_from_odpi()
        self._last_size = self.size

    cdef object _get_cursor_value(self, object conn, dpiDataBuffer *dbvalue,
                                  uint32_t pos, bint in_fetch):
        cdef:
            ThickCursorImpl cursor_impl
            object cursor
        cursor = self.values[pos]
        if cursor is None or in_fetch:
            cursor = conn.cursor()
        cursor_impl = <ThickCursorImpl> cursor._impl
        if cursor_impl._handle != dbvalue.asStmt:
            if cursor_impl._handle != NULL:
                dpiStmt_release(cursor_impl._handle)
                cursor_impl._handle = NULL
            if dpiStmt_addRef(dbvalue.asStmt) < 0:
                _raise_from_odpi()
            cursor_impl._handle = dbvalue.asStmt
            cursor_impl._fixup_ref_cursor = True
        return cursor

    cdef int _set_cursor_value(self, object cursor, uint32_t pos) except -1:
        cdef:
            ThickCursorImpl cursor_impl = cursor._impl
            dpiData *data

        # if the cursor already has a handle, use it directly
        if cursor_impl._handle != NULL:
            if dpiVar_setFromStmt(self._handle, pos, cursor_impl._handle) < 0:
                _raise_from_odpi()

        # otherwise, make use of the statement handle allocated by the variable
        else:
            data = &self._data[pos]
            if dpiStmt_addRef(data.value.asStmt) < 0:
                _raise_from_odpi()
            cursor_impl._handle = data.value.asStmt
        if dpiStmt_setPrefetchRows(cursor_impl._handle,
                                   cursor_impl.prefetchrows) < 0:
            _raise_from_odpi()
        cursor_impl._fixup_ref_cursor = True

    cdef int _transform_element_from_python(self, uint32_t pos,
                                            object value) except -1:
        """
        Transforms a single element from the Python value to the value required
        by ODPI-C.
        """
        cdef:
            dpiDataBuffer temp_dbvalue
            dpiDataBuffer *dbvalue
            dpiBytes *as_bytes
            StringBuffer buf
            bint needs_set
            dpiData *data
        data = &self._data[pos]
        data.isNull = (value is None)
        if not data.isNull:
            if self._native_type_num == DPI_NATIVE_TYPE_STMT:
                self._set_cursor_value(value, pos)
            else:
                needs_set = self._native_type_num == DPI_NATIVE_TYPE_BYTES \
                        or (self._native_type_num == DPI_NATIVE_TYPE_LOB and \
                                not isinstance(value, LOB))
                if needs_set:
                    dbvalue = &temp_dbvalue
                else:
                    dbvalue = &data.value
                buf = StringBuffer()
                _convert_from_python(value, self.dbtype, self._objtype,
                                     dbvalue, buf, self, pos)
                if needs_set:
                    as_bytes = &dbvalue.asBytes
                    if dpiVar_setFromBytes(self._handle, pos, as_bytes.ptr,
                                           as_bytes.length) < 0:
                        _raise_from_odpi()

    cdef int _transform_from_python(self, uint32_t num_elements) except -1:
        """
        Transforms all elements from the Python value to the value required by
        ODPI-C. The number of elements passed corresponds to the number of
        elements requested by execute() or executemany(). For arrays (where
        num_elements must always be 1) the number of elements corresponds to
        the number of elements in the array.
        """
        cdef uint32_t i
        if self.is_array:
            if dpiVar_setNumElementsInArray(self._handle,
                                            self.num_elements_in_array) < 0:
                _raise_from_odpi()
            num_elements = self.num_elements_in_array
        for i in range(num_elements):
            self._transform_element_from_python(i, self.values[i])

    cdef object _transform_array_to_python(self, object conn,
                                           uint32_t num_elements,
                                           dpiData *data):
        """
        Transforms an array from ODPI-C to a Python list.
        """
        cdef:
            object element_value
            list return_value
            uint32_t i
        return_value = cpython.PyList_New(num_elements)
        for i in range(num_elements):
            element_value = self._transform_element_to_python(conn, i, data)
            cpython.Py_INCREF(element_value)
            cpython.PyList_SET_ITEM(return_value, i, element_value)
        return return_value

    cdef object _transform_element_to_python(self, object conn,
                                             uint32_t pos,
                                             dpiData *data,
                                             bint in_fetch=False):
        """
        Transforms a single element from the value supplied by ODPI-C to its
        equivalent Python value.
        """
        cdef object value
        data = &data[pos]
        if not data.isNull:
            if self._native_type_num == DPI_NATIVE_TYPE_STMT:
                value = self._get_cursor_value(conn, &data.value, pos,
                                               in_fetch)
            else:
                value = _convert_to_python(conn._impl, self.dbtype,
                                           self._objtype, &data.value,
                                           self._preferred_num_type,
                                           self.bypass_decode)
            if self.outconverter:
                value = self.outconverter(value)
            return value

    cdef int _transform_to_python(self, object conn,
                                  uint32_t num_elements,
                                  bint in_fetch=False,
                                  uint32_t offset=0) except -1:
        """
        Transforms all elements from the value supplied by ODPI-C to its
        equivalent Python values. The number of elements will either be the
        number of rows fetched or the number of iterations executed. For arrays
        the number of elements is acquired from ODPI-C itself.
        """
        cdef:
            uint32_t i, num_returned_rows
            dpiData *returned_data
            object value
        if self.is_array:
            if dpiVar_getNumElementsInArray(self._handle, &num_elements) < 0:
                _raise_from_odpi()
            self.num_elements_in_array = num_elements
        for i in range(num_elements):
            if self._get_returned_data:
                if dpiVar_getReturnedData(self._handle, i + offset,
                                          &num_returned_rows,
                                          &returned_data) < 0:
                    _raise_from_odpi()
                value = self._transform_array_to_python(conn,
                                                        num_returned_rows,
                                                        returned_data)
            else:
                value = self._transform_element_to_python(conn, i + offset,
                                                          self._data, in_fetch)
            self.values[i] = value
