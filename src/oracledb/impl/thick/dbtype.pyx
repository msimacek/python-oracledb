#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# dbtype.pyx
#   Cython file defining the DbType class (embedded in driver.pyx).
#------------------------------------------------------------------------------

cdef class DbType:
    cdef:
        readonly uint32_t num
        readonly str name

    def __eq__(self, other):
        if not isinstance(other, DbType):
            return NotImplemented
        return self.num == other.num

    def __hash__(self):
        return self.num

    def __repr__(self):
        return f"<DbType {self.name}>"
