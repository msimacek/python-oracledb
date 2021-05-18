#------------------------------------------------------------------------------
# Copyright (c) 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

from . import errors, exceptions

class Cursor:

    def __init__(self, connection, scrollable=False):
        self._impl = None
        self.connection = connection
        self.statement = None
        self._set_input_sizes = False
        self._impl = connection._impl.create_cursor_impl()
        self._impl.scrollable = scrollable

    def __del__(self):
        if self._impl is not None:
            self._impl.close()

    def __enter__(self):
        self._verify_open()
        return self

    def __exit__(self, exc_type, exc_value, exc_tb):
        self.close()

    def __iter__(self):
        return self

    def __next__(self):
        self._verify_fetch()
        row = self._impl.fetch_next_row(self)
        if row is not None:
            return row
        raise StopIteration

    def __repr__(self):
        return f"<oracledb.Cursor on {self.connection!r}>"

    def _call(self, name, parameters, keyword_parameters, return_value=None):
        """
        Internal method used for generating the PL/SQL block used to call
        stored procedures.
        """

        # verify parameters
        if parameters is not None \
                and not isinstance(parameters, (list, tuple)):
            raise TypeError("arguments must be a list or tuple")
        if keyword_parameters is not None \
                and not isinstance(keyword_parameters, dict):
            raise TypeError("keyword arguments must be a dict")
        self._verify_open()

        # build and execute statement
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

    def _prepare(self, statement):
        """
        Internal method used for preparing a statement for execution.
        """
        self._impl.fetch_vars = None
        if not self._set_input_sizes:
            self._impl.bind_vars = None
        self._impl.prepare(statement)
        self.statement = statement

    def _verify_fetch(self):
        """
        Verifies that fetching is possible from this cursor.
        """
        self._verify_open()
        if not self._impl.is_query(self):
            errors._raise_from_string(exceptions.InterfaceError, "not a query")

    def _verify_open(self):
        """
        Verifies that the cursor is open and the associated connection is
        connected. If either condition is false an exception is raised.
        """
        if self._impl is None:
            errors._raise_from_string(exceptions.InterfaceError, "not open")
        self.connection._verify_connected()

    @property
    def arraysize(self):
        """
        Tunes the number of rows fetched and buffered by internal calls to the
        database when fetching rows from SELECT statements and REF CURSORS. The
        value can drastically affect the performance of a query since it
        directly affects the number of network round trips between Python and
        the database. For methods like fetchone() and fetchall() it does not
        change how many rows are returned to the application. For fetchmany()
        it is the default number of rows to fetch.

        Due to the performance benefits, the default value is 100 instead of
        the 1 that the DB API recommends. This value means that 100 rows are
        fetched by each internal call to the database.
        """
        self._verify_open()
        return self._impl.arraysize

    @arraysize.setter
    def arraysize(self, value):
        self._verify_open()
        self._impl.arraysize = value

    def arrayvar(self, typ, value, size=0):
        """
        Create an array variable associated with the cursor of the given type
        and size and return a variable object. The value is either an integer
        specifying the number of elements to allocate or it is a list and the
        number of elements allocated is drawn from the size of the list. If the
        value is a list, the variable is also set with the contents of the
        list. If the size is not specified and the type is a string or binary,
        4000 bytes is allocated. This is needed for passing arrays to PL/SQL
        (in cases where the list might be empty and the type cannot be
        determined automatically) or returning arrays from PL/SQL.

        Array variables can only be used for PL/SQL associative arrays with
        contiguous keys. For PL/SQL associative arrays with sparsely populated
        keys or for varrays and nested tables, the DbObject approach needs to
        be used instead.
        """
        self._verify_open()
        if isinstance(value, list):
            num_elements = len(value)
        elif isinstance(value, int):
            num_elements = value
        else:
            raise TypeError("expecting integer or list of values")
        var = self._impl.create_var(self.connection, typ, size=size,
                                    num_elements=num_elements, is_array=True)
        if isinstance(value, list):
            var.setvalue(0, value)
        return var

    def bindnames(self):
        """
        Return the list of bind variable names bound to the statement. Note
        that a statement must have been prepared first.
        """
        self._verify_open()
        if self.statement is None:
            message = "statement must be prepared first"
            errors._raise_from_string(exceptions.ProgrammingError, message)
        return self._impl.get_bind_names()

    @property
    def bindvars(self):
        """
        Returns the bind variables used for the last execute. The value will be
        either a list or a dictionary depending on whether binding was done by
        position or name. Care should be taken when referencing this attribute.
        In particular, elements should not be removed or replaced.
        """
        self._verify_open()
        return self._impl.bind_vars or []

    def callfunc(self, name, return_type, parameters=None,
                 keyword_parameters=None, *, keywordParameters=None):
        """
        Call a function with the given name. The return type is specified in
        the same notation as is required by setinputsizes(). The sequence of
        parameters must contain one entry for each parameter that the function
        expects. Any keyword parameters will be included after the positional
        parameters. The result of the call is the return value of the function.
        """
        var = self.var(return_type)
        if keywordParameters is not None:
            if keyword_parameters is not None:
                message = "keywordParameters and keyword_parameters cannot " \
                          "both be specified"
                raise exceptions.ProgrammingError(message)
            keyword_parameters = keywordParameters
        self._call(name, parameters, keyword_parameters, var)
        return var.getvalue()

    def callproc(self, name, parameters=None, keyword_parameters=None, *,
                 keywordParameters=None):
        """
        Call a procedure with the given name. The sequence of parameters must
        contain one entry for each parameter that the procedure expects. The
        result of the call is a modified copy of the input sequence. Input
        parameters are left untouched; output and input/output parameters are
        replaced with possibly new values. Keyword parameters will be included
        after the positional parameters and are not returned as part of the
        output sequence.
        """
        if keywordParameters is not None:
            if keyword_parameters is not None:
                message = "keywordParameters and keyword_parameters cannot " \
                          "both be specified"
                raise exceptions.ProgrammingError(message)
            keyword_parameters = keywordParameters
        self._call(name, parameters, keyword_parameters)
        if parameters is None:
            return []
        return [v.getvalue() for v in self._impl.bind_vars[:len(parameters)]]

    def close(self):
        """
        Close the cursor now, rather than whenever __del__ is called. The
        cursor will be unusable from this point forward; an Error exception
        will be raised if any operation is attempted with the cursor.
        """
        self._verify_open()
        self._impl.close()
        self._impl = None

    @property
    def description(self):
        """
        Returns a sequence of 7-item sequences. Each of these sequences
        contains information describing one result column: (name, type,
        display_size, internal_size, precision, scale, null_ok).  This
        attribute will be None for operations that do not return rows or if the
        cursor has not had an operation invoked via the execute() method yet.
        """
        self._verify_open()
        if self._impl.is_query(self):
            return self._impl.get_description()

    def execute(self, statement, parameters=None, **keyword_parameters):
        """
        Execute a statement against the database.

        Parameters may be passed as a dictionary or sequence or as keyword
        parameters. If the parameters are a dictionary, the values will be
        bound by name and if the parameters are a sequence the values will be
        bound by position. Note that if the values are bound by position, the
        order of the variables is from left to right as they are encountered in
        the statement and SQL statements are processed differently than PL/SQL
        statements. For this reason, it is generally recommended to bind
        parameters by name instead of by position.

        Parameters passed as a dictionary are name and value pairs. The name
        maps to the bind variable name used by the statement and the value maps
        to the Python value you wish bound to that bind variable.

        A reference to the statement will be retained by the cursor. If None or
        the same string object is passed in again, the cursor will execute that
        statement again without performing a prepare or rebinding and
        redefining. This is most effective for algorithms where the same
        statement is used, but different parameters are bound to it (many
        times). Note that parameters that are not passed in during subsequent
        executions will retain the value passed in during the last execution
        that contained them.

        For maximum efficiency when reusing an statement, it is best to use the
        setinputsizes() method to specify the parameter types and sizes ahead
        of time; in particular, None is assumed to be a string of length 1 so
        any values that are later bound as numbers or dates will raise a
        TypeError exception.

        If the statement is a query, the cursor is returned as a convenience to
        the caller (so it can be used directly as an iterator over the rows in
        the cursor); otherwise, None is returned.
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
        self._verify_open()
        bind_vars = self._impl.bind_vars
        prepare_needed = statement and statement != self.statement
        if not (prepare_needed and not self._set_input_sizes) \
                and bind_vars is not None and parameters is not None:
            if isinstance(bind_vars, dict) \
                    and not isinstance(parameters, dict) \
                    or isinstance(bind_vars, list) \
                    and isinstance(parameters, dict):
                message = "positional and named binds cannot be intermixed"
                errors._raise_from_string(exceptions.ProgrammingError, message)

        # prepare statement, if necessary
        if prepare_needed:
            self._prepare(statement)

        # perform bind and execute
        self._set_input_sizes = False
        if parameters is not None:
            self._impl.bind_one(self, parameters)
        self._impl.execute(self)
        if self._impl.fetch_vars is not None:
            return self

    def executemany(self, statement, parameters, batcherrors=False,
                    arraydmlrowcounts=False):
        """
        Prepare a statement for execution against a database and then execute
        it against all parameter mappings or sequences found in the sequence
        parameters.

        The statement is managed in the same way as the execute() method
        manages it. If the size of the buffers allocated for any of the
        parameters exceeds 2 GB and you are using the thick implementation, you
        will receive the error “DPI-1015: array size of <n> is too large”,
        where <n> varies with the size of each element being allocated in the
        buffer. If you receive this error, decrease the number of elements in
        the sequence parameters.

        If there are no parameters, or parameters have previously been bound,
        the number of iterations can be specified as an integer instead of
        needing to provide a list of empty mappings or sequences.

        When true, the batcherrors parameter enables batch error support within
        Oracle and ensures that the call succeeds even if an exception takes
        place in one or more of the sequence of parameters. The errors can then
        be retrieved using getbatcherrors().

        When true, the arraydmlrowcounts parameter enables DML row counts to be
        retrieved from Oracle after the method has completed. The row counts
        can then be retrieved using getarraydmlrowcounts().

        Both the batcherrors parameter and the arraydmlrowcounts parameter can
        only be true when executing an insert, update, delete or merge
        statement; in all other cases an error will be raised.

        For maximum efficiency, it is best to use the setinputsizes() method to
        specify the parameter types and sizes ahead of time; in particular,
        None is assumed to be a string of length 1 so any values that are later
        bound as numbers or dates will raise a TypeError exception.
        """
        # verify parameters
        if statement is None and self.statement is None:
            message = "no statement specified and no prior statement prepared"
            errors._raise_from_string(exceptions.ProgrammingError, message)
        if not isinstance(parameters, (list, int)):
            message = "parameters should be a list of sequences or " \
                      "dictionaries, or an integer specifying the number of " \
                      "times to execute the statement"
            errors._raise_from_string(TypeError, message)

        # prepare statement, if necessary
        self._verify_open()
        if statement and statement != self.statement:
            self._prepare(statement)

        # perform bind and execute
        self._set_input_sizes = False
        if isinstance(parameters, int):
            num_execs = parameters
        else:
            num_execs = len(parameters)
            self._impl.bind_many(self, parameters)
        self._impl.executemany(self, num_execs, bool(batcherrors),
                               bool(arraydmlrowcounts))

    def fetchall(self):
        """
        Fetch all (remaining) rows of a query result, returning them as a list
        of tuples. An empty list is returned if no more rows are available.
        Note that the cursor’s arraysize attribute can affect the performance
        of this operation, as internally reads from the database are done in
        batches corresponding to the arraysize.

        An exception is raised if the previous call to execute() did not
        produce any result set or no call was issued yet.
        """
        self._verify_fetch()
        result = []
        fetch_next_row = self._impl.fetch_next_row
        while True:
            row = fetch_next_row(self)
            if row is None:
                break
            result.append(row)
        return result

    def fetchmany(self, size=None):
        """
        Fetch the next set of rows of a query result, returning a list of
        tuples. An empty list is returned if no more rows are available. Note
        that the cursor’s arraysize attribute can affect the performance of
        this operation.

        The number of rows to fetch is specified by the parameter. If it is not
        given, the cursor’s arraysize attribute determines the number of rows
        to be fetched. If the number of rows available to be fetched is fewer
        than the amount requested, fewer rows will be returned.

        An exception is raised if the previous call to execute() did not
        produce any result set or no call was issued yet.
        """
        self._verify_fetch()
        if size is None:
            size = self._impl.arraysize
        result = []
        fetch_next_row = self._impl.fetch_next_row
        while len(result) < size:
            row = fetch_next_row(self)
            if row is None:
                break
            result.append(row)
        return result

    def fetchone(self):
        """
        Fetch the next row of a query result set, returning a single tuple or
        None when no more data is available.

        An exception is raised if the previous call to execute() did not
        produce any result set or no call was issued yet.
        """
        self._verify_fetch()
        return self._impl.fetch_next_row(self)

    @property
    def fetchvars(self):
        """
        Specifies the list of variables created for the last query that was
        executed on the cursor. Care should be taken when referencing this
        attribute. In particular, elements should not be removed or replaced.
        """
        self._verify_open()
        return self._impl.fetch_vars

    def getarraydmlrowcounts(self):
        """
        Return the DML row counts after a call to executemany() with
        arraydmlrowcounts enabled. This will return a list of integers
        corresponding to the number of rows affected by the DML statement for
        each element of the array passed to executemany().
        """
        self._verify_open()
        return self._impl.get_array_dml_row_counts()

    def getbatcherrors(self):
        """
        Return the exceptions that took place after a call to executemany()
        with batcherrors enabled. This will return a list of Error objects, one
        error for each iteration that failed. The offset can be determined by
        looking at the offset attribute of the error object.
        """
        self._verify_open()
        return self._impl.get_batch_errors()

    def getimplicitresults(self):
        """
        Return a list of cursors which correspond to implicit results made
        available from a PL/SQL block or procedure without the use of OUT ref
        cursor parameters. The PL/SQL block or procedure opens the cursors and
        marks them for return to the client using the procedure
        dbms_sql.return_result. Cursors returned in this fashion should not be
        closed. They will be closed automatically by the parent cursor when it
        is closed. Closing the parent cursor will invalidate the cursors
        returned by this method.
        """
        self._verify_open()
        return self._impl.get_implicit_results(self.connection)

    @property
    def inputtypehandler(self):
        """
        Specifies a method called for each value that is bound to a statement
        executed on this cursor. The method signature is handler(cursor, value,
        arraysize) and the return value is expected to be a variable object or
        None in which case a default variable object will be created. If this
        attribute is None, the default behavior will take place for all values
        bound to statements.
        """
        self._verify_open()
        return self._impl.inputtypehandler

    @inputtypehandler.setter
    def inputtypehandler(self, value):
        self._verify_open()
        self._impl.inputtypehandler = value

    @property
    def lastrowid(self):
        """
        Returns the rowid of the last row modified by the cursor. If no row was
        modified by the last operation performed on the cursor, the value None
        is returned.
        """
        self._verify_open()
        return self._impl.get_lastrowid()

    @property
    def outputtypehandler(self):
        """
        Specifies a method called for each column that is going to be fetched
        from this cursor. The method signature is handler(cursor, name,
        defaultType, length, precision, scale) and the return value is expected
        to be a variable object or None in which case a default variable object
        will be created. If this attribute is None, the default behavior will
        take place for all columns fetched from this cursor.
        """
        self._verify_open()
        return self._impl.outputtypehandler

    @outputtypehandler.setter
    def outputtypehandler(self, value):
        self._verify_open()
        self._impl.outputtypehandler = value

    def parse(self, statement):
        """
        This can be used to parse a statement without actually executing it
        (this step is done automatically by Oracle when a statement is
        executed).
        """
        self._verify_open()
        self._prepare(statement)
        self._impl.parse(self)

    @property
    def prefetchrows(self):
        """
        Used to tune the number of rows fetched when a SELECT statement is
        executed. This value can reduce the number of round-trips to the
        database that are required to fetch rows but at the cost of additional
        memory. Setting this value to 0 can be useful when the timing of
        fetches must be explicitly controlled.
        """
        self._verify_open()
        return self._impl.prefetchrows

    @prefetchrows.setter
    def prefetchrows(self, value):
        self._verify_open()
        self._impl.prefetchrows = value

    def prepare(self, statement, tag=None):
        """
        This can be used before a call to execute() to define the statement
        that will be executed. When this is done, the prepare phase will not be
        performed when the call to execute() is made with None or the same
        string object as the statement. If specified the statement will be
        returned to the statement cache with the given tag. See the Oracle
        documentation for more information about the statement cache.
        """
        self._verify_open()
        self._prepare(statement)

    @property
    def rowcount(self):
        """
        This read-only attribute specifies the number of rows that have
        currently been fetched from the cursor (for select statements), that
        have been affected by the operation (for insert, update, delete and
        merge statements), or the number of successful executions of the
        statement (for PL/SQL statements).
        """
        self._verify_open()
        return self._impl.rowcount

    @property
    def rowfactory(self):
        """
        Specifies a method to call for each row that is retrieved from the
        database.  Ordinarily a tuple is returned for each row but if this
        attribute is set, the method is called with the tuple that would
        normally be returned, and the result of the method is returned instead.
        """
        self._verify_open()
        return self._impl.rowfactory

    @rowfactory.setter
    def rowfactory(self, value):
        self._verify_open()
        self._impl.rowfactory = value

    def scroll(self, value=0, mode="relative"):
        """
        Scroll the cursor in the result set to a new position according to the
        mode.

        If mode is “relative” (the default value), the value is taken as an
        offset to the current position in the result set. If set to “absolute”,
        value states an absolute target position. If set to “first”, the cursor
        is positioned at the first row and if set to “last”, the cursor is set
        to the last row in the result set.

        An error is raised if the mode is “relative” or “absolute” and the
        scroll operation would position the cursor outside of the result set.
        """
        self._verify_open()
        self._impl.scroll(value, mode)

    @property
    def scrollable(self):
        """
        Specifies whether the cursor can be scrolled or not. By default,
        cursors are not scrollable, as the server resources and response times
        are greater than for nonscrollable cursors. This attribute is checked
        and the corresponding mode set in Oracle when calling the method
        execute().
        """
        self._verify_open()
        return self._impl.scrollable

    @scrollable.setter
    def scrollable(self, value):
        self._verify_open()
        self._impl.scrollable = value

    def setinputsizes(self, *args, **kwargs):
        """
        This can be used before a call to execute(), callfunc() or callproc()
        to predefine memory areas for the operation’s parameters. Each
        parameter should be a type object corresponding to the input that will
        be used or it should be an integer specifying the maximum length of a
        string parameter. Use keyword parameters when binding by name and
        positional parameters when binding by position. The singleton None can
        be used as a parameter when using positional parameters to indicate
        that no space should be reserved for that position.
        """
        if args and kwargs:
            message = "expecting arguments or keyword arguments, not both"
            errors._raise_from_string(exceptions.InterfaceError, message)
        elif args or kwargs:
            self._verify_open()
            self._impl.setinputsizes(self, args, kwargs)
            self._set_input_sizes = True
            return self._impl.bind_vars
        return []

    def setoutputsize(self, size, column=0):
        """
        Sets a column buffer size for fetches of long columns but the driver
        does not require it so nothing is done here.
        """
        pass

    def var(self, typ, size=0, arraysize=1, inconverter=None,
            outconverter=None, typename=None, encoding_errors=None, *,
            encodingErrors=None):
        """
        Create a variable with the specified characteristics. This method was
        designed for use with PL/SQL in/out variables where the length or type
        cannot be determined automatically from the Python object passed in or
        for use in input and output type handlers defined on cursors or
        connections.

        The dataType parameter specifies the type of data that should be stored
        in the variable. This should be one of the database type constants, DB
        API constants, an object type returned from the method
        Connection.gettype() or one of the following Python types:

            Python Type	        Database Type
            bool	            DB_TYPE_BOOLEAN
            bytes	            DB_TYPE_RAW
            datetime.date	    DB_TYPE_DATE
            datetime.datetime	DB_TYPE_DATE
            datetime.timedelta	DB_TYPE_INTERVAL_DS
            decimal.Decimal	    DB_TYPE_NUMBER
            float	            DB_TYPE_NUMBER
            int             	DB_TYPE_NUMBER
            str                 DB_TYPE_VARCHAR

        The size parameter specifies the length of string and raw variables and
        is ignored in all other cases. If not specified for string and raw
        variables, the value 4000 is used.

        The arraysize parameter specifies the number of elements the variable
        will have. If not specified the bind array size (usually 1) is used.
        When a variable is created in an output type handler this parameter
        should be set to the cursor’s array size.

        The inconverter and outconverter parameters specify methods used for
        converting values to/from the database. More information can be found
        in the section on variable objects.

        The typename parameter specifies the name of a SQL object type and must
        be specified when using type DB_TYPE_OBJECT unless the type object
        was passed directly as the first parameter.

        The encoding_errors parameter specifies what should happen when
        decoding byte strings fetched from the database into strings. It should
        be one of the values noted in the builtin decode function.
        """
        self._verify_open()
        if typename is not None:
            typ = self.connection.gettype(typename)
        if encodingErrors is not None:
            if encoding_errors is not None:
                message = "encodingErrors and encoding_errors cannot both " \
                          "be specified"
                raise exceptions.ProgrammingError(message)
            encoding_errors = encodingErrors
        return self._impl.create_var(self.connection, typ, size, arraysize,
                                     inconverter, outconverter,
                                     encoding_errors)
