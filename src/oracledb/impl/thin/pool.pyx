#------------------------------------------------------------------------------
# Copyright (c) 2020, 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# pool.pyx
#   Cython file defining the pool class (embedded in driver.pyx).
#------------------------------------------------------------------------------

cdef class ThinPoolImpl(BasePoolImpl):

    cdef:
        list _free_new_conn_impls
        list _free_used_conn_impls
        list _busy_conn_impls
        uint8_t _getmode
        uint32_t _stmt_cache_size
        uint32_t _timeout
        uint32_t _max_lifetime_session
        uint32_t _num_pending_requests
        uint32_t _wait_timeout
        object _create_exc
        object _create_thread
        object _create_thread_condition
        object _condition
        object _params
        bint _shutdown

    def __init__(self, params, min, max, increment, homogeneous, getmode,
                 wait_timeout):
        self._params = params
        self.username = params.user
        self.dsn = params.get_dsn()
        self.min = min
        self.max = max
        self.increment = increment
        self.homogeneous = homogeneous
        self._getmode = getmode
        self._wait_timeout = wait_timeout
        self._free_new_conn_impls = []
        self._free_used_conn_impls = []
        self._busy_conn_impls = []
        self._condition = threading.Condition()
        self._create_thread_condition = threading.Condition()
        self._create_thread = threading.Thread(target=self._create_conn_impls,
                                               daemon=True)
        self._create_thread.start()

    cdef ThinConnImpl _create_conn_impl(self):
        """
        Create a single connection using the pool's information. This
        connection may be placed in the pool or may be returned directly (such
        as when the pool is full and POOL_GETMODE_FORCEWAIT is being used).
        """
        cdef ThinConnImpl conn_impl
        conn_impl = ThinConnImpl(self.username, self.dsn)
        conn_impl._connect(self._params)
        conn_impl._pool = self
        return conn_impl

    def _create_conn_impls(self):
        """
        Method which runs in a dedicated thread and is used to create
        connections when needed. This happens initially when the pool is
        created (pool.min connections are created) and when no free connections
        are available (pool.increment up to a maximum of pool.max connections
        are created).
        """
        cdef:
            uint32_t open_count, num_conns = 0, i
            ThinConnImpl connection
            bint wait, shutdown

        # create the initial set of connections requested
        self._create_conn_impls_helper(self.min)

        # wait for requests to create additional connections and then create
        # them; continue creating connections (self.increment at a time) up
        # until the maximum number of connections exists in the pool
        while True:
            with self._condition:
                wait = self._num_pending_requests == 0 \
                        or self._create_exc is not None
            if wait:
                with self._create_thread_condition:
                    self._create_thread_condition.wait()
            if self._shutdown:
                break
            with self._condition:
                open_count = self.get_open_count()
                num_conns = min(self.increment, self.max - open_count)
            self._create_conn_impls_helper(num_conns)

    cdef int _create_conn_impls_helper(self, uint32_t num_conns) except -1:
        """
        Helper method which creates the specified number of connections. In
        order to prevent the thread from dying, exceptions are captured and
        stored on the pool object. The next attempt to acquire a connection
        will return this exception.
        """
        cdef:
            ThinConnImpl conn
            object exc
            uint32_t i
        for i in range(num_conns):
            conn = None
            try:
                conn = self._create_conn_impl()
            except Exception as e:
                exc = e
            with self._condition:
                if conn is not None:
                    self._free_new_conn_impls.append(conn)
                else:
                    self._create_exc = exc
                self._condition.notify()
                if conn is None:
                    break

    cdef int _free_busy_connection(self, ThinConnImpl connection) except -1:
        connection.rollback()
        with self._condition:
            self._busy_conn_impls.remove(connection)
            self._free_used_conn_impls.append(connection)
            self._condition.notify()

    def _has_room(self, purity):
        """
        Returns a boolean indicating if room is available in the pool. This is
        true if there are free connections available. If no free connections
        are available but there is free space available in the pool, the
        creation thread is notified to create additional connections.
        """
        cdef uint32_t open_count
        if self._create_exc is not None or self._free_new_conn_impls:
            return True
        open_count = self.get_open_count()
        if self._free_used_conn_impls:
            if purity != constants.PURITY_NEW or open_count == self.max:
                return True
        if open_count < self.max:
            with self._create_thread_condition:
                self._create_thread_condition.notify()
            return False
        return self._getmode == constants.POOL_GETMODE_FORCEGET

    def acquire(self, str user, str password, str cclass, uint32_t purity,
                str tag, bint matchanytag, list shardingkey,
                list supershardingkey):
        """
        Internal method for acquiring a connection from the pool.
        """
        cdef:
            ThinConnImpl conn_impl
            object wait_timeout
            object predicate
            object exc

        # session tagging has not been implemented yet
        if tag is not None:
            raise NotImplementedError("Tagging has not been implemented yet")

        # determine wait timeout to use
        if self._getmode == constants.POOL_GETMODE_TIMEDWAIT:
            wait_timeout = self._wait_timeout / 1000
        elif self._getmode == constants.POOL_GETMODE_WAIT \
                or self._getmode == constants.POOL_GETMODE_FORCEGET:
            wait_timeout = None
        else:
            wait_timeout = 0

        # ensure manipulation of busy and free lists are done with the lock
        # held (in order to accommodate multiple threads attempting to acquire
        # a connection simultaneously)
        with self._condition:

            # wait for pool to have room available; if no room available after
            # timeout has been reached (if set), raise an exception
            predicate = lambda: self._has_room(purity)
            self._num_pending_requests += 1
            if not self._condition.wait_for(predicate, wait_timeout):
                message = "No connection available in pool"
                self._num_pending_requests -= 1
                errors._raise_from_string(exceptions.DatabaseError, message)

            # if an exception was raised while creating a connection, raise it
            # now (and clear it so subsequent attempts will try to create a
            # connection again)
            if self._create_exc is not None:
                exc = self._create_exc
                self._create_exc = None
                raise exc

            # if a free new connection is available, it can be used without any
            # other considerations
            if self._free_new_conn_impls:
                conn_impl = self._free_new_conn_impls.pop()
                self._busy_conn_impls.append(conn_impl)

            # if a free used connection is available and the purity allows the
            # use of such a connection, it can also be used directly;
            # otherwise, if a new connection is required, that connection will
            # be closed and a new one will be created instead
            elif self._free_used_conn_impls:
                conn_impl = self._free_used_conn_impls.pop(0)
                if purity == constants.PURITY_NEW:
                    conn_impl._pool = None
                    conn_impl.close()
                    conn_impl = self._create_conn_impl()
                self._busy_conn_impls.append(conn_impl)

            # finally, if no new or used free connections are available, the
            # get mode must be POOL_GETMODE_FORCEGET; in this case a brand new
            # connection is created which is not returned to the pool
            else:
                conn_impl = self._create_conn_impl()
                conn_impl._pool = None

            self._num_pending_requests -= 1
            return conn_impl

    def drop(self, ThinConnImpl conn_impl):
        """
        Internal method for dropping a connection from the pool.
        """
        with self._condition:
            self._busy_conn_impls.remove(conn_impl)
            self._condition.notify()
        conn_impl._pool = None
        conn_impl.close()

    def get_busy_count(self):
        """
        Internal method for getting the number of busy connections in the pool.
        """
        return len(self._busy_conn_impls)

    def get_getmode(self):
        """
        Internal method for getting the method by which connections are
        acquired from the pool.
        """
        return self._getmode

    def get_max_lifetime_session(self):
        """
        Internal method for getting the maximum lifetime of each session.
        """
        return self._max_lifetime_session

    def get_open_count(self):
        """
        Internal method for getting the number of connections in the pool.
        """
        return len(self._busy_conn_impls) + \
               len(self._free_used_conn_impls) + \
               len(self._free_new_conn_impls)

    def get_stmt_cache_size(self):
        """
        Internal method for getting the size of the statement cache.
        """
        return self._stmt_cache_size

    def get_timeout(self):
        """
        Internal method for getting the timeout for idle sessions.
        """
        return self._timeout

    def get_wait_timeout(self):
        """
        Internal method for getting the wait timeout for acquiring sessions.
        """
        return self._wait_timeout

    def set_getmode(self, uint8_t value):
        """
        Internal method for setting the method by which connections are
        acquired from the pool.
        """
        self._getmode = value

    def set_max_lifetime_session(self, uint32_t value):
        """
        Internal method for setting the maximum lifetime of each session.
        """
        self._max_lifetime_session = value


    def set_stmt_cache_size(self, uint32_t value):
        """
        Internal method for setting the size of the statement cache.
        """
        self._stmt_cache_size = value

    def set_timeout(self, uint32_t value):
        """
        Internal method for setting the timeout for idle sessions.
        """
        self._timeout = value

    def set_wait_timeout(self, uint32_t value):
        """
        Internal method for setting the wait timeout for acquiring sessions.
        """
        self._wait_timeout = value
