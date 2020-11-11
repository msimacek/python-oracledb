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

# AQ delivery modes
MSG_BUFFERED =  2
MSG_PERSISTENT = 1
MSG_PERSISTENT_OR_BUFFERED = 3

# AQ deque modes
DEQ_BROWSE = 1
DEQ_LOCKED = 2
DEQ_REMOVE = 3
DEQ_REMOVE_NODATA = 4

# AQ dequeue navigation modes
DEQ_FIRST_MSG = 1
DEQ_NEXT_MSG = 3
DEQ_NEXT_TRANSACTION = 2

# AQ dequeue visibility modes
DEQ_IMMEDIATE = 1
DEQ_ON_COMMIT = 2

# AQ dequeue wait modes
DEQ_NO_WAIT = 0
DEQ_WAIT_FOREVER = 2 ** 32 - 1

# AQ enqueue visibility modes
ENQ_IMMEDIATE = 1
ENQ_ON_COMMIT = 2

# AQ message states
MSG_EXPIRED = 3
MSG_PROCESSED = 2
MSG_READY = 0
MSG_WAITING = 1

# AQ other constants
MSG_NO_DELAY = 0
MSG_NO_EXPIRATION = -1

# subscription grouping classes
SUBSCR_GROUPING_CLASS_NONE = 0
SUBSCR_GROUPING_CLASS_TIME = 1

# subscription grouping types
SUBSCR_GROUPING_TYPE_SUMMARY = 1
SUBSCR_GROUPING_TYPE_LAST = 2

# subscription namespaces
SUBSCR_NAMESPACE_AQ = 1
SUBSCR_NAMESPACE_DBCHANGE = 2

# subscription protocols
SUBSCR_PROTOCOL_HTTP = 3
SUBSCR_PROTOCOL_MAIL = 1
SUBSCR_PROTOCOL_CALLBACK = 0
SUBSCR_PROTOCOL_SERVER = 2

# aliases for subscription protocols
SUBSCR_PROTOCOL_OCI = SUBSCR_PROTOCOL_CALLBACK

# subscription quality of service
SUBSCR_QOS_BEST_EFFORT = 0x10
SUBSCR_QOS_DEFAULT = 0
SUBSCR_QOS_DEREG_NFY = 0x02
SUBSCR_QOS_QUERY = 0x08
SUBSCR_QOS_RELIABLE = 0x01
SUBSCR_QOS_ROWIDS = 0x04

# event types
EVENT_AQ = 100
EVENT_DEREG = 5
EVENT_NONE = 0
EVENT_OBJCHANGE = 6
EVENT_QUERYCHANGE = 7
EVENT_SHUTDOWN = 2
EVENT_SHUTDOWN_ANY = 3
EVENT_STARTUP = 1

# operation codes
OPCODE_ALLOPS = 0
OPCODE_ALLROWS = 0x01
OPCODE_ALTER = 0x10
OPCODE_DELETE = 0x08
OPCODE_DROP = 0x20
OPCODE_INSERT = 0x02
OPCODE_UPDATE = 0x04

# basic configuration constants
DRIVER_NAME = "oracledb : " + VERSION
INSTALLATION_URL = "https://oracledb.readthedocs.io/en/" \
        "latest/user_guide/installation.html"
ENCODING = "UTF-8"
