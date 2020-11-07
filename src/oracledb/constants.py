#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

from . import __version__ as VERSION

# mandated DB API constants
apilevel = "2.0"
threadsafety = 2
paramstyle = "named"

# authentication modes
DEFAULT_AUTH = 0
SYSASM = 0x00008000
SYSBKP = 0x00020000
SYSDBA = 0x00000002
SYSDGD = 0x00040000
SYSKMT = 0x00080000
SYSOPER = 0x00000004
SYSRAC = 0x00100000
PRELIM_AUTH = 0x00000008

# pool "get" modes
POOL_GETMODE_WAIT = 0
POOL_GETMODE_NOWAIT = 1
POOL_GETMODE_FORCEGET = 2
POOL_GETMODE_TIMEDWAIT = 3

# pool "get" mode aliases
SPOOL_ATTRVAL_WAIT = POOL_GETMODE_WAIT
SPOOL_ATTRVAL_NOWAIT = POOL_GETMODE_NOWAIT
SPOOL_ATTRVAL_FORCEGET = POOL_GETMODE_FORCEGET
SPOOL_ATTRVAL_TIMEDWAIT = POOL_GETMODE_TIMEDWAIT

# purity values
PURITY_DEFAULT = 0
PURITY_NEW = 1
PURITY_ANY = 2

# purity aliases
ATTR_PURITY_DEFAULT = PURITY_DEFAULT
ATTR_PURITY_NEW = PURITY_NEW
ATTR_PURITY_SELF = PURITY_ANY

# session purity
ATTR_PURITY_DEFAULT = 0
ATTR_PURITY_NEW = 1
ATTR_PURITY_SELF = 2

# basic configuration constants
DRIVER_NAME = "oracledb : " + VERSION
INSTALLATION_URL = "https://oracledb.readthedocs.io/en/" \
        "latest/user_guide/installation.html"
ENCODING = "UTF-8"
