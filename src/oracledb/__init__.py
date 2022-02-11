#------------------------------------------------------------------------------
# Copyright (c) 2020, 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

from .version import __version__
from .exceptions import *
from .errors import _Error
from .defaults import defaults
from .connect_params import ConnectParams
from .connection import connect, Connection
from .cursor import Cursor
from .pool import create_pool, ConnectionPool
from .lob import LOB
from .dbobject import DbObject, DbObjectType
from .constants import *
from .constructors import *
from .dsn import makedsn

from .base_impl import *
from .thick_impl import clientversion, init_oracle_client

# future object used for managing backwards incompatible changes
class Future:

    def __getattr__(self, name):
        return None

    def __setattr__(self, name, value):
        pass

__future__ = Future()

# remove unnecessary symbols
del exceptions, errors, connection, pool, constants
del constructors, base_impl, thick_impl, thin_impl, utils

# general aliases (for backwards compatibility)
ObjectType = DbObjectType
Object = DbObject
SessionPool = ConnectionPool
version = __version__

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

# aliases for authhentication modes (for backwards compatibility)
DEFAULT_AUTH = AUTH_MODE_DEFAULT
SYSASM = AUTH_MODE_SYSASM
SYSBKP = AUTH_MODE_SYSBKP
SYSDBA = AUTH_MODE_SYSDBA
SYSDGD = AUTH_MODE_SYSDGD
SYSKMT = AUTH_MODE_SYSKMT
SYSOPER = AUTH_MODE_SYSOPER
SYSRAC = AUTH_MODE_SYSRAC
PRELIM_AUTH = AUTH_MODE_PRELIM

# aliases for pool "get" modes (for backwards compatibility)
SPOOL_ATTRVAL_WAIT = POOL_GETMODE_WAIT
SPOOL_ATTRVAL_NOWAIT = POOL_GETMODE_NOWAIT
SPOOL_ATTRVAL_FORCEGET = POOL_GETMODE_FORCEGET
SPOOL_ATTRVAL_TIMEDWAIT = POOL_GETMODE_TIMEDWAIT

# aliases for purity (for backwards compatibility)
ATTR_PURITY_DEFAULT = PURITY_DEFAULT
ATTR_PURITY_NEW = PURITY_NEW
ATTR_PURITY_SELF = PURITY_ANY

# aliases for subscription protocols (for backwards compatibility)
SUBSCR_PROTOCOL_OCI = SUBSCR_PROTOCOL_CALLBACK
