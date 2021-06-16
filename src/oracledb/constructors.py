#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

import datetime

from . import errors
from . import exceptions
from typing import Type

def Binary(value: object) -> bytes:
    """
    Constructor mandated by the database API for creating a binary value. This
    is merely a wrapper over the bytes class and that should be used instead.
    """
    return bytes(value)


def Date(year: int, month: int, day: int) -> datetime.date:
    """
    Constructor mandated by the database API for creating a date value. This is
    merely a wrapper over the datetime.date class and that should be used
    instead.
    """
    return datetime.date(year, month, day)


def Time(hour: int, minute: int, second: int) -> None:
    """
    Constructor mandated by the database API for creating a time value. Since
    Oracle doesn't support time only values, an exception is raised when this
    method is called.
    """
    errors._raise_from_string(exceptions.NotSupportedError,
                              "Oracle does not support time only variables")


def Timestamp(year: int, month: int, day: int, hour: int=0, minute: int=0,
              second: int=0, fsecond: int=0) -> datetime.datetime:
    """
    Constructor mandated by the database API for creating a timestamp value.
    This is merely a wrapper over the datetime.datetime class and that should
    be used instead.
    """
    return datetime.datetime(year, month, day, hour, minute, second, fsecond)


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
    errors._raise_from_string(exceptions.NotSupportedError,
                              "Oracle does not support time only variables")


def TimestampFromTicks(ticks: float) -> datetime.datetime:
    """
    Constructor mandated by the database API for creating a timestamp value
    given the number of seconds since the epoch (January 1, 1970). This is
    equivalent to using datetime.datetime.fromtimestamp() and that should be
    used instead.
    """
    return datetime.datetime.fromtimestamp(ticks)
