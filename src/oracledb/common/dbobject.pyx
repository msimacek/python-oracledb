#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class BaseDbObjectType:

    def __call__(self, value=None):
        return self.newobject(value)

    def __eq__(self, other):
        cdef other_type
        if isinstance(other, BaseDbObjectType):
            other_type = <BaseDbObjectType> other
            if other_type._connection is other_type._connection \
                    and other_type.schema == other_type.schema \
                    and other_type.name == other_type.name:
                return True
        return NotImplemented

    def __repr__(self):
        return f"<oracledb.ObjectType {self.schema}.{self.name}>"

    cdef BaseDbObject _new_object(self):
        """
        Internal method for creating a new object.
        """
        raise NotImplementedError()

    @property
    def element_type(self):
        return self._element_objtype or self._element_dbtype

    def newobject(self, value=None):
        cdef BaseDbObject obj = self._new_object()
        if value is not None:
            obj.extend(value)
        return obj


cdef class BaseDbObjectAttr:

    def __repr__(self):
        return f"<oracledb.ObjectAttribute {self.name}>"

    @property
    def type(self):
        return self._objtype or self._dbtype


cdef class BaseDbObject:

    def __getattr__(self, name):
        cdef BaseDbObjectAttr attr
        attr = self.type._attributesByName[name]
        return self._get_attr_value(attr)

    def __repr__(self):
        return f"<oracledb.Object {self.type.schema}.{self.type.name} at " \
               f"{hex(id(self))}>"

    def __setattr__(self, name, value):
        cdef BaseDbObjectAttr attr
        attr = self.type._attributesByName[name]
        self._set_attr_value(attr, value)

    cdef int _append(self, object value) except -1:
        """
        Internal method for appending a value to a collection object.
        """
        raise NotImplementedError()

    cdef object _get_attr_value(self, BaseDbObjectAttr attr):
        """
        Internal method for getting an attribute value.
        """
        raise NotImplementedError()

    cdef int _set_attr_value(self, BaseDbObjectAttr attr,
                             object value) except -1:
        """
        Internal method for setting an attribute value.
        """
        raise NotImplementedError()

    def append(self, value):
        self._append(value)
