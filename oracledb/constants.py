#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#
# Licensed under BSD license (see LICENSE.txt).
#------------------------------------------------------------------------------

import cx_Oracle as _oracledb

# pool get modes
POOL_GET_MODE_WAIT = _oracledb.SPOOL_ATTRVAL_WAIT
POOL_GET_MODE_NO_WAIT = _oracledb.SPOOL_ATTRVAL_NOWAIT
POOL_GET_MODE_FORCE = _oracledb.SPOOL_ATTRVAL_FORCEGET
POOL_GET_MODE_TIMED_WAIT = _oracledb.SPOOL_ATTRVAL_TIMEDWAIT

# pool get purity values
POOL_GET_PURITY_DEFAULT = _oracledb.ATTR_PURITY_DEFAULT
POOL_GET_PURITY_NEW = _oracledb.ATTR_PURITY_NEW
POOL_GET_PURITY_SELF = _oracledb.ATTR_PURITY_SELF
