#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# object.pyx
#   Cython file defining the ObjectType, ObjectAttr and Object classes
# (embedded in driver.pyx).
#------------------------------------------------------------------------------

cdef class DbObjectType(BaseDbObjectType):
    cdef:
        dpiObjectType *_handle
        uint32_t _element_native_type_num

    def __dealloc__(self):
        if self._handle != NULL:
            dpiObjectType_release(self._handle)

    cdef BaseDbObject _new_object(self):
        cdef DbObject obj = DbObject.__new__(DbObject)
        obj.type = self
        if dpiObjectType_createObject(self._handle, &obj._handle) < 0:
            _raise_from_odpi()
        return obj

    @staticmethod
    cdef DbObjectType _new_type(Connection connection, dpiObjectType *handle):
        cdef:
            dpiObjectAttr **attributes = NULL
            DbObjectType objtype, temp
            dpiObjectTypeInfo info
            DbObjectAttr attr
            ssize_t num_bytes
            DbType dbtype
            uint16_t i
            object typ
        objtype = DbObjectType.__new__(DbObjectType)
        objtype._connection = connection
        if dpiObjectType_addRef(handle) < 0:
            _raise_from_odpi()
        objtype._handle = handle
        if dpiObjectType_getInfo(handle, &info) < 0:
            _raise_from_odpi()
        objtype.schema = info.schema[:info.schemaLength].decode()
        objtype.name = info.name[:info.nameLength].decode()
        objtype.iscollection = info.isCollection
        if objtype.iscollection:
            dbtype = DbType._from_num(info.elementTypeInfo.oracleTypeNum)
            objtype._element_dbtype = dbtype
            if info.elementTypeInfo.objectType != NULL:
                temp = DbObjectType._new_type(connection,
                                              info.elementTypeInfo.objectType)
                objtype._element_objtype = temp
            objtype._element_native_type_num = \
                    _get_native_type_num(objtype._element_dbtype)
        objtype.attributes = [None] * info.numAttributes
        try:
            num_bytes = info.numAttributes * sizeof(dpiObjectAttr*)
            attributes = <dpiObjectAttr**> cpython.PyMem_Malloc(num_bytes)
            if dpiObjectType_getAttributes(handle, info.numAttributes,
                                           attributes) < 0:
                _raise_from_odpi()
            for i in range(info.numAttributes):
                attr = DbObjectAttr._new_attr(connection, attributes[i])
                objtype.attributes[i] = attr
        finally:
            if attributes != NULL:
                cpython.PyMem_Free(attributes)
        objtype._attributesByName = \
                dict((a.name, a) for a in objtype.attributes)
        return objtype


cdef class DbObjectAttr(BaseDbObjectAttr):
    cdef:
        dpiObjectAttr *_handle
        uint32_t _native_type_num

    def __dealloc__(self):
        if self._handle != NULL:
            dpiObjectAttr_release(self._handle)

    @staticmethod
    cdef DbObjectAttr _new_attr(Connection connection, dpiObjectAttr *handle):
        cdef:
            dpiObjectAttrInfo info
            DbObjectAttr attr
        attr = DbObjectAttr.__new__(DbObjectAttr)
        attr._handle = handle
        if dpiObjectAttr_getInfo(handle, &info) < 0:
            _raise_from_odpi()
        attr.name = info.name[:info.nameLength].decode()
        attr._dbtype = DbType._from_num(info.typeInfo.oracleTypeNum)
        if info.typeInfo.objectType:
            attr._objtype = DbObjectType._new_type(connection,
                                                   info.typeInfo.objectType)
        attr._native_type_num = _get_native_type_num(attr._dbtype)
        return attr


cdef class DbObject(BaseDbObject):
    cdef:
        dpiObject *_handle

    def __dealloc__(self):
        if self._handle != NULL:
            dpiObject_release(self._handle)

    cdef object _get_attr_value(self, BaseDbObjectAttr attr):
        cdef:
            DbObjectAttr a = <DbObjectAttr> attr
            char number_as_string_buffer[200]
            dpiData data
        if a._native_type_num == DPI_NATIVE_TYPE_BYTES \
                and a._dbtype.num == DPI_ORACLE_TYPE_NUMBER:
            data.value.asBytes.ptr = number_as_string_buffer
            data.value.asBytes.length = sizeof(number_as_string_buffer)
            data.value.asBytes.encoding = NULL
        if dpiObject_getAttributeValue(self._handle, a._handle,
                                       a._native_type_num, &data) < 0:
            _raise_from_odpi()
        return _convert_to_python(self.type._connection, a._dbtype, a._objtype,
                                  &data.value)

    @staticmethod
    cdef DbObject _new_object(DbObjectType objtype, dpiObject *handle):
        cdef DbObject obj = DbObject.__new__(DbObject)
        obj.type = objtype
        if dpiObject_addRef(handle) < 0:
            _raise_from_odpi()
        obj._handle = handle
        return obj

    cdef int _set_attr_value(self, BaseDbObjectAttr attr,
                             object value) except -1:
        cdef:
            DbObjectAttr a = <DbObjectAttr> attr
            dpiData data
        _convert_from_python(value, a._dbtype, a._objtype, &data.value)
        if dpiObject_setAttributeValue(self._handle, a._handle,
                                       a._native_type_num, &data) < 0:
            _raise_from_odpi()
