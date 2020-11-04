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
        Connection _connection
        dpiObjectType *_handle

    def __dealloc__(self):
        if self._handle != NULL:
            dpiObjectType_release(self._handle)

    @staticmethod
    cdef DbObjectType _new_type(Connection connection, dpiObjectType *handle):
        cdef:
            dpiObjectAttr **attributes
            dpiObjectTypeInfo info
            DbObjectType objtype
            object typ
        objtype = DbObjectType.__new__(DbObjectType)
        if dpiObjectType_addRef(handle) < 0:
            _raise_from_odpi()
        objtype._handle = handle
        if dpiObjectType_getInfo(handle, &info) < 0:
            _raise_from_odpi()
        objtype.schema = info.schema[:info.schemaLength].decode()
        objtype.name = info.name[:info.nameLength].decode()
        objtype.iscollection = info.isCollection
        if objtype.iscollection:
            if info.elementTypeInfo.objectType != NULL:
                typ = DbObjectType._new_type(connection,
                                             info.elementTypeInfo.objectType)
            else:
                typ = DbType._from_num(info.elementTypeInfo.oracleTypeNum)
            objtype.element_type = typ
        objtype.attributes = [None] * info.numAttributes
        return objtype


cdef class DbObjectAttr(BaseDbObjectAttr):
    cdef:
        dpiObjectAttr *_handle

    def __dealloc__(self):
        if self._handle != NULL:
            dpiObjectAttr_release(self._handle)


cdef class DbObject(BaseDbObject):
    cdef:
        dpiObject *_handle

    def __dealloc__(self):
        if self._handle != NULL:
            dpiObject_release(self._handle)

    @staticmethod
    cdef DbObject _new_object(DbObjectType objtype, dpiObject *handle):
        cdef DbObject obj = DbObject.__new__(DbObject)
        obj.type = objtype
        if dpiObject_addRef(handle) < 0:
            _raise_from_odpi()
        obj._handle = handle
        return obj
