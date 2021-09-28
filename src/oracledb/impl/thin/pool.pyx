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
        list _conn_impls_to_close
        uint8_t _getmode
        uint32_t _stmt_cache_size
        uint32_t _timeout
        uint32_t _max_lifetime_session
        uint32_t _num_pending_requests
        uint32_t _wait_timeout
        uint32_t _auth_mode
        int _ping_interval
        object _bg_exc
        object _bg_thread
        object _bg_thread_condition
        object _condition
        object _params
        bint _open

    def __init__(self, params, min, max, increment, homogeneous, getmode,
                 wait_timeout, stmtcachesize, ping_interval):
        self._params = params
        self.username = params.user
        self.dsn = params.get_dsn()
        self.min = min
        self.max = max
        self.increment = increment
        self.homogeneous = homogeneous
        self._getmode = getmode
        self._wait_timeout = wait_timeout
        self._stmt_cache_size = stmtcachesize
        self._ping_interval = ping_interval
        self._free_new_conn_impls = []
        self._free_used_conn_impls = []
        self._busy_conn_impls = []
        self._conn_impls_to_close = []
        self._auth_mode = constants.AUTH_MODE_DEFAULT
        self._condition = threading.Condition()
        self._bg_thread_condition = threading.Condition()
        self._bg_thread = threading.Thread(target=self._bg_thread_func,
                                           daemon=True)
        self._bg_thread.start()
        self._open = True

    cdef ThinConnImpl _create_conn_impl(self):
        """
        Create a single connection using the pool's information. This
        connection may be placed in the pool or may be returned directly (such
        as when the pool is full and POOL_GETMODE_FORCEGET is being used).
        """
        cdef ThinConnImpl conn_impl
        conn_impl = ThinConnImpl(self.username, self.dsn)
        conn_impl.connect(self._params, self._stmt_cache_size, self._auth_mode)
        conn_impl._pool = self
        return conn_impl

    def _bg_thread_func(self):
        """
        Method which runs in a dedicated thread and is used to create
        connections and close them when needed. When first started, it creates
        pool.min connections. After that, it creates pool.increment connections
        up to the value of pool.max when needed and destroys connections when
        needed. The thread terminates automatically when the pool is closed.
        """
        cdef:
            uint32_t open_count, num_conns = 0, i
            ThinConnImpl connection
            bint wait = False

        # create the initial set of connections requested
        self._create_conn_impls_helper(self.min)

        # wait for requests to create additional connections or destroy
        # connections
        while True:

            # determine whether to wait for work to do; a wait is forced if
            # a background exception has taken place -- unless the pool has
            # been closed, in which case no wait takes place
            with self._condition:
                wait = self._open and \
                        (self._bg_exc is not None or \
                                (self._num_pending_requests == 0 \
                                 and len(self._conn_impls_to_close) == 0))
            if wait:
                with self._bg_thread_condition:
                    self._bg_thread_condition.wait()

            # perform work of creating/destroying connections
            with self._condition:
                open_count = self.get_open_count()
                num_conns = min(self.increment, self.max - open_count)
            if self._open:
                self._create_conn_impls_helper(num_conns)
            self._close_conn_impls_helper()
            if not self._open:
                break

    cdef int _close_conn_impls_helper(self) except -1:
        """
        Helper method which closes the connections requested by the pool to be
        closed. When the pool is closed, exceptions are ignored.
        """
        cdef ThinConnImpl conn_impl
        while self._conn_impls_to_close:
            conn_impl = self._conn_impls_to_close.pop()
            try:
                conn_impl._force_close()
            except Exception as e:
                if self._open:
                    self._bg_exc = e
                    break

    cdef int _create_conn_impls_helper(self, uint32_t num_conns) except -1:
        """
        Helper method which creates the specified number of connections. In
        order to prevent the thread from dying, exceptions are captured and
        stored on the pool object. The next attempt to acquire a connection
        will return this exception.
        """
        cdef:
            ThinConnImpl conn_impl
            object exc
            uint32_t i
        for i in range(num_conns):
            conn_impl = None
            try:
                conn_impl = self._create_conn_impl()
            except Exception as e:
                exc = e
            with self._condition:
                if conn_impl is not None:
                    self._free_new_conn_impls.append(conn_impl)
                else:
                    self._bg_exc = exc
                self._condition.notify()
                if conn_impl is None:
                    break

    cdef int _free_busy_connection(self, ThinConnImpl connection) except -1:
        if not connection._protocol._session_needs_to_be_closed:
            connection.rollback()
        with self._condition:
            if connection._protocol._session_needs_to_be_closed:
                self._conn_impls_to_close.append(connection)
                with self._bg_thread_condition:
                    self._bg_thread_condition.notify()
            else:
                self._free_used_conn_impls.append(connection)
                connection._time_in_pool = time.monotonic()
            self._busy_conn_impls.remove(connection)
            self._condition.notify()

    cdef ThinConnImpl _get_connection_helper(self, object wait_timeout,
                                             uint32_t purity):
        cdef:
                ThinConnImpl conn_impl
                object predicate
                object exc
                double elapsed_time
                bint requires_ping

        # ensure manipulation of busy and free lists are done with the lock
        # held (in order to accommodate multiple threads attempting to acquire
        # a connection simultaneously)
        with self._condition:

            # wait for pool to have room available; if no room available after
            # timeout has been reached (if set), raise an exception
            predicate = lambda: self._has_room(purity)
            self._num_pending_requests += 1
            if not self._condition.wait_for(predicate, wait_timeout):
                self._num_pending_requests -= 1
                errors._raise_err(errors.ERR_POOL_NO_CONNECTION_AVAILABLE)

            # if an exception was raised while creating a connection, raise it
            # now (and clear it so subsequent attempts will try to create a
            # connection again)
            if self._bg_exc is not None:
                exc = self._bg_exc
                self._bg_exc = None
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
                    self._conn_impls_to_close.append(conn_impl)
                    with self._bg_thread_condition:
                        self._bg_thread_condition.notify()
                    conn_impl = self._create_conn_impl()
                self._busy_conn_impls.append(conn_impl)

            # if no new or used free connections are available, the
            # get mode must be POOL_GETMODE_FORCEGET; in this case a brand new
            # connection is created which is not returned to the pool
            else:
                conn_impl = self._create_conn_impl()
                conn_impl._pool = None

            self._num_pending_requests -= 1
            return conn_impl

    def _has_room(self, purity):
        """
        Returns a boolean indicating if room is available in the pool. This is
        true if there are free connections available. If no free connections
        are available but there is free space available in the pool, the
        creation thread is notified to create additional connections.
        """
        cdef uint32_t open_count
        if self._bg_exc is not None or self._free_new_conn_impls:
            return True
        open_count = self.get_open_count()
        if self._free_used_conn_impls:
            if purity != constants.PURITY_NEW or open_count == self.max:
                return True
        if open_count < self.max:
            with self._bg_thread_condition:
                self._bg_thread_condition.notify()
            return False
        return self._getmode == constants.POOL_GETMODE_FORCEGET

    def acquire(self, str user, str password, str cclass, uint32_t purity,
                str tag, bint matchanytag, list shardingkey,
                list supershardingkey):
        """
        Internal method for acquiring a connection from the pool.
        """
        cdef:
            object wait_timeout
            ThinConnImpl conn_impl
            bint requires_ping

        # if pool is closed, raise an exception
        if not self._open:
            errors._raise_err(errors.ERR_NOT_OPEN)

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

        # acquire a connection from the pool and perform a ping if the ping
        # interval is set to 0 or if the connection was previously used and
        # has been idle for a time greater than the value of ping interval
        while True:
            requires_ping = False
            conn_impl = self._get_connection_helper(wait_timeout, purity)
            if conn_impl._protocol._session_needs_to_be_closed:
                self._conn_impls_to_close.append(conn_impl)
                with self._bg_thread_condition:
                    self._bg_thread_condition.notify()
                continue
            if self._ping_interval == 0:
                requires_ping = True
            elif self._ping_interval > 0 and conn_impl._time_in_pool > 0:
                elapsed_time = time.monotonic() - conn_impl._time_in_pool
                if elapsed_time > self._ping_interval:
                    requires_ping = True
            if not requires_ping:
                break
            try:
                conn_impl._protocol._ping()
                break
            except exceptions.DatabaseError:
                self._conn_impls_to_close.append(conn_impl)
                with self._bg_thread_condition:
                    self._bg_thread_condition.notify()
        return conn_impl

    def close(self, bint force):
        """
        Internal method for closing the pool.
        """
        cdef:
            ThinConnImpl conn_impl

        with self._condition:

            # if force parameter is not True and busy connections exist in the
            # pool, raise an exception
            if not force and self.get_busy_count() > 0:
                errors._raise_err(errors.ERR_POOL_HAS_BUSY_CONNECTIONS)

            # close all connections in the pool; this is done by simply adding
            # to the list of connections that require closing and then waking
            # up the background thread to perform the work
            self._open = False
            for lst in (self._free_used_conn_impls,
                        self._free_new_conn_impls,
                        self._busy_conn_impls):
                self._conn_impls_to_close.extend(lst)
                for conn_impl in lst:
                    conn_impl._pool = None
                lst.clear()
            with self._bg_thread_condition:
                self._bg_thread_condition.notify()

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

    def get_ping_interval(self):
        """
        Internal method for getting the value of the pool-ping-interval.
        """
        return self._ping_interval

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

    def set_ping_interval(self, int value):
        """
        Internal method for setting the value of the pool-ping-interval.
        """
        self._ping_interval = value

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
