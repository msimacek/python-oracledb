#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# utils.pyx
#   Cython file for utility functions (embedded in driver.pyx).
#------------------------------------------------------------------------------

cdef int _convert_from_python(object value, DbType dbtype,
                              BaseDbObjectType objtype, dpiDataBuffer *dbvalue,
                              StringBuffer buf, Var var=None,
                              uint32_t pos=0) except -1:
    cdef:
        uint32_t oracle_type = dbtype.num
        dpiTimestamp *timestamp
        DbObject obj
        int status
        Lob lob
    if oracle_type == DPI_ORACLE_TYPE_NUMBER:
        if isinstance(value, bool):
            if value:
                buf.set_value("1")
            else:
                buf.set_value("0")
        elif isinstance(value, (int, float, decimal.Decimal)):
            buf.set_value(str(value))
        else:
            raise TypeError("expecting number")
        dbvalue.asBytes.ptr = buf.ptr
        dbvalue.asBytes.length = buf.length
    elif oracle_type == DPI_ORACLE_TYPE_NATIVE_DOUBLE \
            or oracle_type == DPI_ORACLE_TYPE_NATIVE_FLOAT:
        if not isinstance(value, (float, int, decimal.Decimal)):
            raise TypeError("expecting number")
        if oracle_type == DPI_ORACLE_TYPE_NATIVE_DOUBLE:
            dbvalue.asDouble = <double> value
        else:
            dbvalue.asFloat = <float> value
    elif oracle_type == DPI_ORACLE_TYPE_VARCHAR \
            or oracle_type == DPI_ORACLE_TYPE_NVARCHAR \
            or oracle_type == DPI_ORACLE_TYPE_CHAR \
            or oracle_type == DPI_ORACLE_TYPE_NCHAR \
            or oracle_type == DPI_ORACLE_TYPE_LONG_VARCHAR:
        if not isinstance(value, str):
            raise TypeError("expecting str")
        buf.set_value(value)
        if var is not None:
            var._set_from_bytes(pos, buf.obj)
        else:
            dbvalue.asBytes.ptr = buf.ptr
            dbvalue.asBytes.length = buf.length
    elif oracle_type == DPI_ORACLE_TYPE_RAW \
            or oracle_type == DPI_ORACLE_TYPE_LONG_RAW:
        if not isinstance(value, bytes):
            raise TypeError("expecting bytes")
        if var is not None:
            var._set_from_bytes(pos, value)
    elif oracle_type == DPI_ORACLE_TYPE_DATE \
            or oracle_type == DPI_ORACLE_TYPE_TIMESTAMP \
            or oracle_type == DPI_ORACLE_TYPE_TIMESTAMP_LTZ \
            or oracle_type == DPI_ORACLE_TYPE_TIMESTAMP_TZ:
        memset(&dbvalue.asTimestamp, 0, sizeof(dbvalue.asTimestamp))
        timestamp = &dbvalue.asTimestamp
        if isinstance(value, datetime.datetime):
            timestamp.year = cydatetime.datetime_year(value)
            timestamp.month = cydatetime.datetime_month(value)
            timestamp.day = cydatetime.datetime_day(value)
            timestamp.hour = cydatetime.datetime_hour(value)
            timestamp.minute = cydatetime.datetime_minute(value)
            timestamp.second = cydatetime.datetime_second(value)
            timestamp.fsecond = cydatetime.datetime_microsecond(value) * 1000
        elif isinstance(value, datetime.date):
            timestamp.year = cydatetime.date_year(value)
            timestamp.month = cydatetime.date_month(value)
            timestamp.day = cydatetime.date_day(value)
        else:
            raise TypeError("expecting datetime.date or datetime.datetime")
    elif oracle_type == DPI_ORACLE_TYPE_BOOLEAN:
        dbvalue.asBoolean = 1 if value else 0
    elif oracle_type == DPI_ORACLE_TYPE_NATIVE_INT:
        if isinstance(value, bool):
            dbvalue.asInt64 = 1 if value else 0
        else:
            dbvalue.asInt64 = <int64_t> value
    elif oracle_type == DPI_ORACLE_TYPE_OBJECT:
        if not isinstance(value, DbObject):
            raise TypeError("expecting DbObject")
        obj = <DbObject> value
        if var is not None:
            if dpiVar_setFromObject(var._handle, pos, obj._handle) < 0:
                _raise_from_odpi()
        else:
            dbvalue.asObject = obj._handle
    elif oracle_type == DPI_ORACLE_TYPE_CLOB \
            or oracle_type == DPI_ORACLE_TYPE_BLOB \
            or oracle_type == DPI_ORACLE_TYPE_NCLOB:
        if isinstance(value, Lob):
            lob = <Lob> value
            if var is not None:
                if dpiVar_setFromLob(var._handle, pos, lob._handle) < 0:
                    _raise_from_odpi()
            else:
                dbvalue.asLOB = lob._handle
        else:
            buf.set_value(value)
            if var is not None:
                with nogil:
                    status = dpiLob_setFromBytes(dbvalue.asLOB, buf.ptr,
                                                 buf.length)
                if status < 0:
                    _raise_from_odpi()
            else:
                dbvalue.asBytes.ptr = buf.ptr
                dbvalue.asBytes.length = buf.length
    else:
        errors._raise_from_string(exceptions.NotSupportedError,
                                  f"database type {dbtype} not supported")


cdef object _convert_to_python(Connection connection, DbType dbtype,
                               DbObjectType objtype, dpiDataBuffer *dbvalue,
                               bint number_as_int=False):
    cdef:
        uint32_t oracle_type = dbtype.num
        dpiTimestamp *as_timestamp
        uint32_t rowid_length
        dpiBytes *as_bytes
        const char *rowid
    if oracle_type == DPI_ORACLE_TYPE_CHAR \
            or oracle_type == DPI_ORACLE_TYPE_NCHAR \
            or oracle_type == DPI_ORACLE_TYPE_VARCHAR \
            or oracle_type == DPI_ORACLE_TYPE_NVARCHAR \
            or oracle_type == DPI_ORACLE_TYPE_LONG_VARCHAR:
        as_bytes = &dbvalue.asBytes
        return as_bytes.ptr[:as_bytes.length].decode()
    elif oracle_type == DPI_ORACLE_TYPE_NUMBER:
        as_bytes = &dbvalue.asBytes
        if number_as_int \
                and memchr(as_bytes.ptr, b'.', as_bytes.length) == NULL:
            return int(as_bytes.ptr[:as_bytes.length].decode())
        return float(as_bytes.ptr[:as_bytes.length].decode())
    elif oracle_type == DPI_ORACLE_TYPE_RAW \
            or oracle_type == DPI_ORACLE_TYPE_LONG_RAW:
        as_bytes = &dbvalue.asBytes
        return as_bytes.ptr[:as_bytes.length]
    elif oracle_type == DPI_ORACLE_TYPE_DATE \
            or oracle_type == DPI_ORACLE_TYPE_TIMESTAMP \
            or oracle_type == DPI_ORACLE_TYPE_TIMESTAMP_LTZ \
            or oracle_type == DPI_ORACLE_TYPE_TIMESTAMP_TZ:
        as_timestamp = &dbvalue.asTimestamp
        return cydatetime.datetime_new(as_timestamp.year, as_timestamp.month,
                                       as_timestamp.day, as_timestamp.hour,
                                       as_timestamp.minute,
                                       as_timestamp.second,
                                       as_timestamp.fsecond // 1000, None)
    elif oracle_type == DPI_ORACLE_TYPE_BOOLEAN:
        return dbvalue.asBoolean == 1
    elif oracle_type == DPI_ORACLE_TYPE_NATIVE_DOUBLE:
        return dbvalue.asDouble
    elif oracle_type == DPI_ORACLE_TYPE_NATIVE_FLOAT:
        return dbvalue.asFloat
    elif oracle_type == DPI_ORACLE_TYPE_NATIVE_INT:
        return dbvalue.asInt64
    elif oracle_type == DPI_ORACLE_TYPE_ROWID:
        if dpiRowid_getStringValue(dbvalue.asRowid, &rowid, &rowid_length) < 0:
            _raise_from_odpi()
        return rowid[:rowid_length].decode()
    elif oracle_type == DPI_ORACLE_TYPE_CLOB \
            or oracle_type == DPI_ORACLE_TYPE_BLOB \
            or oracle_type == DPI_ORACLE_TYPE_NCLOB \
            or oracle_type == DPI_ORACLE_TYPE_BFILE:
        return Lob._new_lob(connection, dbtype, dbvalue.asLOB)
    elif oracle_type == DPI_ORACLE_TYPE_OBJECT:
        return DbObject._new_object(objtype, dbvalue.asObject)
    errors._raise_from_string(exceptions.NotSupportedError,
                              f"database type {dbtype} not supported")


cdef uint32_t _get_native_type_num(DbType dbtype):
    cdef uint32_t oracle_type_num = dbtype.num
    if oracle_type_num == DPI_ORACLE_TYPE_NATIVE_FLOAT:
        return DPI_NATIVE_TYPE_FLOAT
    elif oracle_type_num == DPI_ORACLE_TYPE_NATIVE_DOUBLE:
        return DPI_NATIVE_TYPE_DOUBLE
    elif oracle_type_num == DPI_ORACLE_TYPE_BOOLEAN:
        return DPI_NATIVE_TYPE_BOOLEAN
    elif oracle_type_num == DPI_ORACLE_TYPE_CLOB \
            or oracle_type_num == DPI_ORACLE_TYPE_NCLOB \
            or oracle_type_num == DPI_ORACLE_TYPE_BLOB \
            or oracle_type_num == DPI_ORACLE_TYPE_BFILE:
        return DPI_NATIVE_TYPE_LOB
    elif oracle_type_num == DPI_ORACLE_TYPE_DATE \
            or oracle_type_num == DPI_ORACLE_TYPE_TIMESTAMP \
            or oracle_type_num == DPI_ORACLE_TYPE_TIMESTAMP_LTZ \
            or oracle_type_num == DPI_ORACLE_TYPE_TIMESTAMP_TZ:
        return DPI_NATIVE_TYPE_TIMESTAMP
    elif oracle_type_num == DPI_ORACLE_TYPE_STMT:
        return DPI_NATIVE_TYPE_STMT
    elif oracle_type_num == DPI_ORACLE_TYPE_NATIVE_INT:
        return DPI_NATIVE_TYPE_INT64
    elif oracle_type_num == DPI_ORACLE_TYPE_OBJECT:
        return DPI_NATIVE_TYPE_OBJECT
    elif oracle_type_num == DPI_ORACLE_TYPE_ROWID:
        return DPI_NATIVE_TYPE_ROWID
    return DPI_NATIVE_TYPE_BYTES


cdef object _create_new_from_info(dpiErrorInfo *error_info):
    """
    Creates a new error object given a dpiErrorInfo structure
    that is already populated with error information.
    """
    cdef bytes msg_bytes = error_info.message[:error_info.messageLength]
    context = "%s: %s" % (error_info.fnName, error_info.action)
    return errors._Error(msg_bytes.decode(), context, code=error_info.code,
                         offset=error_info.offset,
                         isrecoverable=error_info.isRecoverable,
                         iswarning=error_info.isWarning)


cdef int _raise_from_info(dpiErrorInfo *error_info) except -1:
    """
    Raises an exception given a dpiErrorInfo structure that is already
    populated with error information.
    """
    msg_bytes = error_info.message[:error_info.messageLength]
    context = "%s: %s" % (error_info.fnName, error_info.action)
    error = errors._Error(msg_bytes.decode(), context, code=error_info.code,
                          offset=error_info.offset,
                          isrecoverable=bool(error_info.isRecoverable),
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


def clientversion():
    """
    Returns the version of the Oracle Client library being used as a 5-tuple.
    The five values are the major version, minor version, update number, patch
    number and port update number.
    """
    cdef dpiVersionInfo info
    global client_version
    if client_version is None:
        if driver_context == NULL:
            init_oracle_client()
        if dpiContext_getClientVersion(driver_context, &info) < 0:
            _raise_from_odpi()
        client_version = (
            info.versionNum,
            info.releaseNum,
            info.updateNum,
            info.portReleaseNum,
            info.portUpdateNum
        )
    return client_version


def init_oracle_client(lib_dir=None, config_dir=None, error_url=None,
        driver_name=None):
    """
    Initialize the Oracle Client library. This method is available externally
    in order to be called with parameters that control how the Oracle Client
    library is initialized. If not called earlier, the first usage of the
    Oracle Client library will cause this method to be called internally.
    """
    cdef:
        bytes lib_dir_bytes, config_dir_bytes, driver_name_bytes
        dpiContextCreateParams params
        dpiErrorInfo error_info
        bytes encoding_bytes
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
