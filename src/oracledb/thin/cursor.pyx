#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class Cursor(BaseCursor):

    cdef:
        Statement _statement
        list _batcherrors
        list _dmlrowcounts
        list _implicit_resultsets
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
        self._preprocess_execute()
        connection._protocol._execute(self)

    cdef int _executemany(self, uint32_t num_execs, bint batcherrors,
                          bint arraydmlrowcounts) except -1:
        cdef Connection connection = self.connection
        self._preprocess_execute()
        connection._protocol._execute(self, num_execs, arraydmlrowcounts,
                                      batcherrors)

    cdef int _fetch_rows(self) except -1:
        cdef Connection connection = self.connection
        connection._protocol._fetch(self)

    cdef object _get_array_dml_row_counts(self):
        if self._dmlrowcounts is None:
            errors._raise_from_string(exceptions.DatabaseError,
                                      "Array DML row counts not available")
        return self._dmlrowcounts

    cdef object _get_batch_errors(self):
        return self._batcherrors

    cdef object _get_lastrowid(self):
        return self._lastrowid

    cdef object _get_implicit_results(self):
        if self._implicit_resultsets is None:
            errors._raise_from_string(exceptions.InterfaceError,
                                      "no statement executed")
        return self._implicit_resultsets

    cdef bint _is_plsql(self):
        return self._statement._is_plsql

    cdef bint _is_query(self) except *:
        return self._statement._is_query

    cdef int _prepare(self, str sql, str tag=None) except -1:
        cdef Connection connection = self.connection
        self.statement = sql
        self._statement = connection._statement_cache.get_statement(sql)
        if self._statement is not None:
            self._fetch_vars = self._statement._fetch_vars
        else:
            self._statement = Statement()
            self._statement._prepare(sql)

    cdef int _preprocess_execute(self) except -1:
        cdef BindInfo bind_info
        if self._bind_vars is not None:
            self._perform_binds()
        for bind_info in self._statement._bind_info_list:
            if bind_info._bind_var is None:
                message = f"Bind value for: {bind_info._bind_name} missing."
                errors._raise_from_string(exceptions.DatabaseError, message)
