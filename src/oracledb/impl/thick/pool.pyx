#------------------------------------------------------------------------------
# Copyright (c) 2020, 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# pool.pyx
#   Cython file defining the pool class (embedded in driver.pyx).
#------------------------------------------------------------------------------

cdef class ThickPoolImpl(BasePoolImpl):
    cdef:
        dpiPool *_handle

    def __dealloc__(self):
        if self._handle != NULL:
            dpiPool_release(self._handle)

    def _create(self, password, threaded, getmode, events, externalauth,
                edition, timeout, wait_timeout, max_lifetime_session,
                session_callback, max_sessions_per_shard):
        cdef:
            bytes edition_bytes, user_bytes, password_bytes, dsn_bytes
            uint32_t password_len = 0, user_len = 0, dsn_len = 0
            bytes session_callback_bytes, name_bytes
            dpiCommonCreateParams common_params
            dpiPoolCreateParams pool_params
            const char *password_ptr = NULL
            const char *user_ptr = NULL
            const char *dsn_ptr = NULL
            int status

        # ensure that the Oracle Client library is initialized
        if driver_context == NULL:
            init_oracle_client()

        # set up common creation parameters
        if dpiContext_initCommonCreateParams(driver_context,
                                             &common_params) < 0:
            _raise_from_odpi()
        if threaded:
            common_params.createMode |= DPI_MODE_CREATE_THREADED
        if events:
            common_params.createMode |= DPI_MODE_CREATE_EVENTS
        if edition:
            edition_bytes = edition.encode()
            common_params.edition = edition_bytes
            common_params.editionLength = <uint32_t> len(edition_bytes)

        # set up pool creation parameters
        if dpiContext_initPoolCreateParams(driver_context, &pool_params) < 0:
            _raise_from_odpi()
        pool_params.minSessions = self.min
        pool_params.maxSessions = self.max
        pool_params.sessionIncrement = self.increment
        pool_params.homogeneous = self.homogeneous
        pool_params.getMode = getmode
        if session_callback is not None and not callable(session_callback):
            session_callback_bytes = session_callback.encode()
            pool_params.plsqlFixupCallback = session_callback_bytes
            pool_params.plsqlFixupCallbackLength = \
                    <uint32_t> len(session_callback_bytes)
        pool_params.maxSessionsPerShard = max_sessions_per_shard

        # prepare user, password and DSN for use
        if self.username is not None:
            user_bytes = self.username.encode()
            user_ptr = user_bytes
            user_len = <uint32_t> len(user_bytes)
        if password is not None:
            password_bytes = password.encode()
            password_ptr = password_bytes
            password_len = <uint32_t> len(password_bytes)
        if self.dsn is not None:
            dsn_bytes = self.dsn.encode()
            dsn_ptr = dsn_bytes
            dsn_len = <uint32_t> len(dsn_bytes)

        # create pool
        with nogil:
            status = dpiPool_create(driver_context, user_ptr, user_len,
                                    password_ptr, password_len, dsn_ptr,
                                    dsn_len, &common_params, &pool_params,
                                    &self._handle)
        if status < 0:
            _raise_from_odpi()
        name_bytes = pool_params.outPoolName[:pool_params.outPoolNameLength]
        self.name = name_bytes.decode()

    def acquire(self, str user, str password, str cclass, uint32_t purity,
                str tag, bint matchanytag, list shardingkey,
                list supershardingkey):
        """
        Internal method for acquiring a connection from the pool.
        """
        cdef ThickConnImpl conn_impl
        conn_impl = ThickConnImpl(user, None)
        conn_impl.connect(pool_impl=self, password=password, cclass=cclass,
                          purity=purity, tag=tag, matchanytag=matchanytag,
                          shardingkey=shardingkey,
                          supershardingkey=supershardingkey)
        return conn_impl

    def close(self, bint force):
        """
        Internal method for closing the pool.
        """
        raise NotImplementedError()

    def drop(self, ThickConnImpl conn_impl):
        """
        Internal method for dropping a connection from the pool.
        """
        cdef int status
        with nogil:
            status = dpiConn_close(conn_impl._handle, DPI_MODE_CONN_CLOSE_DROP,
                                   NULL, 0)
        if status < 0:
            _raise_from_odpi()
        dpiConn_release(conn_impl._handle)
        conn_impl._handle = NULL

    def get_busy_count(self):
        """
        Internal method for getting the number of busy connections in the pool.
        """
        cdef uint32_t value
        if dpiPool_getBusyCount(self._handle, &value) < 0:
            _raise_from_odpi()
        return value

    def get_getmode(self):
        """
        Internal method for getting the method by which connections are
        acquired from the pool.
        """
        cdef uint8_t value
        if dpiPool_getGetMode(self._handle, &value) < 0:
            _raise_from_odpi()
        return value

    def get_max_lifetime_session(self):
        """
        Internal method for getting the maximum lifetime of each session.
        """
        cdef uint32_t value
        if dpiPool_getMaxLifetimeSession(self._handle, &value) < 0:
            _raise_from_odpi()
        return value

    def get_open_count(self):
        """
        Internal method for getting the number of connections in the pool.
        """
        cdef uint32_t value
        if dpiPool_getOpenCount(self._handle, &value) < 0:
            _raise_from_odpi()
        return value

    def get_stmt_cache_size(self):
        """
        Internal method for getting the size of the statement cache.
        """
        cdef uint32_t value
        if dpiPool_getStmtCacheSize(self._handle, &value) < 0:
            _raise_from_odpi()
        return value

    def get_timeout(self):
        """
        Internal method for getting the timeout for idle sessions.
        """
        cdef uint32_t value
        if dpiPool_getTimeout(self._handle, &value) < 0:
            _raise_from_odpi()
        return value

    def get_wait_timeout(self):
        """
        Internal method for getting the wait timeout for acquiring sessions.
        """
        cdef uint32_t value
        if dpiPool_getWaitTimeout(self._handle, &value) < 0:
            _raise_from_odpi()
        return value

    def set_getmode(self, uint8_t value):
        """
        Internal method for setting the method by which connections are
        acquired from the pool.
        """
        if dpiPool_setGetMode(self._handle, value) < 0:
            _raise_from_odpi()

    def set_max_lifetime_session(self, uint32_t value):
        """
        Internal method for setting the maximum lifetime of each session.
        """
        if dpiPool_setMaxLifetimeSession(self._handle, value) < 0:
            _raise_from_odpi()

    def set_stmt_cache_size(self, uint32_t value):
        """
        Internal method for setting the size of the statement cache.
        """
        if dpiPool_setStmtCacheSize(self._handle, value) < 0:
            _raise_from_odpi()

    def set_timeout(self, uint32_t value):
        """
        Internal method for setting the timeout for idle sessions.
        """
        if dpiPool_setTimeout(self._handle, value) < 0:
            _raise_from_odpi()

    def set_wait_timeout(self, uint32_t value):
        """
        Internal method for setting the wait timeout for acquiring sessions.
        """
        if dpiPool_setWaitTimeout(self._handle, value) < 0:
            _raise_from_odpi()
