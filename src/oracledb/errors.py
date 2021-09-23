#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

from . import exceptions

class _Error:
    """
    Error class which is used for all errors that are raised by the driver.
    """

    def __init__(self, message: str=None, context: str=None,
                 isrecoverable: bool=False, iswarning: bool=False,
                 code: int=0, offset: int=0) -> None:
        self.message = message
        self.context = context
        self.isrecoverable = isrecoverable
        self.iswarning = iswarning
        self.code = code
        self.offset = offset
        if code != 0 or (message is not None and message.startswith("DPI-")):
            if code != 0:
                driver_error_num = ERR_ORACLE_ERROR_XREF.get(code)
            else:
                pos = message.find(":")
                error_num = int(message[4:pos])
                driver_error_num = ERR_DPI_ERROR_XREF.get(error_num)
            if driver_error_num is not None:
                driver_error = _get_error_text(driver_error_num)
                self.message = f"{driver_error}\n{self.message}"

    def __str__(self):
        return self.message


def _get_error_text(error_num: int, **args):
    """
    Return the error text for the driver specific error number.
    """
    message_format = ERR_MESSAGE_FORMATS.get(error_num)
    if message_format is None:
        message_format = "missing error {error_num}"
        args = dict(error_num=error_num)
        error_num = ERR_MISSING_ERROR
    message = message_format.format(**args)
    return f"{ERR_PREFIX}-{error_num:04}: {message}"


def _raise_err(error_num: int, **args):
    """
    Raises a driver specific exception from the specified error number and
    supplied arguments.
    """
    message = _get_error_text(error_num, **args)
    exc_type = ERR_EXCEPTION_TYPES[error_num // 1000]
    raise exc_type(_Error(message)) from None


def _raise_from_string(exc_type: Exception, message: str) -> None:
    """
    Raises an exception from a given string. This ensures that an _Error object
    is created for all exceptions that are raised.
    """
    raise exc_type(_Error(message)) from None


# prefix used for all error messages
ERR_PREFIX = "DPY"

# error numbers that result in InterfaceError
ERR_MISSING_ERROR = 1000
ERR_NOT_CONNECTED = 1001
ERR_NOT_OPEN = 1002
ERR_NOT_A_QUERY = 1003
ERR_NO_STATEMENT_EXECUTED = 1004
ERR_POOL_HAS_BUSY_CONNECTIONS = 1005

# error numbers that result in ProgrammingError
ERR_MESSAGE_HAS_NO_PAYLOAD = 2000
ERR_NO_STATEMENT = 2001
ERR_NO_STATEMENT_PREPARED = 2002
ERR_WRONG_EXECUTE_PARAMETERS_TYPE = 2003
ERR_WRONG_EXECUTEMANY_PARAMETERS_TYPE = 2004
ERR_ARGS_AND_KEYWORD_ARGS = 2005
ERR_MIXED_POSITIONAL_AND_NAMED_BINDS = 2006
ERR_EXPECTING_TYPE = 2007
ERR_WRONG_OBJECT_TYPE = 2008
ERR_WRONG_SCROLL_MODE = 2009
ERR_MIXED_ELEMENT_TYPES = 2010
ERR_WRONG_ARRAY_DEFINITION = 2011
ERR_ARGS_MUST_BE_LIST_OR_TUPLE = 2012
ERR_KEYWORD_ARGS_MUST_BE_DICT = 2013
ERR_DUPLICATED_PARAMETER = 2014
ERR_EXPECTING_VAR = 2015
ERR_INCORRECT_VAR_ARRAYSIZE = 2016
ERR_LIBRARY_ALREADY_INITIALIZED = 2017

# error numbers that result in NotSupportedError
ERR_TIME_NOT_SUPPORTED = 3000
ERR_FEATURE_NOT_SUPPORTED = 3001
ERR_PYTHON_VALUE_NOT_SUPPORTED = 3002
ERR_PYTHON_TYPE_NOT_SUPPORTED = 3003
ERR_SET_ROWID_DIRECTLY = 3004
ERR_ARRAYS_OF_ARRAYS = 3005
ERR_ORACLE_TYPE_NOT_SUPPORTED = 3006
ERR_DB_TYPE_NOT_SUPPORTED = 3007
ERR_UNSUPPORTED_INBAND_NOTIFICATION = 3008
ERR_SELF_BIND_NOT_SUPPORTED = 3009
ERR_SERVER_VERSION_NOT_SUPPORTED = 3010

# error numbers that result in DatabaseError
ERR_TNS_ENTRY_NOT_FOUND = 4000
ERR_NO_PASSWORD = 4001
ERR_COLUMN_TRUNCATED = 4002
ERR_ORACLE_NUMBER_NO_REPR = 4003
ERR_INVALID_NUMBER = 4004
ERR_POOL_NO_CONNECTION_AVAILABLE = 4005
ERR_ARRAY_DML_ROW_COUNTS_NOT_ENABLED = 4006
ERR_INCONSISTENT_DATATYPES = 4007
ERR_INVALID_BIND_NAME = 4008
ERR_WRONG_NUMBER_OF_POSITIONAL_BINDS = 4009
ERR_MISSING_BIND_VALUE = 4010
ERR_CONNECTION_CLOSED = 4011
ERR_NUMBER_WITH_INVALID_EXPONENT = 4012
ERR_NUMBER_STRING_OF_ZERO_LENGTH = 4013
ERR_NUMBER_STRING_TOO_LONG = 4014
ERR_NUMBER_WITH_EMPTY_EXPONENT = 4015
ERR_CONTENT_INVALID_AFTER_NUMBER = 4016
ERR_NO_WALLET_DIRECTORY = 4017
ERR_MISSING_WALLET_FILE = 4018

# error numbers that result in InternalError
ERR_MESSAGE_TYPE_UNKNOWN = 5000
ERR_BUFFER_LENGTH_INSUFFICIENT = 5001

# Oracle error number cross reference
ERR_ORACLE_ERROR_XREF = {
    1005: ERR_NO_PASSWORD,
    24422: ERR_POOL_HAS_BUSY_CONNECTIONS,
    24349: ERR_ARRAY_DML_ROW_COUNTS_NOT_ENABLED,
    24459: ERR_POOL_NO_CONNECTION_AVAILABLE,
    24496: ERR_POOL_NO_CONNECTION_AVAILABLE,
}

# ODPI-C error number cross reference
ERR_DPI_ERROR_XREF = {
    1010: ERR_CONNECTION_CLOSED,
    1043: ERR_INVALID_NUMBER,
    1044: ERR_ORACLE_NUMBER_NO_REPR,
}

# error message exception types (multiples of 1000)
ERR_EXCEPTION_TYPES = {
    1: exceptions.InterfaceError,
    2: exceptions.ProgrammingError,
    3: exceptions.NotSupportedError,
    4: exceptions.DatabaseError,
    5: exceptions.InternalError
}

# error message formats
ERR_MESSAGE_FORMATS = {
    ERR_ARGS_MUST_BE_LIST_OR_TUPLE: "arguments must be a list or tuple",
    ERR_ARGS_AND_KEYWORD_ARGS: \
            "expecting arguments or keyword arguments, not both",
    ERR_ARRAY_DML_ROW_COUNTS_NOT_ENABLED: \
            "array DML row counts is not enabled",
    ERR_ARRAYS_OF_ARRAYS: "arrays of arrays are not supported",
    ERR_BUFFER_LENGTH_INSUFFICIENT: \
            "split buffer of length {actual_buffer_len} insufficient to " \
            "hold {required_buffer_len} bytes",
    ERR_COLUMN_TRUNCATED: "column truncated to {col_value_len} {unit} " \
            "(actual is {actual_len})",
    ERR_CONTENT_INVALID_AFTER_NUMBER: "invalid number (content after number)",
    ERR_DB_TYPE_NOT_SUPPORTED: "Database type {name} not supported",
    ERR_DUPLICATED_PARAMETER: \
            "{deprecated_name} and {new_name} cannot both be specified",
    ERR_EXPECTING_TYPE: "expecting type",
    ERR_EXPECTING_VAR: "output type handler should return None or the value " \
                       "returned by a call to cursor.var()",
    ERR_FEATURE_NOT_SUPPORTED: \
            "{feature} is only supported by the {driver_type} driver",
    ERR_INCONSISTENT_DATATYPES: \
            "cannot convert from type {input_type} to {output_type}",
    ERR_INCORRECT_VAR_ARRAYSIZE: "variable array size of {var_arraysize} is " \
                                 "too small (should be at least " \
                                 "{required_arraysize})",
    ERR_INVALID_BIND_NAME: "invalid named bind: {name}",
    ERR_INVALID_NUMBER: "invalid number",
    ERR_KEYWORD_ARGS_MUST_BE_DICT: "keyword arguments must be a dict",
    ERR_LIBRARY_ALREADY_INITIALIZED: \
            "Oracle Client library has already been initialized",
    ERR_MESSAGE_HAS_NO_PAYLOAD: "message has no payload",
    ERR_MESSAGE_TYPE_UNKNOWN: \
            "protocol error: unknown message type: {message_type}",
    ERR_MISSING_BIND_VALUE: "bind value for: {name} missing",
    ERR_MISSING_WALLET_FILE: "wallet file missing: {name}",
    ERR_MIXED_ELEMENT_TYPES: \
            "element {element} is not the same type as previous elements",
    ERR_MIXED_POSITIONAL_AND_NAMED_BINDS: \
            "positional and named binds cannot be intermixed",
    ERR_NO_PASSWORD: "no password specified",
    ERR_NO_STATEMENT: "no statement specified and no prior statement prepared",
    ERR_NO_STATEMENT_EXECUTED: "no statement executed",
    ERR_NO_STATEMENT_PREPARED: "statement must be prepared first",
    ERR_NOT_A_QUERY: "not a query",
    ERR_NO_WALLET_DIRECTORY: "unable to determine wallet directory",
    ERR_NOT_CONNECTED: "not connected",
    ERR_NOT_OPEN: "not open",
    ERR_NUMBER_STRING_OF_ZERO_LENGTH: "invalid number (zero length string)",
    ERR_NUMBER_STRING_TOO_LONG: "invalid number (too long)",
    ERR_NUMBER_WITH_EMPTY_EXPONENT: "invalid number (exponent empty)",
    ERR_NUMBER_WITH_INVALID_EXPONENT: "invalid number (exponent invalid)",
    ERR_ORACLE_NUMBER_NO_REPR: "value cannot be represented as an Oracle " \
                               "number",
    ERR_ORACLE_TYPE_NOT_SUPPORTED: "Oracle type {num} not supported",
    ERR_POOL_HAS_BUSY_CONNECTIONS: \
            "pool cannot be destroyed because it has busy connections",
    ERR_POOL_NO_CONNECTION_AVAILABLE: \
            "timed out waiting for pool to have free connections available " \
            "or create new connections",
    ERR_PYTHON_TYPE_NOT_SUPPORTED: "Python type {typ} not supported",
    ERR_PYTHON_VALUE_NOT_SUPPORTED: \
            "Python value of type {type_name} not supported",
    ERR_SELF_BIND_NOT_SUPPORTED: "binding to self not supported",
    ERR_CONNECTION_CLOSED: "connection to database has been closed",
    ERR_SERVER_VERSION_NOT_SUPPORTED: \
            "connections to this server version are not supported with " \
            "the thin driver",
    ERR_SET_ROWID_DIRECTLY: "rowid variables cannot be set directly",
    ERR_TIME_NOT_SUPPORTED: "Oracle does not support time only variables",
    ERR_TNS_ENTRY_NOT_FOUND: "unable to find TNS entry name {val}",
    ERR_UNSUPPORTED_INBAND_NOTIFICATION: \
            "unsupported in-band notification with error number {err_num}",
    ERR_WRONG_ARRAY_DEFINITION: \
            "expecting a list of two elements [type, numelems]",
    ERR_WRONG_EXECUTE_PARAMETERS_TYPE: \
            "expecting a dictionary, list or tuple, or keyword args",
    ERR_WRONG_EXECUTEMANY_PARAMETERS_TYPE: \
            "parameters should be a list of sequences or " \
            "dictionaries, or an integer specifying the number of " \
            "times to execute the statement",
    ERR_WRONG_NUMBER_OF_POSITIONAL_BINDS: \
            "{expected_num} positional bind(s) required but only " \
            "{actual_num} positional bind(s) provided.",
    ERR_WRONG_OBJECT_TYPE: \
            "found object of type {actual_schema}.{actual_name} " \
            "when expecting object of type {expected_schema}.{expected_name}",
    ERR_WRONG_SCROLL_MODE: \
            "mode must be one of relative, absolute, first or last",
}
