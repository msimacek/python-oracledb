#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class BasePool:

    def __init__(self, user, dsn, min, max, increment, homogeneous):
        self.username = user
        self.dsn = dsn
        self.min = min
        self.max = max
        self.increment = increment
        self.homogeneous = homogeneous

    cdef BaseConnection _acquire(self, str user, str password, str cclass,
                                 uint32_t purity, str tag, bint match_any_tag,
                                 list sharding_key, list super_sharding_key):
        """
        Internal method for acquiring a connection from the pool.
        """
        raise NotImplementedError()

    cdef int _close(self, bint force) except -1:
        """
        Internal method for closing the pool.
        """
        raise NotImplementedError()

    cdef int _drop(self, BaseConnection connection) except -1:
        """
        Internal method for dropping a connection from the pool.
        """
        raise NotImplementedError()

    cdef int _get_busy_count(self, uint32_t *value) except -1:
        """
        Internal method for getting the number of busy connections in the pool.
        """
        raise NotImplementedError()

    cdef int _get_max_lifetime_session(self, uint32_t *value) except -1:
        """
        Internal method for getting the maximum lifetime of each session.
        """
        raise NotImplementedError()

    cdef int _get_open_count(self, uint32_t *value) except -1:
        """
        Internal method for getting the number of connections in the pool.
        """
        raise NotImplementedError()

    cdef int _get_stmt_cache_size(self, uint32_t *value) except -1:
        """
        Internal method for getting the size of the statement cache.
        """
        raise NotImplementedError()

    cdef int _get_timeout(self, uint32_t *value) except -1:
        """
        Internal method for getting the timeout for idle sessions.
        """
        raise NotImplementedError()

    cdef int _get_wait_timeout(self, uint32_t *value) except -1:
        """
        Internal method for getting the wait timeout for acquiring sessions.
        """
        raise NotImplementedError()

    cdef int _release(self, BaseConnection connection, str tag) except -1:
        """
        Internal method for releasing a connection from the pool.
        """
        raise NotImplementedError()

    cdef int _set_max_lifetime_session(self, uint32_t value) except -1:
        """
        Internal method for setting the maximum lifetime of each session.
        """
        raise NotImplementedError()

    cdef int _set_stmt_cache_size(self, uint32_t value) except -1:
        """
        Internal method for setting the size of the statement cache.
        """
        raise NotImplementedError()

    cdef int _set_timeout(self, uint32_t value) except -1:
        """
        Internal method for setting the timeout for idle sessions.
        """
        raise NotImplementedError()

    cdef int _set_wait_timeout(self, uint32_t value) except -1:
        """
        Internal method for setting the wait timeout for acquiring sessions.
        """
        raise NotImplementedError()

    def acquire(self, user=None, password=None, cclass=None,
                purity=constants.PURITY_DEFAULT, tag=None, matchanytag=False,
                shardingkey=[], supershardingkey=[]):
        """
        Acquire a connection from the pool and return it.
        """
        return self._acquire(user=user, password=password, cclass=cclass,
                             purity=purity, tag=tag, match_any_tag=matchanytag,
                             sharding_key=shardingkey,
                             super_sharding_key=supershardingkey)

    @property
    def busy(self):
        cdef uint32_t value
        self._get_busy_count(&value)
        return value

    def close(self, force=False):
        self._close(force)

    def drop(self, connection):
        self._drop(connection)

    @property
    def max_lifetime_session(self):
        cdef uint32_t value
        self._get_max_lifetime_session(&value)
        return value

    @max_lifetime_session.setter
    def max_lifetime_session(self, value):
        self._set_max_lifetime_session(value)

    @property
    def opened(self):
        cdef uint32_t value
        self._get_open_count(&value)
        return value

    def release(self, connection, tag=None):
        self._release(connection, tag)

    @property
    def stmtcachesize(self):
        cdef uint32_t value
        self._get_stmt_cache_size(&value)
        return value

    @stmtcachesize.setter
    def stmtcachesize(self, value):
        self._set_stmt_cache_size(value)

    @property
    def timeout(self):
        cdef uint32_t value
        self._get_timeout(&value)
        return value

    @timeout.setter
    def timeout(self, value):
        self._set_timeout(value)

    @property
    def wait_timeout(self):
        cdef uint32_t value
        self._get_wait_timeout(&value)
        return value

    @wait_timeout.setter
    def wait_timeout(self, value):
        self._set_wait_timeout(value)
