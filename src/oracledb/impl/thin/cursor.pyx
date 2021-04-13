#------------------------------------------------------------------------------
# Copyright (c) 2020, 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class ThinCursorImpl(BaseCursorImpl):

    cdef:
        ThinConnImpl _conn_impl
        Statement _statement
        list _batcherrors
        list _dmlrowcounts
        list _implicit_resultsets
        str _lastrowid
        bint _requires_full_execute

    def __cinit__(self, conn_impl):
        self._conn_impl = conn_impl

    cdef int _close(self) except -1:
        if self._statement is not None:
            self._conn_impl._return_statement(self._statement)
            self._statement = None

    cdef BaseVarImpl _create_var_impl(self, object connection):
        return ThinVarImpl.__new__(ThinVarImpl, connection)

    cdef int _fetch_rows(self, object cursor) except -1:
        self._conn_impl._protocol._fetch(cursor)

    cdef bint _is_plsql(self):
        return self._statement._is_plsql

    cdef int _prepare(self, str sql, str tag=None) except -1:
        self.statement = sql
        if self._statement is not None:
            self._conn_impl._return_statement(self._statement)
            self._statement = None
        self._statement = self._conn_impl._get_statement(sql)
        self.fetch_vars = self._statement._fetch_vars

    cdef int _preprocess_execute(self) except -1:
        cdef BindInfo bind_info
        if self.bind_vars is not None:
            self._perform_binds()
        for bind_info in self._statement._bind_info_list:
            if bind_info._bind_var is None:
                message = f"Bind value for: {bind_info._bind_name} missing."
                errors._raise_from_string(exceptions.DatabaseError, message)

    def execute(self, cursor):
        self._preprocess_execute()
        self._conn_impl._protocol._execute(cursor)

    def executemany(self, cursor, num_execs, batcherrors, arraydmlrowcounts):
        self._preprocess_execute()
        self._conn_impl._protocol._execute(cursor, num_execs,
                                           arraydmlrowcounts, batcherrors)

    def fetch_rows(self, cursor):
        self._conn_impl._protocol._fetch(cursor)

    def get_array_dml_row_counts(self):
        if self._dmlrowcounts is None:
            errors._raise_from_string(exceptions.DatabaseError,
                                      "Array DML row counts not available")
        return self._dmlrowcounts

    def get_batch_errors(self):
        return self._batcherrors

    def get_bind_names(self):
        return list(self._statement._bind_info_dict.keys())

    def get_implicit_results(self, connection):
        if self._implicit_resultsets is None:
            errors._raise_from_string(exceptions.InterfaceError,
                                      "no statement executed")
        return self._implicit_resultsets

    def get_lastrowid(self):
        return self._lastrowid

    def is_query(self, connection):
        return self.fetch_vars is not None

    def parse(self, cursor):
        self._conn_impl._protocol._parse(cursor)
