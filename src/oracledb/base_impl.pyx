#------------------------------------------------------------------------------
# Copyright (c) 2020, 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# base_impl.pyx
#   Cython file for the base implementation that the thin and thick
# implementations use.
#------------------------------------------------------------------------------

# cython: language_level=3

cimport cython
cimport cpython

from libc.stdint cimport int8_t, int16_t, int32_t, int64_t
from libc.stdint cimport uint8_t, uint16_t, uint32_t, uint64_t

import datetime
import decimal
import json
import sys

from . import constants, errors, exceptions
from .cursor import Cursor
from .lob import LOB

cdef int32_t* INTEGRITY_ERROR_CODES = [
        1,          # unique constraint violated
        1400,       # cannot insert NULL
        2290,       # check constraint violated
        2291,       # integrity constraint violated - parent key not found
        2292,       # integrity constraint violated - child record found
        40479,      # internal JSON serializer error
        0
]

cdef int32_t* OPERATIONAL_ERROR_CODES = [
        22,         # invalid session ID; access denied
        378,        # buffer pools cannot be created as specified
        600,        # internal error code
        602,        # internal programming exception
        603,        # ORACLE server session terminated by fatal error
        604,        # error occurred at recursive SQL level
        609,        # could not attach to incoming connection
        1012,       # not logged on
        1013,       # user requested cancel of current operation
        1033,       # ORACLE initialization or shutdown in progress
        1034,       # ORACLE not available
        1041,       # internal error. hostdef extension doesn't exist
        1043,       # user side memory corruption
        1089,       # immediate shutdown or close in progress
        1090,       # shutdown in progress - connection is not permitted
        1092,       # ORACLE instance terminated. Disconnection forced
        3113,       # end-of-file on communication channel
        3114,       # not connected to ORACLE
        3122,       # attempt to close ORACLE-side window on user side
        3135,       # connection lost contact
        12153,      # TNS:not connected
        12203,      # TNS:unable to connect to destination
        12500,      # TNS:listener failed to start a dedicated server process
        12571,      # TNS:packet writer failure
        27146,      # post/wait initialization failed
        28511,      # lost RPC connection to heterogeneous remote agent
        0
]


cdef int is_code_in_array(int32_t code, int32_t *ptr):
    cdef int ix = 0
    while ptr[ix] != 0:
        if ptr[ix] == code:
            return 1
        ix += 1
    return 0


cdef object get_exception_class(int32_t code):
    if is_code_in_array(code, INTEGRITY_ERROR_CODES):
        return exceptions.IntegrityError
    if is_code_in_array(code, OPERATIONAL_ERROR_CODES):
        return exceptions.OperationalError
    return exceptions.DatabaseError


include "impl/base/connection.pyx"
include "impl/base/pool.pyx"
include "impl/base/cursor.pyx"
include "impl/base/var.pyx"
include "impl/base/dbobject.pyx"
include "impl/base/lob.pyx"
include "impl/base/soda.pyx"
include "impl/base/queue.pyx"
include "impl/base/subscr.pyx"
include "impl/base/types.pyx"
