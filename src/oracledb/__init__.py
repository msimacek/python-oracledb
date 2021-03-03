#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

from .version import __version__
from .exceptions import *
from .errors import _Error
from .connection import connect, Connection
from .cursor import Cursor
from .pool import create_pool, Pool
from .constants import *
from .constructors import *

from .base_impl import *
from .thick_impl import clientversion, init_oracle_client

LOB = BaseLob
ObjectType = BaseDbObjectType
Object = BaseDbObject

# future object used for managing backwards incompatible changes
class Future:

    def __getattr__(self, name):
        return None

    def __setattr__(self, name, value):
        pass

__future__ = Future()

# aliases for database types (for backwards compatibility)
BFILE = DB_TYPE_BFILE
BLOB = DB_TYPE_BLOB
BOOLEAN = DB_TYPE_BOOLEAN
CLOB = DB_TYPE_CLOB
CURSOR = DB_TYPE_CURSOR
FIXED_CHAR = DB_TYPE_CHAR
FIXED_NCHAR = DB_TYPE_NCHAR
INTERVAL = DB_TYPE_INTERVAL_DS
LONG_BINARY = DB_TYPE_LONG_RAW
LONG_STRING = DB_TYPE_LONG
NATIVE_INT = DB_TYPE_BINARY_INTEGER
NATIVE_FLOAT = DB_TYPE_BINARY_DOUBLE
NCHAR = DB_TYPE_NVARCHAR
OBJECT = DB_TYPE_OBJECT
NCLOB = DB_TYPE_NCLOB
TIMESTAMP = DB_TYPE_TIMESTAMP

# remove unnecessary symbols
del version, exceptions, errors, connection, pool, constants
del constructors, base_impl, thick_impl, thin_impl, utils
