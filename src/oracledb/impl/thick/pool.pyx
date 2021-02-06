#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# pool.pyx
#   Cython file defining the pool class (embedded in driver.pyx).
#------------------------------------------------------------------------------

cdef class Pool(BasePool):
    cdef:
        dpiPool *_handle

    def __dealloc__(self):
        if self._handle != NULL:
            dpiPool_release(self._handle)

    cdef BaseConnection _acquire(self, str user, str password, str cclass,
                                 uint32_t purity, str tag, bint match_any_tag,
                                 list sharding_key, list super_sharding_key):
        cdef Connection connection
        connection = Connection(user, self.name)
        connection._connect(password=password, mode=constants.DEFAULT_AUTH,
                            handle=0, pool=self, threaded=False,
                            events=False, cclass=cclass, purity=purity,
                            newpassword=None, edition=None, appcontext=None,
                            tag=tag, matchanytag=match_any_tag,
                            shardingkey=sharding_key,
                            supershardingkey=super_sharding_key)
        return connection

    cdef int _close(self, bint force) except -1:
        raise NotImplementedError()

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

    cdef int _drop(self, BaseConnection connection) except -1:
        cdef:
            Connection thick_connection = <Connection> connection
            int status
        with nogil:
            status = dpiConn_close(thick_connection._handle,
                                   DPI_MODE_CONN_CLOSE_DROP, NULL, 0)
        if status < 0:
            _raise_from_odpi()
        dpiConn_release(thick_connection._handle)
        thick_connection._handle = NULL
        thick_connection._is_connected = False

    cdef int _get_busy_count(self, uint32_t *value) except -1:
        if dpiPool_getBusyCount(self._handle, value) < 0:
            _raise_from_odpi()

    cdef int _get_getmode(self, uint8_t *value) except -1:
        if dpiPool_getGetMode(self._handle, value) < 0:
            _raise_from_odpi()

    cdef int _get_max_lifetime_session(self, uint32_t *value) except -1:
        if dpiPool_getMaxLifetimeSession(self._handle, value) < 0:
            _raise_from_odpi()

    cdef int _get_open_count(self, uint32_t *value) except -1:
        if dpiPool_getOpenCount(self._handle, value) < 0:
            _raise_from_odpi()

    cdef int _get_stmt_cache_size(self, uint32_t *value) except -1:
        if dpiPool_getStmtCacheSize(self._handle, value) < 0:
            _raise_from_odpi()

    cdef int _get_timeout(self, uint32_t *value) except -1:
        if dpiPool_getTimeout(self._handle, value) < 0:
            _raise_from_odpi()

    cdef int _get_wait_timeout(self, uint32_t *value) except -1:
        if dpiPool_getWaitTimeout(self._handle, value) < 0:
            _raise_from_odpi()

    cdef int _release(self, BaseConnection connection, str tag) except -1:
        cdef Connection thick_connection = <Connection> connection
        if tag is not None:
            thick_connection.tag = tag
        thick_connection._close()
        thick_connection._is_connected = False

    cdef int _set_getmode(self, uint8_t value) except -1:
        if dpiPool_setGetMode(self._handle, value) < 0:
            _raise_from_odpi()

    cdef int _set_max_lifetime_session(self, uint32_t value) except -1:
        if dpiPool_setMaxLifetimeSession(self._handle, value) < 0:
            _raise_from_odpi()

    cdef int _set_stmt_cache_size(self, uint32_t value) except -1:
        if dpiPool_setStmtCacheSize(self._handle, value) < 0:
            _raise_from_odpi()

    cdef int _set_timeout(self, uint32_t value) except -1:
        if dpiPool_setTimeout(self._handle, value) < 0:
            _raise_from_odpi()

    cdef int _set_wait_timeout(self, uint32_t value) except -1:
        if dpiPool_setWaitTimeout(self._handle, value) < 0:
            _raise_from_odpi()
