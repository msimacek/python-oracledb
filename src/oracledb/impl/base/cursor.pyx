#------------------------------------------------------------------------------
# Copyright (c) 2020, 2022, Oracle and/or its affiliates.
# This program is free software: you can modify it and/or redistribute it
# under the terms of:
#
# (i)  the Universal Permissive License v 1.0 or at your option, any
#      later version (http://oss.oracle.com/licenses/upl); and/or
#
# (ii) the Apache License v 2.0. (http://www.apache.org/licenses/LICENSE-2.0)
#------------------------------------------------------------------------------

cdef class BaseCursorImpl:

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cdef int _bind_type(self,
                        BindVarCollection bind_vars,
                        BindVarCollection bind_var_impls,
                        BindVarKey key,
                        object typ) except -1:
        """
        Internal method used for setting a bind variable given a Python type.
        Fused types are used in order to improve performance while retaining
        readability and in order to avoid duplicating code.
        """
        cdef BaseVarImpl var_impl
        if isinstance(typ, PY_TYPE_VAR):
            bind_vars[key] = typ
            bind_var_impls[key] = typ._impl
        else:
            var_impl = self._create_var_impl_from_type(typ)
            typ = typ if isinstance(typ, PY_TYPE_DB_OBJECT_TYPE) \
                    else var_impl.dbtype
            bind_vars[key] = Var._from_impl(var_impl, typ)
            bind_var_impls[key] = var_impl

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cdef int _bind_type_by_name(self, dict params) except -1:
        """
        Internal method used for setting bind variables by type by name.
        """
        cdef:
            dict bind_vars, bind_var_impls
            object typ
        bind_vars = self.bind_vars = {}
        bind_var_impls = self.bind_var_impls = {}
        for name, value in params.items():
            if value is not None:
                self._bind_type(bind_vars, bind_var_impls, name, value)

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cdef int _bind_type_by_position(self, tuple params) except -1:
        """
        Internal method used for setting binding variables by position.
        """
        cdef:
            list bind_vars, bind_var_impls
            ssize_t i, num_params
        num_params = len(params)
        bind_vars = self.bind_vars = [None] * num_params
        bind_var_impls = self.bind_var_impls = [None] * num_params
        for i, value in enumerate(params):
            if value is not None:
                self._bind_type(bind_vars, bind_var_impls, i, value)

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cdef int _bind_value(self,
                         object cursor,
                         object type_handler,
                         BindVarCollection bind_vars,
                         BindVarCollection bind_var_impls,
                         BindVarKey key,
                         object value,
                         uint32_t num_elements,
                         uint32_t pos) except -1:
        """
        Internal method used for setting a bind variable given a Python value.
        If no bind variable exists in the bind variable collection for the
        given key, a new bind variable is created. Fused types are used in
        order to improve performance while retaining readability and in order
        to avoid duplicating code.
        """
        cdef:
            BaseVarImpl orig_var_impl, var_impl
            object orig_var, var, typ

        # if the value to be bound is a variable, use it directly
        if isinstance(value, PY_TYPE_VAR):
            if BindVarCollection is dict:
                orig_var = bind_vars.get(key)
            else:
                orig_var = bind_vars[key]
            if value is not orig_var:
                bind_vars[key] = value
                bind_var_impls[key] = value._impl
            return 0

        # see if a variable was bound previously, and if so, attempt to set the
        # value in this variable; a failure to set the value will simply result
        # in a new variable being created; if the number of elements has
        # increased, a new variable is also created using the same type
        # information
        if BindVarCollection is dict:
            orig_var_impl = bind_var_impls.get(key)
        else:
            orig_var_impl = bind_var_impls[key]
        if orig_var_impl is not None:
            if num_elements <= orig_var_impl.num_elements:
                var_impl = orig_var_impl
            else:
                var_impl = self._create_var_impl()
                var_impl.num_elements = num_elements
                var_impl.dbtype = orig_var_impl.dbtype
                var_impl.objtype = orig_var_impl.objtype
                var_impl.is_array = orig_var_impl.is_array
                var_impl.size = orig_var_impl.size
                var_impl.buffer_size = orig_var_impl.buffer_size
                var_impl.inconverter = orig_var_impl.inconverter
                var_impl.outconverter = orig_var_impl.outconverter
                var_impl.values = [None] * num_elements
            try:
                var_impl.set_value(pos, value)
                if var_impl is not orig_var_impl:
                    bind_vars[key] = PY_TYPE_VAR._from_impl(var_impl)
                    bind_var_impls[key] = var_impl
                return 0
            except TypeError:
                if pos > 0:
                    raise

        # if an input type handler is specified, call it; the input type
        # handler should return a variable or None; the value None implies that
        # the default processing should take place just as if no input type
        # handler was defined
        if type_handler is not None:
            var = type_handler(cursor, value, num_elements)
            if var is not None:
                if not isinstance(var, Var):
                    message = "expecting variable from input type handler"
                    raise TypeError(message)
                var_impl = var._impl
                var_impl.set_value(pos, value)
                bind_vars[key] = var
                bind_var_impls[key] = var_impl
                return 0

        # finally, create a new variable deriving type information from the
        # value that is being set
        var_impl = self._create_var_impl_from_value(value, num_elements)
        var_impl.set_value(pos, value)
        typ = value.type if isinstance(value, PY_TYPE_DB_OBJECT) \
                else var_impl.dbtype
        bind_vars[key] = PY_TYPE_VAR._from_impl(var_impl, typ)
        bind_var_impls[key] = var_impl

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cdef int _bind_value_by_name(self,
                                 object cursor,
                                 object type_handler,
                                 dict params,
                                 uint32_t num_elements,
                                 uint32_t pos) except -1:
        """
        Internal method used for binding values by name.
        """
        cdef:
            dict bind_vars, bind_var_impls
        if self.bind_vars is None:
            self.bind_vars = {}
            self.bind_var_impls = {}
        bind_vars = self.bind_vars
        bind_var_impls = self.bind_var_impls
        type_handler = self._get_input_type_handler()
        for name, value in params.items():
            self._bind_value(cursor, type_handler, bind_vars, bind_var_impls,
                             name, value, num_elements, pos)

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cdef int _bind_value_by_position(self,
                                     object cursor,
                                     object type_handler,
                                     object params,
                                     uint32_t num_elements,
                                     uint32_t pos) except -1:
        """
        Internal method used for binding values by position.
        """
        cdef:
            list bind_vars, bind_var_impls, empty_values
            Py_ssize_t i, num_params, orig_num_params
        num_params = len(params)
        if self.bind_vars is not None:
            bind_vars = self.bind_vars
            bind_var_impls = self.bind_var_impls
            orig_num_params = len(bind_vars)
        else:
            bind_vars = self.bind_vars = []
            bind_var_impls = self.bind_var_impls = []
            orig_num_params = 0
        if num_params > orig_num_params:
            empty_values = [None] * (num_params - orig_num_params)
            bind_vars.extend(empty_values)
            bind_var_impls.extend(empty_values)
        for i, value in enumerate(params):
            self._bind_value(cursor, type_handler, bind_vars, bind_var_impls,
                             i, value, num_elements, pos)

    cdef int _close(self, bint in_del) except -1:
        """
        Internal method for closing the cursor.
        """
        raise NotImplementedError()

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cdef int _create_fetch_var(self, object cursor, object type_handler,
                               ssize_t pos, FetchInfo fetch_info) except -1:
        """
        Create the fetch variable for the given position and fetch information.
        The output type handler is consulted, if present, to make any necessary
        adjustments.
        """
        cdef:
            BaseVarImpl var_impl
            object var

        # if an output type handler is specified, call it; the output type
        # handler should return a variable or None; the value None implies that
        # the default processing should take place just as if no output type
        # handler was defined
        if type_handler is not None:
            var = type_handler(cursor, fetch_info._name, fetch_info._dbtype,
                               fetch_info._size, fetch_info._precision,
                               fetch_info._scale)
            if var is not None:
                self._verify_var(var)
                var_impl = var._impl
                var_impl._fetch_info = fetch_info
                self.fetch_vars[pos] = var
                self.fetch_var_impls[pos] = var_impl
                return 0

        # otherwise, create a new variable using the provided fetch information
        var_impl = self._create_var_impl()
        var_impl.num_elements = self._fetch_array_size
        var_impl.dbtype = fetch_info._dbtype
        var_impl.objtype = fetch_info._objtype
        var_impl.name = fetch_info._name
        var_impl.size = fetch_info._size
        var_impl.precision = fetch_info._precision
        var_impl.scale = fetch_info._scale
        var_impl.nulls_allowed = fetch_info._nulls_allowed
        var_impl._fetch_info = fetch_info

        # adjust the variable based on the defaults specified by the user, if
        # applicable
        if defaults.fetch_decimals and var_impl.dbtype is DB_TYPE_NUMBER:
            var_impl._preferred_num_type = NUM_TYPE_DECIMAL
        elif not defaults.fetch_lobs:
            if var_impl.dbtype is DB_TYPE_BLOB:
                var_impl.dbtype = DB_TYPE_LONG_RAW
            elif var_impl.dbtype is DB_TYPE_CLOB:
                var_impl.dbtype = DB_TYPE_LONG
            elif var_impl.dbtype is DB_TYPE_NCLOB:
                var_impl.dbtype = DB_TYPE_LONG_NVARCHAR
        elif var_impl.dbtype is DB_TYPE_NUMBER:
            if var_impl.scale == 0 \
                    or (var_impl.scale == -127 and var_impl.precision == 0):
                var_impl._preferred_num_type = NUM_TYPE_INT

        # finalize variable and store in arrays
        var_impl._finalize_init()
        self.fetch_var_impls[pos] = var_impl
        self.fetch_vars[pos] = PY_TYPE_VAR._from_impl(var_impl)

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
        num_vars = cpython.PyList_GET_SIZE(self.fetch_var_impls)
        row = cpython.PyTuple_New(num_vars)
        for i in range(num_vars):
            var_impl = self.fetch_var_impls[i]
            value = var_impl.values[self._buffer_index]
            cpython.Py_INCREF(value)
            cpython.PyTuple_SET_ITEM(row, i, value)
        if self.rowfactory is not None:
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

    cdef BaseVarImpl _create_var_impl_from_type(self, object value):
        """
        Internal method for creating a variable that can contain data of the
        specified type.
        """
        cdef BaseVarImpl var_impl
        var_impl = self._create_var_impl()
        var_impl.num_elements = 1
        if isinstance(value, list):
            if len(value) != 2:
                errors._raise_err(errors.ERR_WRONG_ARRAY_DEFINITION)
            var_impl._set_type_info_from_type(value[0])
            var_impl.num_elements = value[1]
            var_impl.is_array = True
        elif isinstance(value, int):
            var_impl.dbtype = DB_TYPE_VARCHAR
            var_impl.size = value
        else:
            var_impl._set_type_info_from_type(value)
        var_impl._finalize_init()
        return var_impl

    cdef BaseVarImpl _create_var_impl_from_value(self,
                                                 object value,
                                                 uint32_t num_elements):
        """
        Internal method for creating a variable that can contain the specified
        value.
        """
        cdef:
            bint is_plsql = self._is_plsql()
            BaseVarImpl var_impl
        var_impl = self._create_var_impl()
        if not isinstance(value, list):
            var_impl.num_elements = num_elements
            var_impl._set_type_info_from_value(value, is_plsql)
        else:
            var_impl.is_array = True
            var_impl.num_elements = max(num_elements, len(value))
            for element in value:
                if element is not None:
                    var_impl._set_type_info_from_value(element, is_plsql)
            if var_impl.dbtype is None:
                var_impl.dbtype = DB_TYPE_VARCHAR
                var_impl.size = 1
        var_impl._finalize_init()
        return var_impl

    cdef int _fetch_rows(self, object cursor) except -1:
        """
        Internal method used for fetching rows from a cursor.
        """
        raise NotImplementedError()

    cdef BaseConnImpl _get_conn_impl(self):
        """
        Internal method used to return the connection implementation associated
        with the cursor implementation.
        """
        raise NotImplementedError()

    cdef object _get_input_type_handler(self):
        """
        Return the input type handler to use for the cursor. If one is not
        directly defined on the cursor then the one defined on the connection
        is used instead.
        """
        cdef BaseConnImpl conn_impl
        if self.inputtypehandler is not None:
            return self.inputtypehandler
        conn_impl = self._get_conn_impl()
        return conn_impl.inputtypehandler

    @utils.CheckImpls("getting a cursor OCI attribute")
    def _get_oci_attr(self, uint32_t attr_num, uint32_t attr_type):
        pass

    cdef object _get_output_type_handler(self):
        """
        Return the output type handler to use for the cursor. If one is not
        directly defined on the cursor then the one defined on the connection
        is used instead.
        """
        cdef BaseConnImpl conn_impl
        if self.outputtypehandler is not None:
            return self.outputtypehandler
        conn_impl = self._get_conn_impl()
        return conn_impl.outputtypehandler

    cdef int _init_fetch_vars(self, uint32_t num_columns) except -1:
        """
        Initializes the fetch variable lists in preparation for creating the
        fetch variables used in fetching rows from the database.
        """
        self.fetch_vars = [None] * num_columns
        self.fetch_var_impls = [None] * num_columns

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
            object key
        if isinstance(self.bind_var_impls, dict):
            for key, var_impl in self.bind_var_impls.items():
                var_impl._bind(conn, self, num_execs, key, 0)
        else:
            for pos, var_impl in enumerate(self.bind_var_impls):
                var_impl._bind(conn, self, num_execs, None, pos + 1)

    @utils.CheckImpls("setting a cursor OCI attribute")
    def _set_oci_attr(self, uint32_t attr_num, uint32_t attr_type,
                      object value):
        pass

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
            bint has_pos_bind = False, has_name_bind = False
            object params_row, value
            ssize_t i, num_rows
        type_handler = self._get_input_type_handler()
        num_rows = len(parameters)
        for i, params_row in enumerate(parameters):
            if isinstance(params_row, dict):
                has_name_bind = True
                if has_pos_bind:
                    break
                self._bind_value_by_name(cursor, type_handler,
                                         <dict> params_row, num_rows, i)
            elif isinstance(params_row, (list, tuple)):
                has_pos_bind = True
                if has_name_bind:
                    break
                self._bind_value_by_position(cursor, type_handler, params_row,
                                             num_rows, i)
            else:
                errors._raise_err(errors.ERR_WRONG_EXECUTEMANY_PARAMETERS_TYPE)
        if has_pos_bind and has_name_bind:
            errors._raise_err(errors.ERR_MIXED_POSITIONAL_AND_NAMED_BINDS)

    def bind_one(self, cursor, parameters):
        """
        Internal method used for binding a single row of data.
        """
        cdef uint32_t num_rows = 1, pos = 0
        type_handler = self._get_input_type_handler()
        if isinstance(parameters, dict):
            self._bind_value_by_name(cursor, type_handler, <dict> parameters,
                                     num_rows, pos)
        else:
            self._bind_value_by_position(cursor, type_handler, parameters,
                                         num_rows, pos)

    def close(self, bint in_del=False):
        """
        Closes the cursor and makes it unusable for further operations.
        """
        self.bind_vars = None
        self.bind_var_impls = None
        self.fetch_vars = None
        self._close(in_del)

    def create_var(self, object typ, uint32_t size=0,
                   uint32_t num_elements=1, object inconverter=None,
                   object outconverter=None, str encoding_errors=None,
                   bint bypass_decode=False, bint is_array=False):
        cdef BaseVarImpl var_impl
        var_impl = self._create_var_impl()
        var_impl._set_type_info_from_type(typ)
        var_impl.size = size
        var_impl.num_elements = num_elements
        var_impl.inconverter = inconverter
        var_impl.outconverter = outconverter
        var_impl.bypass_decode = bypass_decode
        var_impl.is_array = is_array
        var_impl._finalize_init()
        return PY_TYPE_VAR._from_impl(var_impl)

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

    @utils.CheckImpls("scrolling a scrollable cursor")
    def scroll(self, conn, value, mode):
        """
        Scrolls a scrollable cursor.
        """
        pass

    def setinputsizes(self, cursor, args, kwargs):
        """
        Sets type information for bind variables in advance of executing a
        statement (and binding values).
        """
        if kwargs:
            self._bind_type_by_name(kwargs)
        else:
            self._bind_type_by_position(args)
