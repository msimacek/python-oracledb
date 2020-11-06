#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class Cursor(BaseCursor):

    cdef:
        Statement _statement

    cdef int _close(self) except -1:
        cdef Connection connection = self.connection
        if self._statement is not None:
            connection._statement_cache.put_statement(self._statement)

    cdef BaseVar _create_var(self):
        return Var.__new__(Var, self.connection)

    cdef object _bindnames(self):
        names = self._statement._bind_names
        return list(collections.OrderedDict.fromkeys(names))

    cdef int _execute(self) except -1:
        cdef Connection connection = self.connection
        params = types.SimpleNamespace(cursor=self,
                                       fetch_array_size=self.arraysize,
                                       params=self._bind_vars)
        connection._protocol._execute(params)

    cdef int _fetch_rows(self) except -1:
        cdef Connection connection = self.connection
        params = types.SimpleNamespace(cursor=self,
                                       fetch_array_size=self._fetch_array_size)
        connection._protocol._fetch(params)

    cdef bint _is_plsql(self):
        return self._statement._is_plsql

    cdef bint _is_query(self) except *:
        return self._statement._is_query

    cdef int _prepare(self, str sql, str tag=None) except -1:
        cdef Connection connection = self.connection
        self.statement = sql
        self._statement = connection._statement_cache.get_statement(sql)
        if self._statement is None:
            self._statement = Statement()
            self._statement._prepare(sql)
        self.statement = sql
