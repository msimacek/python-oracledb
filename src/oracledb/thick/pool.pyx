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

    def _create(self, user, password, min, max, increment, threaded, getmode,
                events, homogeneous, externalauth, edition, timeout,
                wait_timeout, max_lifetime_session, session_callback,
                max_sessions_per_shard):
        cdef:
            bytes edition_bytes, user_bytes, password_bytes, dsn_bytes
            uint32_t password_len = 0, user_len = 0, dsn_len = 0
            dpiCommonCreateParams common_params
            dpiPoolCreateParams pool_params
            const char *password_ptr = NULL
            bytes session_callback_bytes
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
        pool_params.minSessions = min
        pool_params.maxSessions = max
        pool_params.sessionIncrement = increment
        if session_callback is not None and not callable(session_callback):
            session_callback_bytes = session_callback.encode()
            pool_params.plsqlFixupCallback = session_callback_bytes
            pool_params.plsqlFixupCallbackLength = \
                    <uint32_t> len(session_callback_bytes)
        pool_params.maxSessionsPerShard = max_sessions_per_shard

        # prepare user, password and DSN for use
        if user:
            user_bytes = user.encode()
            user_ptr = user_bytes
            user_len = <uint32_t> len(user_bytes)
        if password:
            password_bytes = password.encode()
            password_ptr = password_bytes
            password_len = <uint32_t> len(password_bytes)
        if self.dsn:
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
