#------------------------------------------------------------------------------
# Copyright (c) 2020, 2022, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# thick_impl.pyx
#
# Cython file for interfacing with ODPI-C.
#------------------------------------------------------------------------------

# cython: language_level=3

cimport cython
cimport cpython
cimport cpython.datetime as cydatetime

import datetime
import decimal

cydatetime.import_datetime()

from . import constants, driver_mode, errors, exceptions
from .subscr import Message, MessageQuery, MessageRow, MessageTable
from .lob import LOB
from .dbobject import DbObject, DbObjectType
from .var import Var
from .defaults import defaults

from .base_impl cimport get_exception_class
from .base_impl cimport BaseConnImpl, BaseCursorImpl, BaseVarImpl, DbType
from .base_impl cimport BaseDbObjectTypeImpl, BaseDbObjectAttrImpl
from .base_impl cimport BaseDbObjectImpl, BaseLobImpl, BasePoolImpl
from .base_impl cimport BaseSodaDbImpl, BaseSodaCollImpl, BaseSodaDocImpl
from .base_impl cimport BaseSodaDocCursorImpl, BaseQueueImpl
from .base_impl cimport BaseDeqOptionsImpl, BaseEnqOptionsImpl
from .base_impl cimport BaseMsgPropsImpl, BaseSubscrImpl, FetchInfo
from .base_impl cimport ConnectParamsImpl, PoolParamsImpl
from .base_impl cimport NUM_TYPE_FLOAT, NUM_TYPE_INT, NUM_TYPE_DECIMAL
from libc.string cimport memchr, memset

include "impl/thick/odpi.pxd"

cdef dpiContext *driver_context = NULL

driver_context_params = None
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
