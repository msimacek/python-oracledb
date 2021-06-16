#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

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


def _raise_from_string(exc_type: Exception, message: str) -> None:
    """
    Raises an exception from a given string. This ensures that an _Error object
    is created for all exceptions that are raised.
    """
    raise exc_type(_Error(message)) from None
