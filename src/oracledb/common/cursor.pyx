#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

from .. import constants

cdef class BaseCursor:

    def __cinit__(self, connection):
        self.arraysize = 100
        self.prefetchrows = 2
        self._is_open = True

    def __iter__(self):
        return self

    def __next__(self):
        self._verify_fetch()
        row = self._fetch_next_row()
        if row is not None:
            return row
        raise StopIteration

    cdef BaseVar _create_var(self):
        """
        Internal method for creating a variable. Intended to be overridden by
        the subclass.
        """

    cdef int _execute(self) except -1:
        """
        Internal method used for executing a statement. This is intended to be
        overridden by the subclass.
        """

    cdef object _fetch_next_row(self):
        """
        Internal method used for fetching the next row from a cursor. This is
        intended to be overridden by the subclass.
        """
        print("base class fetch next row...")

    cdef int _prepare(self, str statement, str tag=None) except -1:
        """
        Internal method used for preparing a statement for execution. This is
        intended to be overridden by the subclass.
        """

    cdef int _verify_fetch(self) except -1:
        """
        Verifies that fetching is possible from this cursor.
        """
        self._verify_open()
        if not self._fetch_vars:
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

    def fetchall(self):
        """
        Fetches all of the remaining rows available from the cursor and returns
        them as a list.
        """
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

    def var(self, typ, size=0, arraysize=1, inconverter=None,
            outconverter=None, typename=None, encoding_errors=None):
        cdef:
            DbType dbtype
            BaseVar var
        dbtype = DbType._from_type(typ)
        var = self._create_var()
        var.type = dbtype
        var.num_elements = arraysize
        var.inconverter = inconverter
        var.outconverter = outconverter
        var._finalize_init()
        return var
