#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

import datetime
import time

from . import errors
from . import exceptions

def Binary(value):
    return bytes(value)

def Date(year, month, day):
    return datetime.date(year, month, day)

def Time(hour, minute, second):
    errors._raise_from_string(exceptions.NotSupportedError,
                              "Oracle does not support time only variables")

def Timestamp(year, month, day, hour=0, minute=0, second=0):
    return datetime.datetime(year, month, day, hour, minute, second)

def DateFromTicks(ticks):
    return Date(*time.localtime(ticks)[:3])

def TimeFromTicks(ticks):
    return Time(*time.localtime(ticks)[3:6])

def TimestampFromTicks(ticks):
    return Timestamp(*time.localtime(ticks)[:6])
