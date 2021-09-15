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
            if not self._is_implicit_cursor:
                self._conn_impl._return_statement(self._statement)
            self._statement = None

    cdef BaseVarImpl _create_var_impl(self):
        return ThinVarImpl.__new__(ThinVarImpl)

    cdef int _fetch_rows(self, object cursor) except -1:
        self._conn_impl._protocol._fetch(cursor)

    cdef object _get_fetch_var(self, object cursor, object type_handler,
                               FetchInfo fetch_info, bint *requires_define):
        """
        Return the variable to use for fetching data. The type handler is run,
        if specified. If no type handler is specified or the type handler is
        run and None is returned, a default variable is created using the fetch
        information.
        """
        cdef:
            ThinVarImpl var_impl
            object var = None
        if type_handler is not None:
            var = type_handler(cursor, fetch_info._name,
                               fetch_info._dbtype, fetch_info._size,
                               fetch_info._precision, fetch_info._scale)
            if var is not None:
                self._verify_var(var)
        if var is None:
            var = self._create_default_fetch_var(fetch_info._dbtype,
                                                 fetch_info._name,
                                                 fetch_info._size,
                                                 fetch_info._precision,
                                                 fetch_info._scale,
                                                 fetch_info._nulls_allowed)
        var_impl = <ThinVarImpl> var._impl
        var_impl._fetch_info = fetch_info
        if var_impl.dbtype._ora_type_num != fetch_info._dbtype._ora_type_num:
            conversion_helper(var_impl, fetch_info, requires_define)
        return var

    cdef bint _is_plsql(self):
        return self._statement._is_plsql

    cdef int _prepare(self, str sql, str tag=None) except -1:
        self.statement = sql
        if self._statement is not None:
            if not self._is_implicit_cursor:
                self._conn_impl._return_statement(self._statement)
            self._statement = None
        self._statement = self._conn_impl._get_statement(sql)
        self.fetch_vars = self._statement._fetch_vars

    cdef int _preprocess_execute(self, object conn) except -1:
        cdef BindInfo bind_info
        if self.bind_vars is not None:
            self._perform_binds(conn)
        for bind_info in self._statement._bind_info_list:
            if bind_info._bind_var is None:
                errors._raise_err(errors.ERR_MISSING_BIND_VALUE,
                                  name=bind_info._bind_name)

    def execute(self, cursor):
        self._preprocess_execute(cursor.connection)
        self._conn_impl._protocol._execute(cursor)

    def executemany(self, cursor, num_execs, batcherrors, arraydmlrowcounts):
        self._preprocess_execute(cursor.connection)
        self._conn_impl._protocol._execute(cursor, num_execs,
                                           arraydmlrowcounts, batcherrors)

    def fetch_rows(self, cursor):
        self._conn_impl._protocol._fetch(cursor)

    def get_array_dml_row_counts(self):
        if self._dmlrowcounts is None:
            errors._raise_err(errors.ERR_ARRAY_DML_ROW_COUNTS_NOT_ENABLED)
        return self._dmlrowcounts

    def get_batch_errors(self):
        return self._batcherrors

    def get_bind_names(self):
        return list(self._statement._bind_info_dict.keys())

    def get_implicit_results(self, connection):
        if self._implicit_resultsets is None:
            errors._raise_err(errors.ERR_NO_STATEMENT_EXECUTED)
        return self._implicit_resultsets

    def get_lastrowid(self):
        return self._lastrowid

    def is_query(self, connection):
        return self.fetch_vars is not None

    def parse(self, cursor):
        self._conn_impl._protocol._parse(cursor)
