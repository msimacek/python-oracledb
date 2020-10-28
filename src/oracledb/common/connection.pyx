#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class BaseConnection:

    def __init__(self, user, dsn):
        self.username = user
        self.dsn = dsn

    def __repr__(self):
        cls_name = type(self).__name__
        if self.username is None:
            return f"{cls_name} to externally identified user"
        return f"{cls_name} to {self.username}@{self.dsn}"

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

    cdef int _rollback(self) except -1:
        """
        Internal method for rolling back the transaction. Intended to be
        overridden by the subclass.
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

    def close(self):
        """
        Closes the connection and makes it unusable for further operations.
        """
        self._verify_connected()
        self._close()

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

    def ping(self):
        """
        Pings the database to verify the connection is valid.
        """
        self._verify_connected()
        self._ping()

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
