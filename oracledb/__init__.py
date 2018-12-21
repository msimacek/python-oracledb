#------------------------------------------------------------------------------
# Copyright (c) 2018, Oracle and/or its affiliates. All rights reserved.
#
# Licensed under BSD license (see LICENSE.txt).
#------------------------------------------------------------------------------

__version__ = '0.0.1'

DRIVER_NAME = "py-oracledb : " + __version__

from _oracledb import \
    Warning, Error, InterfaceError, DatabaseError, DataError, \
    OperationalError, IntegrityError, InternalError, ProgrammingError, \
    NotSupportedError
from .connection import *

