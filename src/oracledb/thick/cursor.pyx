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
        readonly uint64_t rowcount
        uint32_t _num_rows_in_buffer
        uint32_t _buffer_row_index
        uint32_t _fetch_array_size
        bint _more_rows_to_fetch
        dpiStmtInfo _stmt_info
        dpiStmt *_handle
        str _tag

    def __cinit__(self, connection):
        self.connection = connection

    def __dealloc__(self):
        if self._handle != NULL:
            dpiStmt_release(self._handle)

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cdef object _create_row(self, uint32_t buffer_row_index):
        """
        Internal method for creating a row from the fetched data.
        """
        cdef:
            Py_ssize_t i, num_vars
            object row, value
            Variable var
        num_vars = cpython.PyList_GET_SIZE(self._fetch_vars)
        row = cpython.PyTuple_New(num_vars)
        for i in range(num_vars):
            var = self._fetch_vars[i]
            value = var._get_single_value(NULL, buffer_row_index)
            cpython.Py_INCREF(value)
            cpython.PyTuple_SET_ITEM(row, i, value)
        if self.rowfactory:
            row = self.rowfactory(*row)
        return row

    cdef int _execute(self) except -1:
        """
        Internal method for executing a statement.
        """
        cdef:
            uint64_t rowcount
            uint32_t mode, num_query_cols
            int status
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

    cdef int _fetch_row(self, bint* found,
                        uint32_t* buffer_row_index) except -1:
        """
        Internal method for fetching a row from the database. If no rows are
        available in the buffer, a set of rows are fetched from the database.
        The index into the buffer is returned along with a flag indicating
        whether a row was found or not.
        """
        cdef:
            uint32_t temp_buffer_row_index, num_rows_in_buffer
            bint more_rows_to_fetch
            int status
        if self._num_rows_in_buffer == 0 and self._more_rows_to_fetch:
            with nogil:
                status = dpiStmt_fetchRows(self._handle,
                                           self._fetch_array_size,
                                           &temp_buffer_row_index,
                                           &num_rows_in_buffer,
                                           &more_rows_to_fetch)
            if status < 0:
                errors._raise_from_odpi()
            self._num_rows_in_buffer = num_rows_in_buffer
            self._buffer_row_index = temp_buffer_row_index
            self._more_rows_to_fetch = more_rows_to_fetch
        if self._num_rows_in_buffer == 0:
            found[0] = False
        else:
            found[0] = True
            buffer_row_index[0] = self._buffer_row_index
            self._buffer_row_index += 1
            self._num_rows_in_buffer -= 1

    cdef object _fetch_next_row(self):
        """
        Internal method for fetching the next row from the cursor. If no rows
        are available, None is returned.
        """
        cdef:
            uint32_t buffer_row_index
            bint found
        self._fetch_row(&found, &buffer_row_index)
        if found:
            return self._create_row(buffer_row_index)

    cdef Variable _get_define_var(self, uint32_t pos):
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
            Variable var
            int status
            str name
        if dpiStmt_getQueryInfo(self._handle, pos, &query_info) < 0:
            _raise_from_odpi()
        dbtype = DbType.from_num(query_info.typeInfo.oracleTypeNum)
        if query_info.typeInfo.sizeInChars > 0:
            size = query_info.typeInfo.sizeInChars
        else:
            size = query_info.typeInfo.clientSizeInBytes
        type_handler = self.outputtypehandler \
                or self.connection.outputtypehandler
        if type_handler:
            name = query_info.name[query_info.nameLength].decode()
            result = type_handler(self, name, dbtype, size,
                                  query_info.typeInfo.precision,
                                  query_info.typeInfo.scale)
            if isinstance(result, Variable):
                return result
            elif result is not None:
                message = "expecting variable from output type handler"
                errors._raise_from_error(TypeError, message)
        var = Variable.new_var(self.connection, dbtype, self._fetch_array_size,
                               size)
        if dbtype.num == DPI_ORACLE_TYPE_NUMBER:
            type_info = &query_info.typeInfo
            if type_info.scale == 0 \
                    or (type_info.scale == -127 and type_info.precision == 0):
                var._number_as_int = True
        return var

    cdef int _perform_define(self, uint32_t num_query_cols) except -1:
        """
        Internal method for performing defines. At this point it is assumed
        that the statement executed was in fact a query.
        """
        cdef:
            uint32_t i, size
            Variable var

        # initialize fetching variables; these are used to reduce the number of
        # times that the GIL is released/acquired -- as there is a significant
        # amount of overhead in doing so
        self._num_rows_in_buffer = 0
        self._more_rows_to_fetch = True

        # if fetch variables already exist, nothing to do (the same statement
        # is being executed and therefore all defines have already been
        # performed
        if self._fetch_vars:
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
        if statement is None and self.statement is None:
            errors._raise_from_string(exceptions.ProgrammingError,
                    "no statement specified and no prior statement prepared")
        # nothing to do if the statement is identical to the one already
        # stored, but go ahead and prepare anyway for DDL statements
        if statement is None or statement == self.statement:
            if self._handle != NULL and not self._stmt_info.isDDL:
                return 0
            statement = self.statement
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
