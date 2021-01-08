#------------------------------------------------------------------------------
# Copyright (c) 2016, 2020, Oracle and/or its affiliates. All rights reserved.
#
# Portions Copyright 2007-2015, Anthony Tuininga. All rights reserved.
#
# Portions Copyright 2001-2007, Computronix (Canada) Ltd., Edmonton, Alberta,
# Canada. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# DRCP.py
#   This script demonstrates the use of Database Resident Connection Pooling
# (DRCP) which provides a connection pool in the database server, thereby
# reducing the cost of creating and tearing down client connections. The pool
# can be started and stopped in the database by issuing the following commands
# in SQL*Plus:
#
#   exec dbms_connection_pool.start_pool()
#   exec dbms_connection_pool.stop_pool()
#
# Statistics regarding the pool can be acquired from the following query:
#
#   select * from v$cpool_cc_stats;
#
# There is no difference in how a connection is used once it has been
# established.
#
# DRCP has most benefit when used in conjunction with a local connection pool,
# see the oracledb documentation.
#
#------------------------------------------------------------------------------

import oracledb
import sample_env

conn = oracledb.connect(sample_env.get_drcp_connect_string(),
                        thin=sample_env.get_is_thin(),
                        cclass="PYCLASS", purity=oracledb.ATTR_PURITY_SELF)
cursor = conn.cursor()
print("Performing query using DRCP...")
for row in cursor.execute("select * from TestNumbers order by IntCol"):
    print(row)
