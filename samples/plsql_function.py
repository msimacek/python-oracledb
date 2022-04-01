#------------------------------------------------------------------------------
# Copyright (c) 2016, 2022, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# plsql_function.py
#
# Demonstrates how to call a PL/SQL function and get its return value.
#------------------------------------------------------------------------------

import oracledb
import sample_env

# determine whether to use python-oracledb thin mode or thick mode
if not sample_env.get_is_thin():
    oracledb.init_oracle_client()

connection = oracledb.connect(sample_env.get_main_connect_string())

cursor = connection.cursor()
res = cursor.callfunc('myfunc', int, ('abc', 2))
print(res)
