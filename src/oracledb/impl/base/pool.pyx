#------------------------------------------------------------------------------
# Copyright (c) 2020, 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class BasePoolImpl:

    def __init__(self, user, dsn, min, max, increment, homogeneous):
        self.username = user
        self.dsn = dsn
        self.min = min
        self.max = max
        self.increment = increment
        self.homogeneous = homogeneous

    def acquire(self, str user, str password, str cclass, uint32_t purity,
                str tag, bint matchanytag, list shardingkey,
                list supershardingkey):
        """
        Internal method for acquiring a connection from the pool.
        """
        raise NotImplementedError()

    def close(self, bint force):
        """
        Internal method for closing the pool.
        """
        raise NotImplementedError()

    def drop(self, conn_impl):
        """
        Internal method for dropping a connection from the pool.
        """
        raise NotImplementedError()

    def get_busy_count(self):
        """
        Internal method for getting the number of busy connections in the pool.
        """
        raise NotImplementedError()

    def get_getmode(self):
        """
        Internal method for getting the method by which connections are
        acquired from the pool.
        """
        raise NotImplementedError()

    def get_max_lifetime_session(self):
        """
        Internal method for getting the maximum lifetime of each session.
        """
        raise NotImplementedError()

    def get_open_count(self):
        """
        Internal method for getting the number of connections in the pool.
        """
        raise NotImplementedError()

    def get_stmt_cache_size(self):
        """
        Internal method for getting the size of the statement cache.
        """
        raise NotImplementedError()

    def get_timeout(self):
        """
        Internal method for getting the timeout for idle sessions.
        """
        raise NotImplementedError()

    def get_wait_timeout(self):
        """
        Internal method for getting the wait timeout for acquiring sessions.
        """
        raise NotImplementedError()

    def set_getmode(self, uint8_t value):
        """
        Internal method for setting the method by which connections are
        acquired from the pool.
        """
        raise NotImplementedError()

    def set_max_lifetime_session(self, uint32_t value):
        """
        Internal method for setting the maximum lifetime of each session.
        """
        raise NotImplementedError()

    def set_stmt_cache_size(self, uint32_t value):
        """
        Internal method for setting the size of the statement cache.
        """
        raise NotImplementedError()

    def set_timeout(self, uint32_t value):
        """
        Internal method for setting the timeout for idle sessions.
        """
        raise NotImplementedError()

    def set_wait_timeout(self, uint32_t value):
        """
        Internal method for setting the wait timeout for acquiring sessions.
        """
        raise NotImplementedError()
