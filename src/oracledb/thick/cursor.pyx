#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# cursor.pyx
#   Cython file defining the cursor class (embedded in driver.pyx).
#------------------------------------------------------------------------------

cdef class Cursor(BaseCursor):
    cdef:
        readonly Connection connection
        dpiStmtInfo _stmt_info
        dpiStmt *_handle
        str _tag

    def __cinit__(self, connection):
        self.connection = connection

    def __dealloc__(self):
        if self._handle != NULL:
            dpiStmt_release(self._handle)

    cdef int _close(self) except -1:
        """
        Internal method for closing the cursor.
        """
        if self._handle != NULL:
            if dpiStmt_close(self._handle, NULL, 0) < 0:
                _raise_from_odpi()
            dpiStmt_release(self._handle)
            self._handle = NULL

    cdef BaseVar _create_var(self):
        """
        Internal method for creating a variable.
        """
        return Var.__new__(Var, self.connection)

    cdef int _execute(self) except -1:
        """
        Internal method for executing a statement.
        """
        cdef:
            uint64_t rowcount
            uint32_t mode, num_query_cols
            int status
        if self._bind_vars is not None:
            self._perform_binds()
        mode = DPI_MODE_EXEC_DEFAULT
        with nogil:
            status = dpiStmt_execute(self._handle, mode, &num_query_cols)
            if status == DPI_SUCCESS:
                status = dpiStmt_getRowCount(self._handle, &rowcount)
        if status < 0:
            _raise_from_odpi()
        self.rowcount = rowcount
        if num_query_cols > 0:
            self._perform_define(num_query_cols)

    cdef int _executemany(self, uint32_t num_execs, bint batcherrors,
                          bint arraydmlrowcounts) except -1:
        """
        Internal method for executing a statement many times
        equal to the number of elements in the list of parameters
        or the provided integer. Arraydmlrowcounts and batcherrors
        can be set.
        """
        cdef:
            int status, rowcount_status
            uint64_t rowcount
            uint32_t mode

        mode = DPI_MODE_EXEC_DEFAULT
        if arraydmlrowcounts:
            mode |= DPI_MODE_EXEC_ARRAY_DML_ROWCOUNTS
        if batcherrors:
            mode |= DPI_MODE_EXEC_BATCH_ERRORS

        if self._bind_vars is not None:
            self._perform_binds()

        if num_execs > 0:
            with nogil:
                status = dpiStmt_executeMany(self._handle, mode, num_execs)
                rowcount_status = dpiStmt_getRowCount(self._handle, &rowcount)
            self.rowcount = rowcount
            if status < 0 or rowcount_status < 0:
                _raise_from_odpi()

    cdef int _fetch_rows(self) except -1:
        """
        Internal method for fetching rows from a cursor.
        """
        cdef:
            uint32_t temp_buffer_row_index, num_rows_in_buffer
            bint more_rows_to_fetch
            int status
        with nogil:
            status = dpiStmt_fetchRows(self._handle,
                                       self._fetch_array_size,
                                       &temp_buffer_row_index,
                                       &num_rows_in_buffer,
                                       &more_rows_to_fetch)
        if status < 0:
            errors._raise_from_odpi()
        self._buffer_rowcount = num_rows_in_buffer
        self._buffer_index = temp_buffer_row_index
        self._more_rows_to_fetch = more_rows_to_fetch

    cdef object _get_array_dml_row_counts(self):
        """
        Internal method for populating arraydmlrowcount
        list.
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

    cdef object _get_batch_errors(self):
        """
        Internal method for populating a list of batch error
        objects.
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

    cdef Var _get_define_var(self, uint32_t pos):
        """
        Internal method that returns the variable that will be used for
        fetching data in the specified position. If an output type handler is
        specified, it will be called first; otherwise, the query info will be
        used to generate a variable and return it.
        """
        cdef:
            object type_handler, result
            dpiDataTypeInfo *type_info
            dpiQueryInfo query_info
            DbType dbtype
            uint32_t size
            int status
            str name
            Var var
        if dpiStmt_getQueryInfo(self._handle, pos, &query_info) < 0:
            _raise_from_odpi()
        dbtype = DbType._from_num(query_info.typeInfo.oracleTypeNum)
        if query_info.typeInfo.sizeInChars > 0:
            size = query_info.typeInfo.sizeInChars
        else:
            size = query_info.typeInfo.clientSizeInBytes
        type_handler = self.outputtypehandler \
                or self.connection.outputtypehandler
        name = query_info.name[:query_info.nameLength].decode()
        if type_handler:
            result = type_handler(self, name, dbtype, size,
                                  query_info.typeInfo.precision,
                                  query_info.typeInfo.scale)
            if isinstance(result, Var):
                return result
            elif result is not None:
                message = "expecting variable from output type handler"
                errors._raise_from_error(TypeError, message)
        type_info = &query_info.typeInfo
        var = Var.new_var(self.connection, dbtype, self._fetch_array_size,
                          size)
        var.precision = type_info.precision
        var.scale = type_info.scale + type_info.fsPrecision
        var.name = name
        var.nulls_allowed = query_info.nullOk
        if dbtype.num == DPI_ORACLE_TYPE_NUMBER:
            if var.scale == 0 or (var.scale == -127 and var.precision == 0):
                var._number_as_int = True
        return var

    cdef int _perform_define(self, uint32_t num_query_cols) except -1:
        """
        Internal method for performing defines. At this point it is assumed
        that the statement executed was in fact a query.
        """
        cdef:
            uint32_t i, size
            Var var

        # initialize fetching variables; these are used to reduce the number of
        # times that the GIL is released/acquired -- as there is a significant
        # amount of overhead in doing so
        self._buffer_rowcount = 0
        self._more_rows_to_fetch = True

        # if fetch variables already exist, nothing to do (the same statement
        # is being executed and therefore all defines have already been
        # performed
        if self._fetch_vars is not None:
            return 0

        # populate list to contain fetch variables that are created
        self._fetch_array_size = self.arraysize
        self._fetch_vars = cpython.PyList_New(num_query_cols)
        for i in range(num_query_cols):
            var = self._get_define_var(i + 1)
            if dpiStmt_define(self._handle, i + 1, var._handle) < 0:
                _raise_from_odpi()
            cpython.Py_INCREF(var)
            cpython.PyList_SET_ITEM(self._fetch_vars, i, var)

    cdef int _prepare(self, str statement, str tag=None) except -1:
        """
        Internal method used for preparing statements for execution.
        """
        cdef:
            uint32_t statement_bytes_length, tag_bytes_length = 0
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
            status = dpiConn_prepareStmt(self.connection._handle, 0,
                                         statement_ptr, statement_bytes_length,
                                         tag_ptr, tag_bytes_length,
                                         &self._handle)
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
