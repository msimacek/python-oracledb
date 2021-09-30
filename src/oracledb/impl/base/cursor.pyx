#------------------------------------------------------------------------------
# Copyright (c) 2020, 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class BaseCursorImpl:

    cdef int _bind_by_name(self, object cursor, dict params,
                           uint32_t num_elements=1, uint32_t pos=0) except -1:
        """
        Internal method used for binding variables by name.
        """
        cdef:
            object orig_var, var, value
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
            object orig_var, var, value
        if self.bind_vars is None:
            orig_num_vars = 0
            self.bind_vars = [None] * len(params)
        else:
            orig_num_vars = len(self.bind_vars)
        for i, value in enumerate(params):
            if i < orig_num_vars:
                orig_var = self.bind_vars[i]
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

    cdef object _create_default_fetch_var(self, object typ,
                                          str name, uint32_t size,
                                          int16_t precision, int16_t scale,
                                          bint nulls_allowed):
        """
        Creates a default variable given fetch information. The defaults for
        fetching LOBs and decimals are also consulted and adjustments made as
        needed.
        """
        if defaults.fetch_decimals and typ is DB_TYPE_NUMBER:
            typ = decimal.Decimal
        elif not defaults.fetch_lobs:
            if typ is DB_TYPE_BLOB:
                typ = DB_TYPE_LONG_RAW
            elif typ is DB_TYPE_CLOB or typ is DB_TYPE_NCLOB:
                typ = DB_TYPE_LONG
        return self.create_var(typ, name=name, size=size, precision=precision,
                               scale=scale, nulls_allowed=nulls_allowed,
                               num_elements=self._fetch_array_size,
                               inconverter=None, outconverter=None,
                               encoding_errors=None, bypass_decode=False,
                               is_array=False)

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cdef object _create_row(self):
        """
        Internal method for creating a row from the fetched data.
        """
        cdef:
            Py_ssize_t i, num_vars
            BaseVarImpl var_impl
            object row, value
        num_vars = cpython.PyList_GET_SIZE(self.fetch_vars)
        row = cpython.PyTuple_New(num_vars)
        for i in range(num_vars):
            var_impl = self.fetch_vars[i]._impl
            value = var_impl.values[self._buffer_index]
            cpython.Py_INCREF(value)
            cpython.PyTuple_SET_ITEM(row, i, value)
        if self.rowfactory:
            row = self.rowfactory(*row)
        self._buffer_index += 1
        self._buffer_rowcount -= 1
        self.rowcount += 1
        return row

    cdef BaseVarImpl _create_var_impl(self):
        """
        Internal method for creating a variable.
        """
        raise NotImplementedError()

    cdef object _create_var_by_type(self, object value,
                                    uint32_t num_elements=1):
        """
        Internal method for creating a variable that can contain the specified
        type.
        """
        if value is None:
            return None
        elif isinstance(value, Var):
            return value
        elif isinstance(value, list):
            if len(value) != 2:
                errors._raise_err(errors.ERR_WRONG_ARRAY_DEFINITION)
            return self.create_var(typ=value[0], num_elements=value[1],
                                   is_array=True)
        elif isinstance(value, int):
            return self.create_var(DB_TYPE_VARCHAR, size=value,
                                   num_elements=num_elements)
        return self.create_var(value, num_elements=num_elements)

    cdef object _create_var_by_value(self, object cursor, object value,
                                     uint32_t num_elements):
        """
        Internal method for creating a variable that can contain the
        specified value.
        """
        cdef:
            object type_handler, result, typ, temp_typ
            uint32_t size, temp_size

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
                if not isinstance(result, Var):
                    message = "expecting variable from input type handler"
                    raise TypeError(message)
                return result

        # handle scalar values
        if not isinstance(value, list):
            typ = self._get_type_and_size(value, &size, self._is_plsql())
            return self.create_var(typ, size=size, num_elements=num_elements)

        # handle arrays
        if len(value) > num_elements:
            num_elements = len(value)
        size = 0
        typ = None
        for element in value:
            temp_typ = self._get_type_and_size(element, &temp_size,
                                               self._is_plsql())
            if temp_typ is None:
                continue
            if typ is None:
                typ = temp_typ
            elif temp_typ is not typ:
                errors._raise_err(errors.ERR_MIXED_ELEMENT_TYPES,
                                  element=element)
            if temp_size > size:
                size = temp_size
        return self.create_var(typ, size=size, num_elements=num_elements,
                               is_array=True)

    cdef int _fetch_rows(self, object cursor) except -1:
        """
        Internal method used for fetching rows from a cursor.
        """
        raise NotImplementedError()

    cdef object _get_bind_var(self, object cursor, uint32_t num_elements,
                              uint32_t pos, object value, object orig_var):
        """
        Internal method that returns the variable that will be bound with the
        specified value.
        """
        cdef BaseVarImpl var_impl, orig_var_impl
        if isinstance(value, Var):
            return value
        elif orig_var is not None:
            orig_var_impl = orig_var._impl
            if num_elements <= orig_var_impl.num_elements:
                var = orig_var
                var_impl = orig_var_impl
            else:
                var_impl = self._create_var_impl()
                var_impl.num_elements = num_elements
                var_impl.dbtype = orig_var_impl.dbtype
                var_impl._objtype = orig_var_impl._objtype
                var_impl.is_array = orig_var_impl.is_array
                var_impl.size = orig_var_impl.size
                var_impl.buffer_size = orig_var_impl.buffer_size
                var_impl.inconverter = orig_var_impl.inconverter
                var_impl.outconverter = orig_var_impl.outconverter
                var_impl.values = [None] * num_elements
                var = Var._from_impl(var_impl, orig_var._type)
            try:
                var_impl.set_value(pos, value)
                return var
            except TypeError:
                if pos > 0:
                    raise
        var = self._create_var_by_value(cursor, value, num_elements)
        var_impl = var._impl
        var_impl.set_value(pos, value)
        return var

    cdef object _get_type_and_size(self, object value, uint32_t *size, bint
                                   is_plsql=True):
        """
        Internal method used for determining the type to use for a variable
        given a Python value. This will either be a DbObjectType or one of the
        DbType constants.
        """
        if value is None:
            size[0] = 1
            return None
        elif isinstance(value, bool):
            if is_plsql:
                return DB_TYPE_BOOLEAN
            return DB_TYPE_BINARY_INTEGER
        elif isinstance(value, str):
            size[0] = <uint32_t> len(value)
            return DB_TYPE_VARCHAR
        elif isinstance(value, bytes):
            size[0] = <uint32_t> len(value)
            return DB_TYPE_RAW
        elif isinstance(value, (int, float, decimal.Decimal)):
            return DB_TYPE_NUMBER
        elif isinstance(value, (datetime.date, datetime.datetime)):
            return DB_TYPE_DATE
        elif isinstance(value, datetime.timedelta):
            return DB_TYPE_INTERVAL_DS
        elif isinstance(value, DbObject):
            return value.type
        elif isinstance(value, LOB):
            return value.type
        elif isinstance(value, Cursor):
            return DB_TYPE_CURSOR
        else:
            errors._raise_err(errors.ERR_PYTHON_VALUE_NOT_SUPPORTED,
                              type_name=type(value).__name__)

    cdef bint _is_plsql(self):
        """
        Internal method that indicates whether the currently prepared statement
        is a PL/SQL statement or not.
        """
        raise NotImplementedError()

    cdef int _perform_binds(self, object conn, uint32_t num_execs=1) except -1:
        """
        Perform all binds on the cursor.
        """
        cdef:
            BaseVarImpl var_impl
            Py_ssize_t pos
            object var
            str key
        if isinstance(self.bind_vars, dict):
            for key, var in self.bind_vars.items():
                var_impl = <BaseVarImpl> var._impl
                var_impl._bind(conn, self, num_execs, key)
        else:
            for pos, var in enumerate(self.bind_vars):
                var_impl = <BaseVarImpl> var._impl
                var_impl._bind(conn, self, num_execs, None, pos + 1)

    cdef int _scroll(self, object conn, int32_t offset,
                     uint32_t mode) except -1:
        """
        Internal method for scrolling a scrollable cursor.
        """
        raise NotImplementedError()

    cdef int _verify_var(self, object var) except -1:
        """
        Internal method used for verifying if an outputtypehandler returns a
        valid var object.
        """
        if not isinstance(var, Var):
            errors._raise_err(errors.ERR_EXPECTING_VAR)
        if self.arraysize > var.num_elements:
            errors._raise_err(errors.ERR_INCORRECT_VAR_ARRAYSIZE,
                              var_arraysize=var.num_elements,
                              required_arraysize=self.arraysize)

    def bind_many(self, cursor, parameters):
        """
        Internal method used for binding multiple rows of data.
        """
        cdef:
            object params_row, value
            ssize_t i, num_rows
            bint has_pos_bind=False, has_name_bind=False
        num_rows = len(parameters)
        for i in range(num_rows):
            params_row = parameters[i]
            if isinstance(params_row, dict):
                if has_pos_bind:
                    errors._raise_err(errors.ERR_MIXED_POSITIONAL_AND_NAMED_BINDS)
                self._bind_by_name(cursor, params_row, num_rows, i)
                has_name_bind = True
            elif isinstance(params_row, (list, tuple)):
                if has_name_bind:
                    errors._raise_err(errors.ERR_MIXED_POSITIONAL_AND_NAMED_BINDS)
                self._bind_by_position(cursor, params_row, num_rows, i)
                has_pos_bind = True
            else:
                errors._raise_err(errors.ERR_WRONG_EXECUTEMANY_PARAMETERS_TYPE)

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

    cpdef create_var(self, object typ, uint32_t size=0,
                     uint32_t num_elements=1, object inconverter=None,
                     object outconverter=None, str encoding_errors=None,
                     bint bypass_decode=False, int16_t precision=0,
                     int16_t scale=0, str name=None, bint nulls_allowed=False,
                     bint is_array=False):
        cdef BaseVarImpl impl
        impl = self._create_var_impl()
        impl._set_type(typ)
        if impl.dbtype.default_size > 0:
            impl.size = size or impl.dbtype.default_size
            impl.buffer_size = impl.size * impl.dbtype._buffer_size_factor
        else:
            impl.buffer_size = impl.dbtype._buffer_size_factor
        if num_elements == 0:
            impl.num_elements = 1
        else:
            impl.num_elements = num_elements
        impl.inconverter = inconverter
        impl.outconverter = outconverter
        impl.bypass_decode = bypass_decode
        impl.is_array = is_array
        impl.values = [None] * impl.num_elements
        impl.precision = precision
        impl.scale = scale
        impl.nulls_allowed = nulls_allowed
        impl.name = name
        if impl.dbtype is DB_TYPE_NUMBER \
                and impl._preferred_num_type == NUM_TYPE_FLOAT:
            if scale == 0 or (scale == -127 and precision == 0):
                impl._preferred_num_type = NUM_TYPE_INT
        return Var._from_impl(impl, typ)

    @utils.CheckImpls("executing a statement")
    def execute(self, cursor):
        pass

    @utils.CheckImpls("executing a statement in batch")
    def executemany(self, cursor, num_execs, batcherrors, arraydmlrowcounts):
        pass

    def fetch_next_row(self, cursor):
        """
        Internal method used for fetching the next row from a cursor.
        """
        if self._buffer_rowcount == 0 and self._more_rows_to_fetch:
            self._fetch_rows(cursor)
        if self._buffer_rowcount > 0:
            return self._create_row()

    @utils.CheckImpls("getting a list of array DML row counts")
    def get_array_dml_row_counts(self):
        pass

    @utils.CheckImpls("getting a list of batch errors")
    def get_batch_errors(self):
        pass

    @utils.CheckImpls("getting a list of bind variable names")
    def get_bind_names(self):
        pass

    def get_description(self):
        """
        Internal method for populating the cursor description.
        """
        return [v._impl.get_description() for v in self.fetch_vars]

    @utils.CheckImpls("getting implicit results from PL/SQL")
    def get_implicit_results(self, connection):
        pass

    @utils.CheckImpls("getting the rowid of the row last modified")
    def get_lastrowid(self):
        pass

    @utils.CheckImpls("determining if the cursor last executed a query")
    def is_query(self, cursor):
        pass

    @utils.CheckImpls("parsing a statement without executing it")
    def parse(self, cursor):
        pass

    @utils.CheckImpls("preparing a statement")
    def prepare(self, str statement, str tag, bint cache_statement):
        pass

    def scroll(self, conn, value, mode):
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
            errors._raise_err(errors.ERR_WRONG_SCROLL_MODE)
        self._scroll(conn, value, int_mode)

    def setinputsizes(self, cursor, args, kwargs):
        if kwargs:
            self.bind_vars = {}
            for key, value in kwargs.items():
                self.bind_vars[key] = self._create_var_by_type(value)
        else:
            self.bind_vars = [self._create_var_by_type(v) for v in args]
