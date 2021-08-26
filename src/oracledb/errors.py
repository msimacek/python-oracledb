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

    def __str__(self):
        return self.message


def _raise_err(error_num: int, **args):
    message_format = ERR_MESSAGE_FORMATS.get(error_num)
    if message_format is None:
        message_format = "missing error {error_num}"
        args = dict(error_num=error_num)
        exc_type = exceptions.InternalError
        error_num = ERR_MISSING_ERROR
    exc_type = ERR_EXCEPTION_TYPES[error_num // 1000]
    message = message_format.format(**args)
    full_message = f"{ERR_PREFIX}-{error_num:04}: {message}"
    raise exc_type(_Error(full_message)) from None


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

# error numbers that result in NotSupportedError
ERR_TIME_NOT_SUPPORTED = 3000
ERR_FEATURE_NOT_SUPPORTED = 3001
ERR_PYTHON_VALUE_NOT_SUPPORTED = 3002
ERR_PYTHON_TYPE_NOT_SUPPORTED = 3003
ERR_SET_ROWID_DIRECTLY = 3004
ERR_ARRAYS_OF_ARRAYS = 3005
ERR_ORACLE_TYPE_NOT_SUPPORTED = 3006

# error message exception types (multiples of 1000)
ERR_EXCEPTION_TYPES = {
    1: exceptions.InterfaceError,
    2: exceptions.ProgrammingError,
    3: exceptions.NotSupportedError
}

# error message formats
ERR_MESSAGE_FORMATS = {
    ERR_ARGS_MUST_BE_LIST_OR_TUPLE: "arguments must be a list or tuple",
    ERR_ARGS_AND_KEYWORD_ARGS: \
            "expecting arguments or keyword arguments, not both",
    ERR_ARRAYS_OF_ARRAYS: "arrays of arrays are not supported",
    ERR_DUPLICATED_PARAMETER: \
            "{deprecated_name} and {new_name} cannot both be specified",
    ERR_EXPECTING_TYPE: "expecting type",
    ERR_EXPECTING_VAR: "output type handler should return None or the value " \
                       "returned by a call to cursor.var()",
    ERR_FEATURE_NOT_SUPPORTED: \
            "{feature} is only supported by the {driver_type} driver",
    ERR_INCORRECT_VAR_ARRAYSIZE: "variable array size of {var_arraysize} is " \
                                 "too small (should be at least " \
                                 "{required_arraysize})",
    ERR_KEYWORD_ARGS_MUST_BE_DICT: "keyword arguments must be a dict",
    ERR_MESSAGE_HAS_NO_PAYLOAD: "message has no payload",
    ERR_MIXED_ELEMENT_TYPES: \
            "element {element} is not the same type as previous elements",
    ERR_MIXED_POSITIONAL_AND_NAMED_BINDS: \
            "positional and named binds cannot be intermixed",
    ERR_NO_STATEMENT: "no statement specified and no prior statement prepared",
    ERR_NO_STATEMENT_EXECUTED: "no statement executed",
    ERR_NO_STATEMENT_PREPARED: "statement must be prepared first",
    ERR_NOT_A_QUERY: "not a query",
    ERR_NOT_CONNECTED: "not connected",
    ERR_NOT_OPEN: "not open",
    ERR_ORACLE_TYPE_NOT_SUPPORTED: "Oracle type {num} not supported",
    ERR_PYTHON_TYPE_NOT_SUPPORTED: "Python type {typ} not supported",
    ERR_PYTHON_VALUE_NOT_SUPPORTED: \
            "Python value of type {type_name} not supported",
    ERR_SET_ROWID_DIRECTLY: "rowid variables cannot be set directly",
    ERR_TIME_NOT_SUPPORTED: "Oracle does not support time only variables",
    ERR_WRONG_ARRAY_DEFINITION: \
            "expecting a list of two elements [type, numelems]",
    ERR_WRONG_EXECUTE_PARAMETERS_TYPE: \
            "expecting a dictionary, list or tuple, or keyword args",
    ERR_WRONG_EXECUTEMANY_PARAMETERS_TYPE: \
            "parameters should be a list of sequences or " \
            "dictionaries, or an integer specifying the number of " \
            "times to execute the statement",
    ERR_WRONG_OBJECT_TYPE: \
            "found object of type {actual_schema}.{actual_name} " \
            "when expecting object of type {expected_schema}.{expected_name}",
    ERR_WRONG_SCROLL_MODE: \
            "mode must be one of relative, absolute, first or last",
}
