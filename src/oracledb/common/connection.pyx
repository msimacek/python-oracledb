#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class BaseConnection:

    def __init__(self, user, dsn):
        self.user = user
        self.dsn = dsn

    def __repr__(self):
        cls_name = type(self).__name__
        if self.user is None:
            return f"{cls_name} to externally identified user"
        return f"{cls_name} to {self.user}@{self.dsn}"

    cdef BaseCursor _create_cursor(self):
        """
        Internal method for creating a cursor. Intended to be overridden by the
        subclass.
        """

    cdef str _get_version(self):
        """
        Return the version associated with the connection. Intended to be
        overridden by the subclass.
        """

    cdef int _verify_connected(self) except -1:
        """
        Verifies that the connection is connected to the database. If it is not
        an exception is raised.
        """
        if not self._is_connected:
            errors._raise_from_string(exceptions.InterfaceError,
                                      "not connected")

    def cursor(self):
        """
        Returns a cursor associated with the connection.
        """
        return self._create_cursor()

    @property
    def version(self):
        if self._version is None:
            self._version = self._get_version()
        return self._version
