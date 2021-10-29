#------------------------------------------------------------------------------
# Copyright (c) 2016, 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# plsql_procedure.py
#
# Demonstrate how to call a PL/SQL stored procedure and get the results of an
# OUT variable.
#------------------------------------------------------------------------------

import oracledb
import sample_env

# determine whether to use thin driver or not
if not sample_env.get_is_thin():
    oracledb.init_oracle_client()

connection = oracledb.connect(sample_env.get_main_connect_string())

cursor = connection.cursor()
myvar = cursor.var(int)
cursor.callproc('myproc', (123, myvar))
print(myvar.getvalue())
