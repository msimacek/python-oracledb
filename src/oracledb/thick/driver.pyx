#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

# cython: language_level=3

from .. import constants, errors, exceptions

from ..common.driver cimport get_exception_class
from ..common.driver cimport BaseConnection
from ..common.driver cimport BaseCursor
from libc.string cimport memset

include "odpi.pxd"

cdef dpiContext *driver_context = NULL

cdef class Connection(BaseConnection):
    cdef dpiConn *_handle

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

    def cursor(self):
        return Cursor(self)


cdef class Cursor(BaseCursor):
    cdef:
        readonly Connection connection
        readonly uint64_t rowcount
        dpiStmt *_handle
        dpiStmtInfo _stmt_info;
        str _tag

    def __cinit__(self, connection):
        self.connection = connection

    def __dealloc__(self):
        if self._handle != NULL:
            dpiStmt_release(self._handle)

    cdef int _execute(Cursor self) except -1:
        """
        Internal method for executing a statement.
        """
        cdef:
            uint64_t rowcount
            uint32_t mode, num_query_cols
            int status
        mode = DPI_MODE_EXEC_DEFAULT
        with nogil:
            status = dpiStmt_execute(self._handle, mode, &num_query_cols)
            if status == 0:
                status = dpiStmt_getRowCount(self._handle, &rowcount)
        if status < 0:
            _raise_from_odpi()
        self.rowcount = rowcount

    cdef int _prepare(Cursor self, str statement, str tag=None) except -1:
        """
        Internal method used for preparing statements for execution.
        """
        cdef:
            uint32_t statement_bytes_length, tag_bytes_length = 0
            bytes statement_bytes, tag_bytes
            const char *tag_ptr = NULL
            const char *statement_ptr
            int status
        if statement is None and self.statement is None:
            errors._raise_from_string(exceptions.ProgrammingError,
                    "no statement specified and no prior statement prepared")
        # nothing to do if the statement is identical to the one already
        # stored, but go ahead and prepare anyway for DDL statements
        if statement is None or statement == self.statement:
            if self._handle != NULL and not self._stmt_info.isDDL:
                return 0
            statement = self.statement
        self.statement = statement
        statement_bytes = statement.encode()
        statement_ptr = <const char*> statement_bytes
        statement_bytes_length = <uint32_t> len(statement_bytes)
        if tag is not None:
            self._tag = tag
            tag_bytes = tag.encode()
            tag_bytes_length = <uint32_t> len(tag_bytes)
            tag_ptr = <const char*> tag_bytes
        with nogil:
            if self._handle != NULL:
                dpiStmt_release(self._handle)
                self._handle = NULL
            status = dpiConn_prepareStmt(self.connection._handle, 0,
                                         statement_ptr, statement_bytes_length,
                                         tag_ptr, tag_bytes_length,
                                         &self._handle)
            if status == 0:
                status = dpiStmt_getInfo(self._handle, &self._stmt_info)
            if status == 0 and self._stmt_info.isQuery:
                status = dpiStmt_setFetchArraySize(self._handle,
                                                   self.arraysize)
                if status == 0 \
                        and self.prefetchrows != DPI_DEFAULT_PREFETCH_ROWS:
                    status = dpiStmt_setPrefetchRows(self._handle,
                                                     self.prefetchrows)
        if status < 0:
            _raise_from_odpi()

    def execute(self, statement=None, parameters=None, **keyword_parameters):
        """
        Executes a statement, passing any parameters to the database.
        """

        # verify parameters
        if parameters and keyword_parameters:
            errors._raise_from_string(exceptions.InterfaceError,
                    "expecting argument or keyword arguments, not both")
        if parameters is not None \
                and not isinstance(parameters, (list, tuple, dict)):
            errors._raise_from_string(exceptions.InterfaceError,
                    "expecting a dictionary, list or tuple, or keyword args")
        self._verify_open()

        # prepare statement, if necessary, and then execute it
        self._prepare(statement)
        self._execute()


cdef int _raise_from_info(dpiErrorInfo *error_info) except -1:
    """
    Raises an exception given a dpiErrorInfo structure that is already
    populated with error information.
    """
    msg_bytes = error_info.message[:error_info.messageLength]
    context = "%s: %s" % (error_info.fnName, error_info.action)
    error = errors._Error(msg_bytes.decode(), context, code=error_info.code,
                          offset=error_info.offset,
                          isrecoverable=error_info.isRecoverable,
                          iswarning=error_info.isWarning)
    exc_type = get_exception_class(error_info.code)
    raise exc_type(error)


cdef int _raise_from_odpi() except -1:
    """
    Raises an exception from ODPI-C, given that an error has been raised by
    ODPI-C (a return code of -1 has been received).
    """
    cdef dpiErrorInfo error_info
    dpiContext_getError(driver_context, &error_info)
    _raise_from_info(&error_info)


def init_oracle_client(lib_dir=None, config_dir=None, error_url=None,
        driver_name=None):
    """
    Initialize the Oracle Client library. This method is available externally
    in order to be called with parameters that control how the Oracle Client
    library is initialized. If not called earlier, the first usage of the
    Oracle Client library will cause this method to be called internally.
    """
    cdef bytes lib_dir_bytes, config_dir_bytes, driver_name_bytes
    cdef dpiContextCreateParams params
    cdef dpiErrorInfo error_info
    cdef bytes encoding_bytes
    if driver_context != NULL:
        errors._raise_from_string(exceptions.ProgrammingError,
                "Oracle Client library has already been initialized")
    memset(&params, 0, sizeof(dpiContextCreateParams))
    encoding_bytes = constants.ENCODING.encode()
    params.defaultEncoding = encoding_bytes
    if lib_dir is not None:
        lib_dir_bytes = lib_dir.encode()
        params.oracleClientLibDir = lib_dir_bytes
    if config_dir is not None:
        config_dir_bytes = config_dir.encode()
        params.oracleClientConfigDir = config_dir_bytes
    if driver_name is not None:
        driver_name_bytes = driver_name.encode()
    else:
        driver_name_bytes = constants.DRIVER_NAME.encode()
    params.defaultDriverName = driver_name_bytes
    if error_url is not None:
        error_url_bytes = error_url.encode()
    else:
        error_url_bytes = constants.INSTALLATION_URL.encode()
    params.loadErrorUrl = error_url_bytes
    if dpiContext_createWithParams(DPI_MAJOR_VERSION, DPI_MINOR_VERSION,
                                   &params, &driver_context, &error_info) < 0:
        _raise_from_info(&error_info)
