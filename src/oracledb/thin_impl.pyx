#------------------------------------------------------------------------------
# Copyright (c) 2020, 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# thin_impl.pyx
#   Cython file for communicating with the server directly without the use of
# any Oracle Client library.
#------------------------------------------------------------------------------

# cython: language_level=3

cimport cython
cimport cpython
cimport cpython.datetime as cydatetime
cimport cpython.ref

from libc.stdint cimport int8_t, int16_t, int32_t, int64_t
from libc.stdint cimport uint8_t, uint16_t, uint32_t, uint64_t
from libc.stdint cimport UINT8_MAX, UINT16_MAX, UINT32_MAX, UINT64_MAX
from cpython cimport array

import array
import collections
import datetime
import decimal
import getpass
import hashlib
import os
import socket
import re
import secrets
import ssl
import sys
import threading
import time

cydatetime.import_datetime()

from . import constants, errors, exceptions
from .defaults import defaults

from .base_impl cimport get_exception_class, NUM_TYPE_FLOAT
from .base_impl cimport NUM_TYPE_INT, NUM_TYPE_DECIMAL, NUM_TYPE_STR
from .base_impl cimport BaseConnImpl, BaseCursorImpl, BaseVarImpl, DbType
from .base_impl cimport BaseLobImpl, BasePoolImpl, FetchInfo
from .base_impl import DB_TYPE_BLOB, DB_TYPE_CLOB, DB_TYPE_NCLOB
from .cursor import Cursor
from .lob import LOB
from .var import Var

include "impl/thin/constants.pxi"
include "impl/thin/utils.pyx"
include "impl/thin/crypto.pyx"
include "impl/thin/capabilities.pyx"
include "impl/thin/buffer.pyx"
include "impl/thin/network_services.pyx"
include "impl/thin/data_types.pyx"
include "impl/thin/messages.pyx"
include "impl/thin/protocol.pyx"
include "impl/thin/connection.pyx"
include "impl/thin/statement.pyx"
include "impl/thin/cursor.pyx"
include "impl/thin/var.pyx"
include "impl/thin/lob.pyx"
include "impl/thin/pool.pyx"
include "impl/thin/conversions.pyx"
