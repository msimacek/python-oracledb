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
from ..common.driver cimport BaseDbObjectType, BaseDbObjectAttr, BaseDbObject
from ..common.driver cimport BaseLob, BasePool, BaseSodaDatabase
from ..common.driver cimport BaseSodaCollection, BaseSodaDoc, BaseSodaDocCursor
from ..common.driver cimport BaseSodaOperation, BaseQueue, BaseDeqOptions
from ..common.driver cimport BaseEnqOptions, BaseMsgProps, BaseSubscription
from ..common.driver cimport Message, MessageQuery, MessageRow, MessageTable
from libc.string cimport memchr, memset

include "odpi.pxd"

cdef dpiContext *driver_context = NULL

client_version = None

include "buffer.pyx"
include "connection.pyx"
include "pool.pyx"
include "cursor.pyx"
include "lob.pyx"
include "json.pyx"
include "var.pyx"
include "dbobject.pyx"
include "soda.pyx"
include "queue.pyx"
include "subscr.pyx"
include "utils.pyx"
