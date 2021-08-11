#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

import datetime

from . import errors

# synonyms for the types mandated by the database API
Binary = bytes
Date = datetime.date
Timestamp = datetime.datetime


def Time(hour: int, minute: int, second: int) -> None:
    """
    Constructor mandated by the database API for creating a time value. Since
    Oracle doesn't support time only values, an exception is raised when this
    method is called.
    """
    errors._raise_err(errors.ERR_TIME_NOT_SUPPORTED)


def DateFromTicks(ticks: float) -> datetime.date:
    """
    Constructor mandated by the database API for creating a date value given
    the number of seconds since the epoch (January 1, 1970). This is equivalent
    to using datetime.date.fromtimestamp() and that should be used instead.
    """
    return datetime.date.fromtimestamp(ticks)


def TimeFromTicks(ticks: float) -> None:
    """
    Constructor mandated by the database API for creating a time value given
    the number of seconds since the epoch (January 1, 1970). Since Oracle
    doesn't support time only values, an exception is raised when this method
    is called.
    """
    errors._raise_err(errors.ERR_TIME_NOT_SUPPORTED)


def TimestampFromTicks(ticks: float) -> datetime.datetime:
    """
    Constructor mandated by the database API for creating a timestamp value
    given the number of seconds since the epoch (January 1, 1970). This is
    equivalent to using datetime.datetime.fromtimestamp() and that should be
    used instead.
    """
    return datetime.datetime.fromtimestamp(ticks)
