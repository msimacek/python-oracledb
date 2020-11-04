#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# object.pyx
#   Cython file defining the ObjectType, ObjectAttr and Object classes
# (embedded in driver.pyx).
#------------------------------------------------------------------------------

cdef class ObjectType(BaseObjectType):
    cdef:
        Connection _connection
        dpiObjectType *_handle

    def __dealloc__(self):
        if self._handle != NULL:
            dpiObjectType_release(self._handle)

    @staticmethod
    cdef ObjectType _new_type(Connection connection, dpiObjectType *handle):
        cdef:
            dpiObjectAttr **attributes
            dpiObjectTypeInfo info
            ObjectType object_type
            object typ
        object_type = ObjectType.__new__(ObjectType)
        object_type._handle = handle
        if dpiObjectType_getInfo(handle, &info) < 0:
            _raise_from_odpi()
        object_type.schema = info.schema[:info.schemaLength].decode()
        object_type.name = info.name[:info.nameLength].decode()
        object_type.iscollection = info.isCollection
        if object_type.iscollection:
            if info.elementTypeInfo.objectType != NULL:
                typ = ObjectType._new_type(connection,
                                           info.elementTypeInfo.objectType)
            else:
                typ = DbType._from_num(info.elementTypeInfo.oracleTypeNum)
            object_type.element_type = typ
        object_type.attributes = [None] * info.numAttributes
        return object_type


cdef class ObjectAttr(BaseObjectAttr):
    cdef:
        dpiObjectAttr *_handle

    def __dealloc__(self):
        if self._handle != NULL:
            dpiObjectAttr_release(self._handle)


cdef class Object(BaseObject):
    cdef:
        dpiObject *_handle

    def __dealloc__(self):
        if self._handle != NULL:
            dpiObject_release(self._handle)
