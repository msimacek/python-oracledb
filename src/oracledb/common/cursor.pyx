#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

from .. import constants

cdef class BaseCursor:

    def __cinit__(self, connection):
        self.connection = connection
        self.arraysize = 100
        self.prefetchrows = 2
        self._is_open = True

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, exc_tb):
        self.close()

    def __iter__(self):
        return self

    def __next__(self):
        self._verify_fetch()
        row = self._fetch_next_row()
        if row is not None:
            return row
        raise StopIteration

    def __repr__(self):
        return f"<oracledb.Cursor on {self.connection!r}>"

    cdef int _bind_by_name(self, dict params, uint32_t num_elements=1,
                           uint32_t pos=0) except -1:
        """
        Internal method used for binding variables by name.
        """
        cdef:
            BaseVar orig_var, var
            object value
            str name
        if self._bind_vars is None:
            self._bind_vars = {}
        for name, value in params.items():
            orig_var = self._bind_vars.get(name)
            var = self._get_bind_var(num_elements, pos, value, orig_var)
            self._bind_vars[name] = var

    cdef int _bind_by_position(self, object params, uint32_t num_elements=1,
                               uint32_t pos=0) except -1:
        """
        Internal method used for binding variables by position.
        """
        cdef:
            Py_ssize_t i, orig_num_vars
            BaseVar orig_var, var
            object value
        if self._bind_vars is None:
            orig_num_vars = 0
            self._bind_vars = [None] * len(params)
        else:
            orig_num_vars = len(self._bind_vars)
        for i, value in enumerate(params):
            if i < orig_num_vars:
                orig_var = <BaseVar> cpython.PyList_GET_ITEM(self._bind_vars,
                                                             i)
            else:
                orig_var = None
            var = self._get_bind_var(num_elements, pos, value, orig_var)
            if i < len(self._bind_vars):
                self._bind_vars[i] = var
            else:
                self._bind_vars.append(var)

    cdef object _bindnames(self):
        """
        Internal method used for getting bind names.
        """
        raise NotImplementedError()

    def _call(self, name, parameters, keyword_parameters, return_value=None):

        # verify parameters
        if parameters is not None \
                and not isinstance(parameters, (list, tuple)):
            raise TypeError("arguments must be a list or tuple")
        if keyword_parameters is not None \
                and not isinstance(keyword_parameters, dict):
            raise TypeError("keyword arguments must be a dict")
        self._verify_open()

        # build statement
        bind_names = []
        bind_values = []
        statement_parts = ["begin "]
        if return_value is not None:
            statement_parts.append(":retval := ")
            bind_values.append(return_value)
        statement_parts.append(name + "(")
        if parameters:
            bind_values.extend(parameters)
            bind_names = [":%d" % (i + 1) for i in range(len(parameters))]
        if keyword_parameters:
            for arg_name, arg_value in keyword_parameters.items():
                bind_values.append(arg_value)
                bind_names.append(f"{arg_name} => :{len(bind_names) + 1}")
        statement_parts.append(",".join(bind_names))
        statement_parts.append("); end;")
        statement = "".join(statement_parts)
        self.execute(statement, bind_values)

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
        num_vars = cpython.PyList_GET_SIZE(self._fetch_vars)
        row = cpython.PyTuple_New(num_vars)
        for i in range(num_vars):
            var = self._fetch_vars[i]
            value = var._get_single_value(self._buffer_index)
            cpython.Py_INCREF(value)
            cpython.PyTuple_SET_ITEM(row, i, value)
        if self.rowfactory:
            row = self.rowfactory(*row)
        self._buffer_index += 1
        self._buffer_rowcount -= 1
        self.rowcount += 1
        return row

    cdef BaseVar _create_var(self):
        """
        Internal method for creating a variable.
        """
        raise NotImplementedError()

    cdef BaseVar _create_var_by_type(self, object value,
                                     uint32_t num_elements=1):
        """
        Internal method for creating a variable that can contain the specified
        type.
        """
        cdef:
            uint32_t size = 0
            DbType dbtype
            BaseVar var
        if value is None:
            return None
        elif isinstance(value, int):
            dbtype = DB_TYPE_VARCHAR
            size = value
        elif isinstance(value, BaseVar):
            return value
        elif isinstance(value, list):
            if len(value) != 2:
                message = "expecting a list of two elements [type, numelems]"
                errors._raise_from_string(exceptions.ProgrammingError, message)
            return self.arrayvar(*value)
        else:
            dbtype = DbType._from_type(value)
            size = dbtype.default_size
        var = self._create_var()
        var._dbtype = dbtype
        var.num_elements = num_elements
        var.size = size
        if size > 0:
            var.buffer_size = size * dbtype._buffer_size_factor
        else:
            var.buffer_size = dbtype._buffer_size_factor
        var.is_array = False
        var._finalize_init()
        return var

    cdef BaseVar _create_var_by_value(self, object value,
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
        type_handler = self.inputtypehandler \
                or self.connection.inputtypehandler
        if type_handler:
            result = type_handler(self, value, num_elements)
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
                    temp_dbtype = None
                if dbtype is None:
                    dbtype = temp_dbtype
                    objtype = temp_objtype
                    size = temp_size
                elif temp_dbtype is not dbtype or temp_objtype is not objtype:
                    message = f"element {element} is not the same type as" \
                               "previous elements"
                    errors._raise_from_string(exceptions.NotSuppportedError,
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
        var = self._create_var()
        var._dbtype = dbtype
        var._objtype = objtype
        var.num_elements = num_elements
        var.is_array = is_array
        var.size = size
        if size > 0:
            var.buffer_size = size * dbtype._buffer_size_factor
        else:
            var.buffer_size = dbtype._buffer_size_factor
        var._finalize_init()
        return var

    cdef int _execute(self) except -1:
        """
        Internal method used for executing a statement.
        """
        raise NotImplementedError()

    cdef int _executemany(self, uint32_t num_execs, bint batcherrors,
                          bint arraydmlrowcounts) except -1:
        """
        Internal method used for executing a statement many times.
        """
        raise NotImplementedError()

    cdef object _fetch_next_row(self):
        """
        Internal method used for fetching the next row from a cursor.
        """
        if self._buffer_rowcount == 0 and self._more_rows_to_fetch:
            self._fetch_rows()
        if self._buffer_rowcount > 0:
            return self._create_row()

    cdef int _fetch_rows(self) except -1:
        """
        Internal method used for fetching rows from a cursor.
        """
        raise NotImplementedError()

    cdef object _get_array_dml_row_counts(self):
        """
        Internal method used for populating list with arraydmlrowcount.
        """
        raise NotImplementedError()

    cdef object _get_batch_errors(self):
        """
        Internal method used for populating list with batch error objects.
        """
        raise NotImplementedError()

    cdef BaseVar _get_bind_var(self, uint32_t num_elements, uint32_t pos,
                               object value, BaseVar orig_var):
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
                var = self._create_var()
                var.num_elements = num_elements
                var._dbtype = orig_var._dbtype
                var._objtype = orig_var._objtype
                var.is_array = orig_var.is_array
                var.size = orig_var.size
                var.buffer_size = orig_var.buffer_size
                var.inconverter = orig_var.inconverter
                var.outconverter = orig_var.outconverter
                var._finalize_init()
            try:
                var._set_value(pos, value)
                return var
            except:
                if pos > 0:
                    raise
        var = self._create_var_by_value(value, num_elements)
        var._set_value(pos, value)
        return var

    cdef object _get_lastrowid(self):
        """
        Internal method for returning the last rowid associated with a cursor.
        """
        raise NotImplementedError()

    cdef bint _is_plsql(self):
        """
        Internal method that indicates whether the currently prepared statement
        is a PL/SQL statement or not.
        """
        raise NotImplementedError()

    cdef bint _is_query(self) except *:
        """
        Internal method that indicates whether the currently statement is a
        query or not.
        """
        raise NotImplementedError()

    cdef int _parse(self) except -1:
        """
        Internal method for parsing the currently prepared statement without
        executing it.
        """
        raise NotImplementedError()

    cdef int _perform_binds(self) except -1:
        """
        Perform all binds on the cursor.
        """
        cdef:
            Py_ssize_t pos
            BaseVar var
            str key
        self._set_input_sizes = False
        if isinstance(self._bind_vars, dict):
            for key, var in self._bind_vars.items():
                var._bind(self, key)
        else:
            for pos, var in enumerate(self._bind_vars):
                var._bind(self, None, pos + 1)

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

    cdef int _verify_fetch(self) except -1:
        """
        Verifies that fetching is possible from this cursor.
        """
        self._verify_open()
        if not self._is_query():
            errors._raise_from_string(exceptions.InterfaceError, "not a query")

    cdef int _verify_open(self) except -1:
        """
        Verifies that the cursor is open and the associated connection is
        connected. If either condition is false an exception is raised.
        """
        cdef BaseConnection connection
        if not self._is_open:
            errors._raise_from_string(exceptions.InterfaceError, "not open")
        connection = <BaseConnection> self.connection
        connection._verify_connected()

    def arrayvar(self, typ, value, size=None):
        """
        Create an array variable associated with the cursor of the given type
        and size and return it.
        """
        cdef:
            DbType dbtype
            BaseVar var
        dbtype = DbType._from_type(typ)
        var = self._create_var()
        var.is_array = True
        var._dbtype = dbtype
        if isinstance(typ, BaseDbObjectType):
            var._objtype = typ
        if dbtype.default_size > 0:
            var.size = size or dbtype.default_size
            var.buffer_size = var.size * dbtype._buffer_size_factor
        else:
            var.buffer_size = dbtype._buffer_size_factor
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

    def bindnames(self):
        """
        Returns a list of bind names.
        """
        self._verify_open()
        if self.statement is None:
            message = "statement must be prepared first"
            errors._raise_from_string(exceptions.ProgrammingError, message)
        return self._bindnames()

    @property
    def bindvars(self):
        return self._bind_vars or []

    def callfunc(self, name, return_type, parameters=None, **kwargs):
        """
        Call a stored function and return the return value from the stored
        function.
        """
        var = self.var(return_type)
        self._call(name, parameters, kwargs, var)
        return var.getvalue()

    def callproc(self, name, parameters=None, kwargs=None):
        """
        Call a stored procedure and return the (possibly modified) arguments.
        Note that only the positional arguments are returned.
        """
        self._call(name, parameters, kwargs)
        if parameters is None:
            return []
        return [v.getvalue() for v in self._bind_vars[:len(parameters)]]

    def close(self):
        """
        Closes the cursor and makes it unusable for further operations.
        """
        self._verify_open()
        self._bind_vars = None
        self._fetch_vars = None
        self._close()
        self._is_open = False

    @property
    def description(self):
        if self._is_query():
            return [v.description for v in self._fetch_vars]

    def execute(self, statement=None, parameters=None, **keyword_parameters):
        """
        Executes a statement, passing any parameters to the database.
        """

        # verify parameters
        if statement is None and self.statement is None:
            message = "no statement specified and no prior statement prepared"
            errors._raise_from_string(exceptions.ProgrammingError, message)
        if keyword_parameters:
            if parameters:
                errors._raise_from_string(exceptions.InterfaceError,
                        "expecting arguments or keyword arguments, not both")
            parameters = keyword_parameters
        elif parameters is not None \
                and not isinstance(parameters, (list, tuple, dict)):
            errors._raise_from_string(exceptions.InterfaceError,
                    "expecting a dictionary, list or tuple, or keyword args")
        prepare_needed = statement and statement != self.statement
        if not (prepare_needed and not self._set_input_sizes) \
                and self._bind_vars is not None and parameters is not None:
            if isinstance(self._bind_vars, dict) \
                    and not isinstance(parameters, dict) \
                    or isinstance(self._bind_vars, list) \
                    and isinstance(parameters, dict):
                message = "positional and named binds cannot be intermixed"
                errors._raise_from_string(exceptions.ProgrammingError, message)

        # prepare statement, if necessary
        self._verify_open()
        if prepare_needed:
            self._fetch_vars = None
            if not self._set_input_sizes:
                self._bind_vars = None
            self._prepare(statement)

        # perform bind and execute
        if parameters is not None:
            if isinstance(parameters, dict):
                self._bind_by_name(parameters)
            else:
                self._bind_by_position(parameters)
        self._execute()
        if self._fetch_vars is not None:
            return self

    def executemany(self, statement, parameters, batcherrors=False,
                    arraydmlrowcounts=False):
        """
        Executes a statement many times equal to the number of elements in the
        list of parameters or the provided integer. Arraydmlrowcounts and
        batcherrors can be set.
        """
        cdef uint32_t num_execs, i

        # verify parameters
        if statement is None and self.statement is None:
            message = "no statement specified and no prior statement prepared"
            errors._raise_from_string(exceptions.ProgrammingError, message)
        if not isinstance(parameters, (list, int)):
            message = "parameters should be a list of sequences or " \
                      "dictionaries, or an integer specifying the number of " \
                      "times to execute the statement"
            errors._raise_from_string(TypeError, message)

        # prepare statement if necessary
        self._verify_open()
        if statement and statement != self.statement:
            self._fetch_vars = None
            if not self._set_input_sizes:
                self._bind_vars = None
            self._prepare(statement)

        # perform binds
        if isinstance(parameters, int):
            num_execs = parameters
        else:
            num_execs = len(parameters)
            for i in range(num_execs):
                if isinstance(parameters[i], dict):
                    self._bind_by_name(parameters[i], num_execs, i)
                else:
                    self._bind_by_position(parameters[i], num_execs, i)

        self._executemany(num_execs, bool(batcherrors),
                          bool(arraydmlrowcounts))

    def fetchall(self):
        """
        Fetches all of the remaining rows available from the cursor and returns
        them as a list.
        """
        self._verify_fetch()
        result = []
        while True:
            row = self._fetch_next_row()
            if row is None:
                break
            result.append(row)
        return result

    def fetchmany(self, num_rows=None):
        """
        Fetches up to the specified number of rows from the cursor and returns
        them as a list. If the number of rows is not specified, the cursor's
        arraysize is used instead.
        """
        self._verify_fetch()
        if num_rows is None:
            num_rows = self.arraysize
        result = []
        while len(result) < num_rows:
            row = self._fetch_next_row()
            if row is None:
                break
            result.append(row)
        return result

    def fetchone(self):
        """
        Fetches a single row from the cursor and returns it. If no rows are
        available, None is returned.
        """
        self._verify_fetch()
        return self._fetch_next_row()

    def getarraydmlrowcounts(self):
        """
        Populates the arraydmlrowcount row count list.
        """
        return self._get_array_dml_row_counts()

    def getbatcherrors(self):
        """
        Populates the batch error list with error objects.
        """
        return self._get_batch_errors()

    @property
    def lastrowid(self):
        self._verify_open()
        return self._get_lastrowid()

    def parse(self, statement):
        """
        Parse the statement without executing it. This also retrieves
        describe information for queries.
        """
        self._verify_open()
        self._prepare(statement)
        self._parse()

    def prepare(self, statement):
        """
        Prepares a statement.
        """
        self._prepare(statement)

    def scroll(self, value=0, mode="relative"):
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
        self._verify_open()
        self._scroll(value, int_mode)

    def setinputsizes(self, *args, **kwargs):
        if args and kwargs:
            message = "expecting arguments or keyword arguments, not both"
            errors._raise_from_string(exceptions.InterfaceError, message)
        self._verify_open()
        if kwargs:
            self._bind_vars = {}
            for key, value in kwargs.items():
                self._bind_vars[key] = self._create_var_by_type(value)
        elif args:
            self._bind_vars = [self._create_var_by_type(v) for v in args]
        else:
            return []
        self._set_input_sizes = True
        return self._bind_vars

    def setoutputsize(self, size, column=0):
        """
        Sets a column buffer size for fetches of long columns but the driver
        does not require it so nothing is done here.
        """
        pass

    def var(self, typ, size=0, arraysize=1, inconverter=None,
            outconverter=None, typename=None, encoding_errors=None):
        cdef:
            DbType dbtype
            BaseVar var
        var = self._create_var()
        if isinstance(typ, BaseDbObjectType):
            var._objtype = typ
            dbtype = DB_TYPE_OBJECT
        else:
            dbtype = DbType._from_type(typ)
        var._dbtype = dbtype
        if typename:
            var._objtype = self.connection._get_type(typename)
        if dbtype.default_size > 0:
            var.size = size or dbtype.default_size
            var.buffer_size = var.size * dbtype._buffer_size_factor
        else:
            var.buffer_size = dbtype._buffer_size_factor
        var.num_elements = arraysize
        var.inconverter = inconverter
        var.outconverter = outconverter
        var._finalize_init()
        return var
