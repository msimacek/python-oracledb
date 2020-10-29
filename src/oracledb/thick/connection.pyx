#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# connection.pyx
#   Cython file defining the connection class (embedded in driver.pyx).
#------------------------------------------------------------------------------

cdef class Connection(BaseConnection):
    cdef:
        dpiConn *_handle
        public str tag

    def __dealloc__(self):
        if self._handle != NULL:
            dpiConn_release(self._handle)

    cdef int _close(self) except -1:
        cdef:
            uint32_t mode = DPI_MODE_CONN_CLOSE_DEFAULT
            const char *tag_ptr = NULL
            uint32_t tag_length = 0
            bytes tag_bytes
            int status
        if self.tag:
            mode = DPI_MODE_CONN_CLOSE_RETAG
            tag_bytes = self.tag.encode()
            tag_ptr = tag_bytes
            tag_length = <uint32_t> len(tag_bytes)
        with nogil:
            status = dpiConn_close(self._handle, mode, tag_ptr, tag_length)
            if status == DPI_SUCCESS:
                dpiConn_release(self._handle)
                self._handle = NULL
        if status < 0:
            _raise_from_odpi()

    cdef int _commit(self) except -1:
        cdef int status
        with nogil:
            status = dpiConn_commit(self._handle)
        if status < 0:
            _raise_from_odpi()

    def _connect(self, host, port, connect_string, password):
        cdef:
            bytes user_name_bytes, password_bytes, connect_string_bytes
            uint32_t user_name_length = 0, password_length = 0
            const char *connect_string_ptr = NULL
            dpiCommonCreateParams common_params
            uint32_t connect_string_length = 0
            const char *user_name_ptr = NULL
            const char *password_ptr = NULL
            dpiConnCreateParams conn_params
            int status
        if driver_context == NULL:
            init_oracle_client()
        if dpiContext_initCommonCreateParams(driver_context,
                                             &common_params) < 0:
            _raise_from_odpi()
        if dpiContext_initConnCreateParams(driver_context, &conn_params) < 0:
            _raise_from_odpi()
        if self.username:
            user_name_bytes = self.username.encode()
            user_name_ptr = user_name_bytes
            user_name_length = <uint32_t> len(user_name_bytes)
        if password:
            password_bytes = password.encode()
            password_ptr = password_bytes
            password_length = <uint32_t> len(password_bytes)
        if connect_string:
            connect_string_bytes = connect_string.encode()
            connect_string_ptr = connect_string_bytes
            connect_string_length = <uint32_t> len(connect_string_bytes)
        with nogil:
            status = dpiConn_create(driver_context, user_name_ptr,
                                    user_name_length, password_ptr,
                                    password_length, connect_string_ptr,
                                    connect_string_length, &common_params,
                                    &conn_params, &self._handle)
        if status < 0:
            _raise_from_odpi()
        self._is_connected = True

    cdef str _get_current_schema(self):
        cdef:
            uint32_t value_length
            const char *value
        if dpiConn_getCurrentSchema(self._handle, &value, &value_length) < 0:
            _raise_from_odpi()
        if value is not NULL:
            return value[:value_length].decode()

    cdef str _get_edition(self):
        cdef:
            uint32_t value_length
            const char *value
        if dpiConn_getEdition(self._handle, &value, &value_length) < 0:
            _raise_from_odpi()
        if value is not NULL:
            return value[:value_length].decode()

    cdef str _get_external_name(self):
        cdef:
            uint32_t value_length
            const char *value
        if dpiConn_getExternalName(self._handle, &value, &value_length) < 0:
            _raise_from_odpi()
        if value is not NULL:
            return value[:value_length].decode()

    cdef str _get_internal_name(self):
        cdef:
            uint32_t value_length
            const char *value
        if dpiConn_getInternalName(self._handle, &value, &value_length) < 0:
            _raise_from_odpi()
        if value is not NULL:
            return value[:value_length].decode()

    cdef bytes _get_ltxid(self):
        cdef:
            uint32_t value_length
            const char *value
        if dpiConn_getLTXID(self._handle, &value, &value_length) < 0:
            _raise_from_odpi()
        return value[:value_length]

    cdef uint32_t _get_stmtcachesize(self) except *:
        cdef uint32_t size
        if dpiConn_getStmtCacheSize(self._handle, &size) < 0:
            _raise_from_odpi()
        return size

    cdef str _get_version(self):
        cdef:
            dpiVersionInfo version_info
            int status
        self._verify_connected()
        with nogil:
            status = dpiConn_getServerVersion(self._handle, NULL, NULL,
                                              &version_info)
        if status < 0:
            _raise_from_odpi()
        return "%d.%d.%d.%d.%d" % \
                (version_info.versionNum, version_info.releaseNum,
                 version_info.updateNum, version_info.portReleaseNum,
                 version_info.portUpdateNum)

    cdef BaseCursor _create_cursor(self):
        return Cursor.__new__(Cursor, self)

    cdef int _ping(self) except -1:
        cdef int status
        with nogil:
            status = dpiConn_ping(self._handle)
        if status < 0:
            _raise_from_odpi()

    cdef int _rollback(self) except -1:
        cdef int status
        with nogil:
            status = dpiConn_rollback(self._handle)
        if status < 0:
            _raise_from_odpi()

    cdef int _set_current_schema(self, str value) except -1:
        cdef:
            uint32_t value_length
            const char *value_ptr
            bytes value_bytes
        value_bytes = value.encode()
        value_ptr = value_bytes
        value_length = len(value_bytes)
        if dpiConn_setCurrentSchema(self._handle, value_ptr, value_length) < 0:
            _raise_from_odpi()

    cdef int _set_external_name(self, str value) except -1:
        cdef:
            uint32_t value_length
            const char *value_ptr
            bytes value_bytes
        value_bytes = value.encode()
        value_ptr = value_bytes
        value_length = len(value_bytes)
        if dpiConn_setExternalName(self._handle, value_ptr, value_length) < 0:
            _raise_from_odpi()

    cdef int _set_internal_name(self, str value) except -1:
        cdef:
            uint32_t value_length
            const char *value_ptr
            bytes value_bytes
        value_bytes = value.encode()
        value_ptr = value_bytes
        value_length = len(value_bytes)
        if dpiConn_setInternalName(self._handle, value_ptr, value_length) < 0:
            _raise_from_odpi()

    cdef int _set_stmtcachesize(self, uint32_t value) except -1:
        if dpiConn_setStmtCacheSize(self._handle, value) < 0:
            _raise_from_odpi()
