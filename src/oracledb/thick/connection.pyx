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
        if self.user:
            user_name_bytes = self.user.encode()
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
        """
        Internal method for creating a cursor.
        """
        return Cursor.__new__(Cursor, self)

    def close(self):
        cdef:
            uint32_t mode = DPI_MODE_CONN_CLOSE_DEFAULT
            const char *tag_ptr = NULL
            uint32_t tag_length = 0
            bytes tag_bytes
            int status
        self._verify_connected()
        if self.tag:
            mode = DPI_MODE_CONN_CLOSE_RETAG
            tag_bytes = self.tag.encode()
            tag_ptr = tag_bytes
            tag_length = <uint32_t> len(tag_bytes)
        with nogil:
            status = dpiConn_close(self._handle, mode, tag_ptr, tag_length)
            if status == DPI_SUCCESS:
                dpiConn_release(self._handle)
        if status < 0:
            _raise_from_odpi()
        self._handle = NULL
