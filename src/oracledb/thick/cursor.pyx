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
        dpiStmt *_handle
        dpiStmtInfo _stmt_info;
        str _tag

    def __cinit__(self, connection):
        self.connection = connection

    def __dealloc__(self):
        if self._handle != NULL:
            dpiStmt_release(self._handle)

    cdef int _execute(Cursor self) except -1:
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
            if status == 0:
                status = dpiStmt_getRowCount(self._handle, &rowcount)
        if status < 0:
            _raise_from_odpi()
        self.rowcount = rowcount

    cdef int _prepare(Cursor self, str statement, str tag=None) except -1:
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
            if status == 0:
                status = dpiStmt_getInfo(self._handle, &self._stmt_info)
            if status == 0 and self._stmt_info.isQuery:
                status = dpiStmt_setFetchArraySize(self._handle,
                                                   self.arraysize)
                if status == 0 \
                        and self.prefetchrows != DPI_DEFAULT_PREFETCH_ROWS:
                    status = dpiStmt_setPrefetchRows(self._handle,
                                                     self.prefetchrows)
        if status < 0:
            _raise_from_odpi()

    def execute(self, statement=None, parameters=None, **keyword_parameters):
        """
        Executes a statement, passing any parameters to the database.
        """

        # verify parameters
        if parameters and keyword_parameters:
            errors._raise_from_string(exceptions.InterfaceError,
                    "expecting argument or keyword arguments, not both")
        if parameters is not None \
                and not isinstance(parameters, (list, tuple, dict)):
            errors._raise_from_string(exceptions.InterfaceError,
                    "expecting a dictionary, list or tuple, or keyword args")
        self._verify_open()

        # prepare statement, if necessary, and then execute it
        self._prepare(statement)
        self._execute()
