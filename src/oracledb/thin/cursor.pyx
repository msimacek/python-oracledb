#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class Cursor(BaseCursor):

    cdef:
        readonly Connection connection
        uint16_t _cursor_id

    def __cinit__(self, connection):
        self.connection = connection

    cdef BaseVar _create_var(self):
        return Var.__new__(Var, self.connection)

    cdef int _execute(self) except -1:
        params = types.SimpleNamespace(cursor=self, sql=self.statement,
                                       fetch_array_size=self.arraysize,
                                       params=self._bind_vars)
        self.connection._protocol._execute(params)

    cdef int _fetch_rows(self) except -1:
        params = types.SimpleNamespace(cursor=self,
                                       fetch_array_size=self._fetch_array_size)
        self.connection._protocol._fetch(params)

    cdef int _prepare(self, str statement, str tag=None) except -1:
        self.statement = statement
