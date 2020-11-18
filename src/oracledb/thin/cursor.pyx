#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class Cursor(BaseCursor):

    cdef:
        Statement _statement
        str _lastrowid

    cdef int _close(self) except -1:
        cdef Connection connection = self.connection
        if self._statement is not None:
            connection._statement_cache.put_statement(self._statement)

    cdef BaseVar _create_var(self):
        return Var.__new__(Var, self.connection)

    cdef object _bindnames(self):
        return list(self._statement._bind_info_dict.keys())

    cdef int _execute(self) except -1:
        cdef Connection connection = self.connection
        self._preprocess_execute(connection)
        connection._protocol._execute(self, self.arraysize, 1,
                                      self._statement._bind_info_list)

    cdef int _executemany(self, uint32_t num_execs, bint batcherrors,
                          bint arraydmlrowcounts) except -1:
        cdef Connection connection = self.connection
        self._preprocess_execute(connection)
        connection._protocol._execute(self, self.arraysize, num_execs,
                                      self._statement._bind_info_list)

    cdef int _fetch_rows(self) except -1:
        cdef Connection connection = self.connection
        connection._protocol._fetch(self, self._fetch_array_size)

    cdef object _get_lastrowid(self):
        return self._lastrowid

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

    cdef int _preprocess_execute(self, Connection connection) except -1:
        cdef BindInfo bind_info
        if self._bind_vars is not None:
            self._perform_binds()
        for bind_info in self._statement._bind_info_list:
            if bind_info._bind_var is None:
                message = f"Bind value for: {bind_info._bind_name} missing."
                errors._raise_from_string(exceptions.DatabaseError, message)
