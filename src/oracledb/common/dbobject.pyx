#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class BaseDbObjectType:

    def __repr__(self):
        return f"<oracledb.ObjectType {self.schema}.{self.name}"


cdef class BaseDbObjectAttr:

    def __repr__(self):
        return f"<oracledb.ObjectAttr {self.name}"


cdef class BaseDbObject:

    def __repr__(self):
        return f"<oracledb.Object {self.type.schema}.{self.type.name} at " \
               f"{hex(id(self))}>"
