#------------------------------------------------------------------------------
# Copyright (c) 2020, 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# cursor.pyx
#   Cython file defining the cursor class (embedded in driver.pyx).
#------------------------------------------------------------------------------

cdef class ThickCursorImpl(BaseCursorImpl):
    cdef:
        ThickConnImpl _conn_impl
        bint _fixup_ref_cursor
        dpiStmtInfo _stmt_info
        dpiStmt *_handle
        str _tag

    def __cinit__(self, conn_impl):
        self._conn_impl = conn_impl

    def __dealloc__(self):
        if self._handle != NULL:
            dpiStmt_release(self._handle)

    cdef int _close(self) except -1:
        """
        Internal method for closing the cursor.
        """
        if self._handle != NULL:
            if self._conn_impl._handle != NULL \
                    and not self._is_implicit_cursor:
                if dpiStmt_close(self._handle, NULL, 0) < 0:
                    _raise_from_odpi()
            dpiStmt_release(self._handle)
            self._handle = NULL

    cdef BaseVarImpl _create_var_impl(self):
        """
        Internal method for creating a variable.
        """
        return ThickVarImpl.__new__(ThickVarImpl)

    cdef int _fetch_rows(self, object cursor) except -1:
        """
        Internal method for fetching rows from a cursor.
        """
        cdef:
            uint32_t temp_buffer_row_index, num_rows_in_buffer
            bint more_rows_to_fetch
            ThickVarImpl var_impl
            object var, conn
            int status
        with nogil:
            status = dpiStmt_fetchRows(self._handle,
                                       self._fetch_array_size,
                                       &temp_buffer_row_index,
                                       &num_rows_in_buffer,
                                       &more_rows_to_fetch)
        if status < 0:
            _raise_from_odpi()
        conn = cursor.connection
        for var in self.fetch_vars:
            var_impl = <ThickVarImpl> var._impl
            var_impl._transform_to_python(conn, num_rows_in_buffer,
                                          in_fetch=True,
                                          offset=temp_buffer_row_index)
        self._buffer_index = 0
        self._buffer_rowcount = num_rows_in_buffer
        self._more_rows_to_fetch = more_rows_to_fetch

    cdef object _get_define_var(self, object cursor, uint32_t pos):
        """
        Internal method that returns the variable that will be used for
        fetching data in the specified position. If an output type handler is
        specified, it will be called first; otherwise, the query info will be
        used to generate a variable and return it.
        """
        cdef:
            object type_handler, result, typ
            ThickDbObjectTypeImpl typ_impl
            ThickCursorImpl cursor_impl
            dpiDataTypeInfo *type_info
            ThickConnImpl conn_impl
            dpiQueryInfo query_info
            BaseVarImpl var_impl
            FetchInfo fetch_info
            int16_t scale
            int status
        if dpiStmt_getQueryInfo(self._handle, pos, &query_info) < 0:
            _raise_from_odpi()
        fetch_info = FetchInfo()
        fetch_info._dbtype = \
                DbType._from_num(query_info.typeInfo.oracleTypeNum)
        if fetch_info._dbtype.num == DPI_ORACLE_TYPE_INTERVAL_YM:
            errors._raise_err(errors.ERR_DB_TYPE_NOT_SUPPORTED,
                              name=fetch_info._dbtype.name)
        if query_info.typeInfo.sizeInChars > 0:
            fetch_info._size = query_info.typeInfo.sizeInChars
        else:
            fetch_info._size = query_info.typeInfo.clientSizeInBytes
        fetch_info._buffer_size = query_info.typeInfo.clientSizeInBytes
        fetch_info._name = query_info.name[:query_info.nameLength].decode()
        fetch_info._scale = query_info.typeInfo.scale + \
                query_info.typeInfo.fsPrecision
        fetch_info._precision = query_info.typeInfo.precision
        fetch_info._nulls_allowed = query_info.nullOk
        type_handler = cursor.outputtypehandler \
                or cursor.connection.outputtypehandler
        if type_handler is not None:
            result = type_handler(cursor, fetch_info._name, fetch_info._dbtype,
                                  fetch_info._size, fetch_info._precision,
                                  fetch_info._scale)
            if result is not None:
                self._verify_var(result)
                var_impl = result._impl
                var_impl._fetch_info = fetch_info
                return result
        type_info = &query_info.typeInfo
        if type_info.objectType != NULL:
            cursor_impl = <ThickCursorImpl> cursor._impl
            conn_impl = cursor_impl._conn_impl
            typ_impl = ThickDbObjectTypeImpl._from_handle(conn_impl,
                                                          type_info.objectType)
            typ = DbObjectType._from_impl(typ_impl)
        else:
            typ = fetch_info._dbtype
        return self._create_default_fetch_var(typ, fetch_info)

    cdef bint _is_plsql(self):
        return <bint> self._stmt_info.isPLSQL

    cdef int _perform_define(self, object cursor,
                             uint32_t num_query_cols) except -1:
        """
        Internal method for performing defines. At this point it is assumed
        that the statement executed was in fact a query.
        """
        cdef:
            ThickCursorImpl cursor_impl = <ThickCursorImpl> cursor._impl
            ThickVarImpl var_impl
            uint32_t i, size
            object var

        # initialize fetching variables; these are used to reduce the number of
        # times that the GIL is released/acquired -- as there is a significant
        # amount of overhead in doing so
        self._buffer_rowcount = 0
        self._more_rows_to_fetch = True

        # if fetch variables already exist, nothing to do (the same statement
        # is being executed and therefore all defines have already been
        # performed
        if self.fetch_vars is not None:
            return 0

        # populate list to contain fetch variables that are created
        self._fetch_array_size = self.arraysize
        self.fetch_vars = cpython.PyList_New(num_query_cols)
        for i in range(num_query_cols):
            var = self._get_define_var(cursor, i + 1)
            var_impl = <ThickVarImpl> var._impl
            var_impl._create_handle(cursor_impl._conn_impl)
            if dpiStmt_define(self._handle, i + 1, var_impl._handle) < 0:
                _raise_from_odpi()
            cpython.Py_INCREF(var)
            cpython.PyList_SET_ITEM(self.fetch_vars, i, var)

    cdef int _scroll(self, object conn, int32_t offset,
                     uint32_t mode) except -1:
        cdef:
            uint32_t temp_buffer_row_index = 0, num_rows_in_buffer = 0
            bint more_rows_to_fetch = False
            ThickVarImpl var_impl
            int status
            object var
        with nogil:
            status = dpiStmt_scroll(self._handle, mode, offset,
                                    0 - self._buffer_rowcount)
            if status == 0:
                status = dpiStmt_fetchRows(self._handle,
                                           self._fetch_array_size,
                                           &temp_buffer_row_index,
                                           &num_rows_in_buffer,
                                           &more_rows_to_fetch)
            if status == 0:
                status = dpiStmt_getRowCount(self._handle, &self.rowcount)
        if status < 0:
            _raise_from_odpi()
        for var in self.fetch_vars:
            var_impl = <ThickVarImpl> var._impl
            var_impl._transform_to_python(conn, num_rows_in_buffer,
                                          in_fetch=True,
                                          offset=temp_buffer_row_index)
        self._buffer_index = 0
        self._buffer_rowcount = num_rows_in_buffer
        self._more_rows_to_fetch = more_rows_to_fetch
        self.rowcount -= num_rows_in_buffer

    cdef int _transform_binds(self, object conn,
                              uint32_t num_execs=1) except -1:
        cdef:
            ThickVarImpl var_impl
            object var
        if isinstance(self.bind_vars, dict):
            for var in self.bind_vars.values():
                var_impl = <ThickVarImpl> var._impl
                var_impl._transform_to_python(conn, num_execs)
        elif isinstance(self.bind_vars, list):
            for var in self.bind_vars:
                var_impl = <ThickVarImpl> var._impl
                var_impl._transform_to_python(conn, num_execs)

    def execute(self, cursor):
        """
        Internal method for executing a statement.
        """
        cdef:
            uint32_t mode, num_query_cols
            uint64_t rowcount
            int status
        if self.bind_vars is not None:
            self._perform_binds(cursor.connection)
        if self._conn_impl.autocommit:
            mode = DPI_MODE_EXEC_COMMIT_ON_SUCCESS
        else:
            mode = DPI_MODE_EXEC_DEFAULT
        with nogil:
            status = dpiStmt_execute(self._handle, mode, &num_query_cols)
            if status == DPI_SUCCESS:
                status = dpiStmt_getRowCount(self._handle, &rowcount)
        if status < 0:
            _raise_from_odpi()
        self.rowcount = rowcount
        if num_query_cols > 0:
            self._perform_define(cursor, num_query_cols)
        elif self._stmt_info.isReturning or self._stmt_info.isPLSQL:
            self._transform_binds(cursor.connection)

    def executemany(self, cursor, num_execs, batcherrors, arraydmlrowcounts):
        """
        Internal method for executing a statement multiple times.
        """
        cdef:
            uint32_t mode, num_execs_int = num_execs
            dpiErrorInfo error_info
            uint64_t rowcount
            int status

        if self._conn_impl.autocommit:
            mode = DPI_MODE_EXEC_COMMIT_ON_SUCCESS
        else:
            mode = DPI_MODE_EXEC_DEFAULT
        if arraydmlrowcounts:
            mode |= DPI_MODE_EXEC_ARRAY_DML_ROWCOUNTS
        if batcherrors:
            mode |= DPI_MODE_EXEC_BATCH_ERRORS

        if self.bind_vars is not None:
            self._perform_binds(cursor.connection, num_execs_int)

        if num_execs_int > 0:
            with nogil:
                status = dpiStmt_executeMany(self._handle, mode, num_execs_int)
                if status < 0:
                    dpiContext_getError(driver_context, &error_info)
                dpiStmt_getRowCount(self._handle, &rowcount)
            self.rowcount = rowcount
            if status < 0:
                _raise_from_info(&error_info)
            if self._stmt_info.isReturning or self._stmt_info.isPLSQL:
                self._transform_binds(cursor.connection, num_execs_int)

    def get_array_dml_row_counts(self):
        """
        Internal method for returning a list of array DML row counts for the
        last operation executed.
        """
        cdef:
            uint32_t num_row_count, i
            uint64_t *rowcount
            int status

        status = dpiStmt_getRowCounts(self._handle, &num_row_count, &rowcount)
        if status < 0:
            _raise_from_odpi()

        result = cpython.PyList_New(num_row_count)
        for i in range(num_row_count):
            cpython.PyList_SET_ITEM(result, i, rowcount[i])
        return result

    def get_batch_errors(self):
        """
        Internal method for returning a list of batch errors.
        """
        cdef:
            uint32_t num_errors, i
            dpiErrorInfo *errors

        if dpiStmt_getBatchErrorCount(self._handle, &num_errors) < 0:
            _raise_from_odpi()
        if num_errors == 0:
            return []

        errors = <dpiErrorInfo*> \
                cpython.PyMem_Malloc(num_errors * sizeof(dpiErrorInfo))

        try:
            if dpiStmt_getBatchErrors(self._handle, num_errors, errors) < 0:
                _raise_from_odpi()
            result = cpython.PyList_New(num_errors)
            for i in range(num_errors):
                error = _create_new_from_info(&errors[i])
                cpython.Py_INCREF(error)
                cpython.PyList_SET_ITEM(result, i, error)
        finally:
            cpython.PyMem_Free(errors)

        return result

    def get_bind_names(self):
        cdef:
            uint32_t *name_lengths = NULL
            const char **names = NULL
            uint32_t num_binds, i
            ssize_t num_bytes
            list result
        if dpiStmt_getBindCount(self._handle, &num_binds) < 0:
            _raise_from_odpi()
        if num_binds == 0:
            return []
        try:
            num_bytes = num_binds * sizeof(char*)
            names = <const char**> cpython.PyMem_Malloc(num_bytes)
            num_bytes = num_binds * sizeof(uint32_t)
            name_lengths = <uint32_t*> cpython.PyMem_Malloc(num_bytes)
            if dpiStmt_getBindNames(self._handle, &num_binds, names,
                                    name_lengths) < 0:
                _raise_from_odpi()
            result = [None] * num_binds
            for i in range(num_binds):
                result[i] = names[i][:name_lengths[i]].decode()
            return result
        finally:
            if names:
                cpython.PyMem_Free(names)
            if name_lengths:
                cpython.PyMem_Free(name_lengths)

    def get_implicit_results(self, connection):
        cdef:
            ThickCursorImpl child_cursor_impl
            object child_cursor
            dpiStmt *child_stmt
            list result = []
        if self._handle == NULL:
            errors._raise_err(errors.ERR_NO_STATEMENT_EXECUTED)
        while True:
            if dpiStmt_getImplicitResult(self._handle, &child_stmt) < 0:
                _raise_from_odpi()
            if child_stmt == NULL:
                break
            child_cursor = connection.cursor()
            child_cursor_impl = child_cursor._impl
            child_cursor_impl._handle = child_stmt
            child_cursor_impl._fixup_ref_cursor = True
            child_cursor_impl._is_implicit_cursor = True
            result.append(child_cursor)
        return result

    def get_lastrowid(self):
        """
        Internal method for returning the rowid of the row that was last
        modified by an operation.
        """
        cdef:
            uint32_t rowid_length
            const char *rowid_ptr
            dpiRowid *rowid
        if self._handle is not NULL:
            if dpiStmt_getLastRowid(self._handle, &rowid) < 0:
                _raise_from_odpi()
            if rowid:
                if dpiRowid_getStringValue(rowid, &rowid_ptr,
                                           &rowid_length) < 0:
                    _raise_from_odpi()
                return rowid_ptr[:rowid_length].decode()

    def is_query(self, cursor):
        cdef uint32_t num_query_cols
        if self._fixup_ref_cursor:
            self._fetch_array_size = self.arraysize
            if dpiStmt_setFetchArraySize(self._handle,
                                         self._fetch_array_size) < 0:
                _raise_from_odpi()
            if dpiStmt_getNumQueryColumns(self._handle, &num_query_cols) < 0:
                _raise_from_odpi()
            self._perform_define(cursor, num_query_cols)
            self._fixup_ref_cursor = False
        return self.fetch_vars is not None

    def parse(self, cursor):
        """
        Internal method for parsing a statement.
        """
        cdef:
            uint32_t mode, num_query_cols
            int status
        if self._stmt_info.isQuery:
            mode = DPI_MODE_EXEC_DESCRIBE_ONLY
        else:
            mode = DPI_MODE_EXEC_PARSE_ONLY
        with nogil:
            status = dpiStmt_execute(self._handle, mode, &num_query_cols)
        if status < 0:
            _raise_from_odpi()
        if num_query_cols > 0:
            self._perform_define(cursor, num_query_cols)

    def prepare(self, str statement, str tag, bint cache_statement):
        """
        Internal method used for preparing statements for execution.
        """
        cdef:
            uint32_t statement_bytes_length, tag_bytes_length = 0
            ThickConnImpl conn_impl = self._conn_impl
            bytes statement_bytes, tag_bytes
            const char *tag_ptr = NULL
            const char *statement_ptr
            int status
        self.statement = statement
        statement_bytes = statement.encode()
        statement_ptr = <const char*> statement_bytes
        statement_bytes_length = <uint32_t> len(statement_bytes)
        if tag is not None:
            self._tag = tag
            tag_bytes = tag.encode()
            tag_bytes_length = <uint32_t> len(tag_bytes)
            tag_ptr = <const char*> tag_bytes
        with nogil:
            if self._handle != NULL:
                dpiStmt_release(self._handle)
                self._handle = NULL
            status = dpiConn_prepareStmt(conn_impl._handle, self.scrollable,
                                         statement_ptr, statement_bytes_length,
                                         tag_ptr, tag_bytes_length,
                                         &self._handle)
            if status == DPI_SUCCESS and not cache_statement:
                status = dpiStmt_deleteFromCache(self._handle)
            if status == DPI_SUCCESS:
                status = dpiStmt_getInfo(self._handle, &self._stmt_info)
            if status == DPI_SUCCESS and self._stmt_info.isQuery:
                status = dpiStmt_setFetchArraySize(self._handle,
                                                   self.arraysize)
                if status == DPI_SUCCESS \
                        and self.prefetchrows != DPI_DEFAULT_PREFETCH_ROWS:
                    status = dpiStmt_setPrefetchRows(self._handle,
                                                     self.prefetchrows)
        if status < 0:
            _raise_from_odpi()
