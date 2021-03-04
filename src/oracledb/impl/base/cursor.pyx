#------------------------------------------------------------------------------
# Copyright (c) 2020, 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class BaseCursorImpl:

    def __cinit__(self, conn_impl):
        self.arraysize = 100
        self.prefetchrows = 2

    cdef int _bind_by_name(self, object cursor, dict params,
                           uint32_t num_elements=1, uint32_t pos=0) except -1:
        """
        Internal method used for binding variables by name.
        """
        cdef:
            BaseVar orig_var, var
            object value
            str name
        if self.bind_vars is None:
            self.bind_vars = {}
        for name, value in params.items():
            orig_var = self.bind_vars.get(name)
            var = self._get_bind_var(cursor, num_elements, pos, value,
                                     orig_var)
            self.bind_vars[name] = var

    cdef int _bind_by_position(self, object cursor, object params,
                               uint32_t num_elements=1,
                               uint32_t pos=0) except -1:
        """
        Internal method used for binding variables by position.
        """
        cdef:
            Py_ssize_t i, orig_num_vars
            BaseVar orig_var, var
            object value
        if self.bind_vars is None:
            orig_num_vars = 0
            self.bind_vars = [None] * len(params)
        else:
            orig_num_vars = len(self.bind_vars)
        for i, value in enumerate(params):
            if i < orig_num_vars:
                orig_var = <BaseVar> cpython.PyList_GET_ITEM(self.bind_vars,
                                                             i)
            else:
                orig_var = None
            var = self._get_bind_var(cursor, num_elements, pos, value,
                                     orig_var)
            if i < len(self.bind_vars):
                self.bind_vars[i] = var
            else:
                self.bind_vars.append(var)

    cdef int _close(self) except -1:
        """
        Internal method for closing the cursor.
        """
        raise NotImplementedError()

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cdef object _create_row(self):
        """
        Internal method for creating a row from the fetched data.
        """
        cdef:
            Py_ssize_t i, num_vars
            object row, value
            BaseVar var
        num_vars = cpython.PyList_GET_SIZE(self.fetch_vars)
        row = cpython.PyTuple_New(num_vars)
        for i in range(num_vars):
            var = self.fetch_vars[i]
            value = var._get_single_value(self._buffer_index)
            cpython.Py_INCREF(value)
            cpython.PyTuple_SET_ITEM(row, i, value)
        if self.rowfactory:
            row = self.rowfactory(*row)
        self._buffer_index += 1
        self._buffer_rowcount -= 1
        self.rowcount += 1
        return row

    cdef BaseVar _create_var(self, object connection):
        """
        Internal method for creating a variable.
        """
        raise NotImplementedError()

    cdef BaseVar _create_var_by_type(self, object connection, object value,
                                     uint32_t num_elements=1):
        """
        Internal method for creating a variable that can contain the specified
        type.
        """
        cdef BaseVar var
        if value is None:
            return None
        elif isinstance(value, BaseVar):
            return value
        elif isinstance(value, list):
            if len(value) != 2:
                message = "expecting a list of two elements [type, numelems]"
                errors._raise_from_string(exceptions.ProgrammingError, message)
            return self.arrayvar(connection, *value)
        var = self._create_var(connection)
        if isinstance(value, int):
            var._dbtype = DB_TYPE_VARCHAR
            var.size = value
        else:
            var._set_dbtype_from_type(value)
            var.size = var._dbtype.default_size
        var.num_elements = num_elements
        var._finalize_init()
        return var

    cdef BaseVar _create_var_by_value(self, object cursor, object value,
                                      uint32_t num_elements):
        """
        Internal method for creating a variable that can contain the
        specified value.
        """
        cdef:
            BaseDbObjectType objtype = None, temp_objtype
            DbType dbtype = None, temp_dbtype
            uint32_t size = 0, temp_size
            object type_handler, result
            bint is_array = False
            BaseDbObject obj
            BaseVar var

        # determine if an input type handler should be used; an input type
        # handler defined on the cursor takes precedence over one defined on
        # the connection to which the cursor belongs; the input type handler
        # should return a variable or None; the value None implies that the
        # default processing should take place just as if no input type handler
        # was defined
        type_handler = cursor.inputtypehandler or \
                cursor.connection.inputtypehandler
        if type_handler:
            result = type_handler(cursor, value, num_elements)
            if result is not None:
                if not isinstance(result, BaseVar):
                    message = "expecting variable from input type handler"
                    raise TypeError(message)
                return <BaseVar> result

        # determine the type and size of variable to create
        if isinstance(value, list):
            is_array = True
            if len(value) > num_elements:
                num_elements = len(value)
            for element in value:
                temp_size = 0
                temp_dbtype = DbType._from_value(element, &temp_size)
                if temp_dbtype is None:
                    continue
                if temp_dbtype is DB_TYPE_OBJECT:
                    obj = <BaseDbObject> value
                    temp_objtype = obj.type
                else:
                    temp_objtype = None
                if dbtype is None:
                    dbtype = temp_dbtype
                    objtype = temp_objtype
                    size = temp_size
                elif temp_dbtype is not dbtype or temp_objtype is not objtype:
                    message = f"element {element} is not the same type as " \
                               "previous elements"
                    errors._raise_from_string(exceptions.NotSupportedError,
                                              message)
                if temp_size > size:
                    size = temp_size
        else:
            dbtype = DbType._from_value(value, &size, self._is_plsql())
            if dbtype is DB_TYPE_OBJECT:
                obj = <BaseDbObject> value
                objtype = obj.type
        if dbtype is None:
            dbtype = DB_TYPE_VARCHAR
            size = 1

        # create the variable
        var = self._create_var(cursor.connection)
        var._dbtype = dbtype
        var._objtype = objtype
        var.num_elements = num_elements
        var.is_array = is_array
        var.size = size
        var._finalize_init()
        return var

    cdef int _fetch_rows(self, object cursor) except -1:
        """
        Internal method used for fetching rows from a cursor.
        """
        raise NotImplementedError()

    cdef BaseVar _get_bind_var(self, object cursor, uint32_t num_elements,
                               uint32_t pos, object value, BaseVar orig_var):
        """
        Internal method that returns the variable that will be bound with the
        specified value.
        """
        cdef BaseVar var
        if isinstance(value, BaseVar):
            return <BaseVar> value
        elif orig_var is not None:
            if num_elements <= orig_var.num_elements:
                var = orig_var
            else:
                var = self._create_var(cursor.connection)
                var.num_elements = num_elements
                var._dbtype = orig_var._dbtype
                var._objtype = orig_var._objtype
                var.is_array = orig_var.is_array
                var.size = orig_var.size
                var.inconverter = orig_var.inconverter
                var.outconverter = orig_var.outconverter
                var._finalize_init()
            try:
                var._set_value(pos, value)
                return var
            except TypeError:
                if pos > 0:
                    raise
        var = self._create_var_by_value(cursor, value, num_elements)
        var._set_value(pos, value)
        return var

    cdef bint _is_plsql(self):
        """
        Internal method that indicates whether the currently prepared statement
        is a PL/SQL statement or not.
        """
        raise NotImplementedError()

    cdef int _parse(self, object connection) except -1:
        """
        Internal method for parsing the currently prepared statement without
        executing it.
        """
        raise NotImplementedError()

    cdef int _perform_binds(self, uint32_t num_execs=1) except -1:
        """
        Perform all binds on the cursor.
        """
        cdef:
            Py_ssize_t pos
            BaseVar var
            str key
        if isinstance(self.bind_vars, dict):
            for key, var in self.bind_vars.items():
                var._bind(self, num_execs, key)
        else:
            for pos, var in enumerate(self.bind_vars):
                var._bind(self, num_execs, None, pos + 1)

    cdef int _prepare(self, str statement, str tag=None) except -1:
        """
        Internal method used for preparing a statement for execution.
        """
        raise NotImplementedError()

    cdef int _scroll(self, int32_t offset, uint32_t mode) except -1:
        """
        Internal method for scrolling a scrollable cursor.
        """
        raise NotImplementedError()

    def arrayvar(self, connection, typ, value, size=None):
        """
        Create an array variable associated with the cursor of the given type
        and size and return it.
        """
        cdef BaseVar var
        var = self._create_var(connection)
        var._set_dbtype_from_type(typ)
        var.is_array = True
        if isinstance(typ, BaseDbObjectType):
            var._objtype = typ
        if var._dbtype.default_size > 0:
            var.size = size or var._dbtype.default_size
        if isinstance(value, list):
            var.num_elements = len(value)
        elif isinstance(value, int):
            var.num_elements = value
        else:
            errors._raise_from_string(TypeError,
                                      "expecting integer or list of values")
        var._finalize_init()
        if isinstance(value, list):
            var.setvalue(0, value)
        return var

    def bind_many(self, cursor, parameters):
        """
        Internal method used for binding multiple rows of data.
        """
        cdef:
            object params_row, value
            ssize_t i, num_rows
        num_rows = len(parameters)
        for i in range(num_rows):
            params_row = parameters[i]
            if isinstance(params_row, dict):
                self._bind_by_name(cursor, params_row, num_rows, i)
            else:
                self._bind_by_position(cursor, params_row, num_rows, i)

    def bind_one(self, cursor, parameters):
        """
        Internal method used for binding a single row of data.
        """
        if isinstance(parameters, dict):
            self._bind_by_name(cursor, parameters)
        else:
            self._bind_by_position(cursor, parameters)

    def close(self):
        """
        Closes the cursor and makes it unusable for further operations.
        """
        self.bind_vars = None
        self.fetch_vars = None
        self._close()

    def execute(self, cursor):
        """
        Internal method used for executing a statement.
        """
        raise NotImplementedError()

    def executemany(self, cursor, num_execs, batcherrors, arraydmlrowcounts):
        """
        Internal method used for executing a statement many times.
        """
        raise NotImplementedError()

    def fetch_next_row(self, cursor):
        """
        Internal method used for fetching the next row from a cursor.
        """
        if self._buffer_rowcount == 0 and self._more_rows_to_fetch:
            self._fetch_rows(cursor)
        if self._buffer_rowcount > 0:
            return self._create_row()

    def get_array_dml_row_counts(self):
        """
        Internal method used for returning the list of array DML row counts.
        """
        raise NotImplementedError()

    def get_batch_errors(self):
        """
        Internal method used for returning a list with batch errors.
        """
        raise NotImplementedError()

    def get_bind_names(self):
        """
        Internal method used for getting bind names.
        """
        raise NotImplementedError()

    def get_description(self):
        """
        Internal method for populating the cursor description.
        """
        return [v.description for v in self.fetch_vars]

    def get_implicit_results(self, connection):
        """
        Internal method to return a list of cursors corresponding to the
        implicit results made available from a PL/SQL block or procedure.
        """
        raise NotImplementedError()

    def get_lastrowid(self):
        """
        Internal method for returning the last rowid associated with a cursor.
        """
        raise NotImplementedError()

    def is_query(self, cursor):
        """
        Internal method for determining if the cursor last executed a query.
        """
        raise NotImplementedError()

    def parse(self, cursor):
        """
        Parse the statement without executing it. This also retrieves
        describe information for queries.
        """
        self._parse(cursor)

    def prepare(self, statement):
        """
        Prepares a statement.
        """
        self._prepare(statement)

    def scroll(self, value, mode):
        """
        Scrolls a scrollable cursor.
        """
        cdef uint32_t int_mode = 0
        if mode == "relative":
            int_mode = FETCH_MODE_RELATIVE
        elif mode == "absolute":
            int_mode = FETCH_MODE_ABSOLUTE
        elif mode == "first":
            int_mode = FETCH_MODE_FIRST
        elif mode == "last":
            int_mode = FETCH_MODE_LAST
        else:
            message = "mode must be one of relative, absolute, first or last"
            errors._raise_from_string(exceptions.InterfaceError, message)
        self._scroll(value, int_mode)

    def setinputsizes(self, cursor, args, kwargs):
        conn = cursor.connection
        if kwargs:
            self.bind_vars = {}
            for key, value in kwargs.items():
                self.bind_vars[key] = self._create_var_by_type(conn, value)
        else:
            self.bind_vars = [self._create_var_by_type(conn, v) for v in args]

    def var(self, cursor, typ, size=0, arraysize=1, inconverter=None,
            outconverter=None, typename=None, encoding_errors=None):
        cdef BaseVar var
        var = self._create_var(cursor.connection)
        if isinstance(typ, BaseDbObjectType):
            var._objtype = typ
            var._dbtype = DB_TYPE_OBJECT
        else:
            var._set_dbtype_from_type(typ)
        if typename:
            var._objtype = cursor.connection.gettype(typename)
        if var._dbtype.default_size > 0:
            var.size = size or var._dbtype.default_size
        var.num_elements = arraysize
        var.inconverter = inconverter
        var.outconverter = outconverter
        var._finalize_init()
        return var
