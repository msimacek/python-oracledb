#------------------------------------------------------------------------------
# Copyright (c) 2016, 2022, Oracle and/or its affiliates.
#
# Portions Copyright 2007-2015, Anthony Tuininga. All rights reserved.
#
# Portions Copyright 2001-2007, Computronix (Canada) Ltd., Edmonton, Alberta,
# Canada. All rights reserved.
# This program is free software: you can modify it and/or redistribute it
# under the terms of:
#
# (i)  the Universal Permissive License v 1.0 or at your option, any
#      later version (http://oss.oracle.com/licenses/upl); and/or
#
# (ii) the Apache License v 2.0. (http://www.apache.org/licenses/LICENSE-2.0)
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# database_startup.py
#
# Demonstrates starting up a database using Python. The connection used
# assumes that the environment variable ORACLE_SID has been set.
#------------------------------------------------------------------------------

import oracledb

# this script is currently only supported in python-oracledb thick mode
oracledb.init_oracle_client()

# the connection must be in PRELIM_AUTH mode
connection = oracledb.connect(mode=oracledb.SYSDBA | oracledb.PRELIM_AUTH)
connection.startup()

# the following statements must be issued in normal SYSDBA mode
connection = oracledb.connect(mode=oracledb.SYSDBA)
cursor = connection.cursor()
cursor.execute("alter database mount")
cursor.execute("alter database open")
