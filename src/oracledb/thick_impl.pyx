#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# thick_impl.pyx
#   Cython file for interfacing with ODPI-C.
#------------------------------------------------------------------------------

# cython: language_level=3

cimport cython
cimport cpython
cimport cpython.datetime as cydatetime

import datetime
import decimal

cydatetime.import_datetime()

from . import constants, errors, exceptions

from .base_impl cimport get_exception_class
from .base_impl cimport BaseConnection, BaseCursor, BaseVar, DbType
from .base_impl cimport BaseDbObjectType, BaseDbObjectAttr, BaseDbObject
from .base_impl cimport BaseLob, BasePool, BaseSodaDatabase
from .base_impl cimport BaseSodaCollection, BaseSodaDoc, BaseSodaDocCursor
from .base_impl cimport BaseSodaOperation, BaseQueue, BaseDeqOptions
from .base_impl cimport BaseEnqOptions, BaseMsgProps, BaseSubscription
from .base_impl cimport Message, MessageQuery, MessageRow, MessageTable
from .base_impl cimport NUM_TYPE_FLOAT, NUM_TYPE_INT, NUM_TYPE_DECIMAL
from libc.string cimport memchr, memset

include "impl/thick/odpi.pxd"

cdef dpiContext *driver_context = NULL

client_version = None

include "impl/thick/buffer.pyx"
include "impl/thick/connection.pyx"
include "impl/thick/pool.pyx"
include "impl/thick/cursor.pyx"
include "impl/thick/lob.pyx"
include "impl/thick/json.pyx"
include "impl/thick/var.pyx"
include "impl/thick/dbobject.pyx"
include "impl/thick/soda.pyx"
include "impl/thick/queue.pyx"
include "impl/thick/subscr.pyx"
include "impl/thick/utils.pyx"
