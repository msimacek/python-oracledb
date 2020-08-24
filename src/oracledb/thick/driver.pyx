#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# driver.pyx
#   Cython file for interfacing with ODPI-C.
#------------------------------------------------------------------------------

# cython: language_level=3

cimport cython
cimport cpython
cimport cpython.datetime as cydatetime

import datetime
import decimal

cydatetime.import_datetime()

from .. import constants, errors, exceptions

from ..common.driver cimport get_exception_class
from ..common.driver cimport BaseConnection, BaseCursor, BaseVar, DbType
from libc.string cimport memchr, memset

include "odpi.pxd"

cdef dpiContext *driver_context = NULL

include "connection.pyx"
include "cursor.pyx"
include "var.pyx"
include "utils.pyx"
