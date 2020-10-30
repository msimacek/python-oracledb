#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class BaseConnection:

    def __init__(self, user, dsn):
        self.username = user
        self.dsn = dsn

    def __enter__(self):
        self._verify_connected()
        return self

    def __exit__(self, exc_type, exc_value, exc_tb):
        self.close()

    def __repr__(self):
        cls_name = type(self).__name__
        if self.username is None:
            return f"<oracledb.{cls_name} to externally identified user>"
        return f"<oracledb.{cls_name} to {self.username}@{self.dsn}>"


    cdef int _begin(self, long format_id, str transaction_id,
                    str branch_id) except -1:
        """
        Internal method for beginning a distributed transaction.
        """
        raise NotImplementedError()

    cdef int _cancel(self) except -1:
        """
        Internal method for breaking execution of any currently executing
        statement.
        """
        raise NotImplementedError()

    cdef int _change_password(self, str old_password,
                              str new_password) except -1:
        """
        Internal method for changing the password.
        """
        raise NotImplementedError()

    cdef int _close(self) except -1:
        """
        Internal method for closing the connection. Intended to be overridden
        by the subclass.
        """
        raise NotImplementedError()

    cdef int _commit(self) except -1:
        """
        Internal method for committing the transaction. Intended to be
        overridden by the subclass.
        """
        raise NotImplementedError()

    cdef BaseCursor _create_cursor(self):
        """
        Internal method for creating a cursor. Intended to be overridden by the
        subclass.
        """
        raise NotImplementedError()

    cdef str _get_current_schema(self):
        """
        Internal method for returning the current schema.
        """
        raise NotImplementedError()

    cdef str _get_edition(self):
        """
        Internal method for returning the edition.
        """
        raise NotImplementedError()

    cdef str _get_external_name(self):
        """
        Internal method for returning the external name.
        """
        raise NotImplementedError()

    cdef str _get_internal_name(self):
        """
        Internal method for returning the internal name.
        """
        raise NotImplementedError()

    cdef bytes _get_ltxid(self):
        """
        Internal method for returning the logical transaction id.
        """
        raise NotImplementedError()

    cdef uint32_t _get_stmtcachesize(self) except *:
        """
        Internal method for returning the size of the statement cache.
        """
        raise NotImplementedError()

    cdef str _get_version(self):
        """
        Return the version associated with the connection. Intended to be
        overridden by the subclass.
        """
        raise NotImplementedError()

    cdef int _ping(self) except -1:
        """
        Internal method for pinging the database. Intended to be overridden by
        the subclass.
        """
        raise NotImplementedError()

    cdef bint _prepare(self) except *:
        """
        Internal method for preparing to commit a distributed transaction.
        """
        raise NotImplementedError()

    cdef int _rollback(self) except -1:
        """
        Internal method for rolling back the transaction. Intended to be
        overridden by the subclass.
        """
        raise NotImplementedError()

    cdef int _set_current_schema(self, str value) except -1:
        """
        Internal method for setting the current schema.
        """
        raise NotImplementedError()

    cdef int _set_external_name(self, str value) except -1:
        """
        Internal method for setting the external name.
        """
        raise NotImplementedError()

    cdef int _set_internal_name(self, str value) except -1:
        """
        Internal method for setting the internal name.
        """
        raise NotImplementedError()

    cdef int _set_stmtcachesize(self, uint32_t value) except -1:
        """
        Internal method for setting the size of the statement cache.
        """
        raise NotImplementedError()

    cdef int _verify_connected(self) except -1:
        """
        Verifies that the connection is connected to the database. If it is not
        an exception is raised.
        """
        if not self._is_connected:
            errors._raise_from_string(exceptions.InterfaceError,
                                      "not connected")

    def begin(self, format_id=-1, transaction_id="", branch_id=""):
        """
        Begins a distributed transaction.
        """
        self._verify_connected()
        self._begin(format_id, transaction_id, branch_id)

    def cancel(self):
        """
        Issues an immediate (asynchronous) abort of any currently executing
        statement.
        """
        self._verify_connected()
        self._cancel()

    def changepassword(self, old_password, new_password):
        """
        Changes the password for the user to which the connection is connected.
        """
        self._verify_connected()
        self._change_password(old_password, new_password)

    def close(self):
        """
        Closes the connection and makes it unusable for further operations.
        """
        self._verify_connected()
        self._close()
        self._is_connected = False

    def commit(self):
        """
        Commits any outstanding connection.
        """
        self._verify_connected()
        self._commit()

    def cursor(self):
        """
        Returns a cursor associated with the connection.
        """
        return self._create_cursor()

    @property
    def current_schema(self):
        self._verify_connected()
        return self._get_current_schema()

    @current_schema.setter
    def current_schema(self, value):
        self._verify_connected()
        self._set_current_schema(value)

    @property
    def edition(self):
        self._verify_connected()
        return self._get_edition()

    @property
    def external_name(self):
        self._verify_connected()
        return self._get_external_name()

    @external_name.setter
    def external_name(self, value):
        self._verify_connected()
        self._set_external_name(value)

    @property
    def internal_name(self):
        self._verify_connected()
        return self._get_internal_name()

    @internal_name.setter
    def internal_name(self, value):
        self._verify_connected()
        self._set_internal_name(value)

    @property
    def ltxid(self):
        self._verify_connected()
        return self._get_ltxid()

    @property
    def stmtcachesize(self):
        self._verify_connected()
        return self._get_stmtcachesize()

    @stmtcachesize.setter
    def stmtcachesize(self, value):
        self._verify_connected()
        self._set_stmtcachesize(value)

    def ping(self):
        """
        Pings the database to verify the connection is valid.
        """
        self._verify_connected()
        self._ping()

    def prepare(self):
        """
        Prepares the distributed transaction for commit. Returns a boolean
        indicating if a commit is in fact needed.
        """
        self._verify_connected()
        return self._prepare()

    def rollback(self):
        """
        Rolls back any outstanding connection.
        """
        self._verify_connected()
        self._rollback()

    @property
    def version(self):
        if self._version is None:
            self._version = self._get_version()
        return self._version
