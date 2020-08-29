#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class Cursor(BaseCursor):

    cdef:
        readonly Connection connection

    def __cinit__(self, connection):
        self.connection = connection

    cdef BaseVar _create_var(self):
        return Var.__new__(Var, self.connection)
