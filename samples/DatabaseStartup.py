#------------------------------------------------------------------------------
# Copyright (c) 2016, 2020, Oracle and/or its affiliates. All rights reserved.
#
# Portions Copyright 2007-2015, Anthony Tuininga. All rights reserved.
#
# Portions Copyright 2001-2007, Computronix (Canada) Ltd., Edmonton, Alberta,
# Canada. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# DatabaseStartup.py
#   This script demonstrates starting up a database using Python. It is only
# possible in Oracle 10g Release 2 and higher. The connection used assumes that
# the environment variable ORACLE_SID has been set.
# 
# Currently, this script runs with the thick driver only.
#------------------------------------------------------------------------------

import oracledb

# the connection must be in PRELIM_AUTH mode
connection = oracledb.connect("/", thin=False,
                              mode=oracledb.SYSDBA | oracledb.PRELIM_AUTH)
connection.startup()

# the following statements must be issued in normal SYSDBA mode
connection = oracledb.connect("/", thin=False, mode=oracledb.SYSDBA)
cursor = connection.cursor()
cursor.execute("alter database mount")
cursor.execute("alter database open")
