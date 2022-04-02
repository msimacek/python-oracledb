#------------------------------------------------------------------------------
# Copyright (c) 2017, 2022, Oracle and/or its affiliates.
#
# Portions Copyright 2007-2015, Anthony Tuininga. All rights reserved.
#
# Portions Copyright 2001-2007, Computronix (Canada) Ltd., Edmonton, Alberta,
# Canada. All rights reserved.
#
# This program is free software: you can modify it and/or redistribute it
# under the terms of:
#
# (i)  the Universal Permissive License v 1.0 or at your option, any
#      later version (http://oss.oracle.com/licenses/upl); and/or
#
# (ii) the Apache License v 2.0. (http://www.apache.org/licenses/LICENSE-2.0)
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# dml_returning_multiple_rows.py
#
# Demonstrates the use of DML returning with multiple rows being returned at
# once.
#------------------------------------------------------------------------------

import oracledb
import sample_env

# determine whether to use python-oracledb thin mode or thick mode
if not sample_env.get_is_thin():
    oracledb.init_oracle_client()

# truncate table first so that script can be rerun
connection = oracledb.connect(sample_env.get_main_connect_string())
cursor = connection.cursor()
print("Truncating table...")
cursor.execute("truncate table TestTempTable")

# populate table with a few rows
for i in range(5):
    data = (i + 1, "Test String #%d" % (i + 1))
    print("Adding row", data)
    cursor.execute("insert into TestTempTable values (:1, :2)", data)

# now delete them and use DML returning to return the data that was inserted
int_col = cursor.var(int)
string_col = cursor.var(str)
print("Deleting data with DML returning...")
cursor.execute("""
        delete from TestTempTable
        returning IntCol, StringCol into :int_col, :string_col""",
        int_col=int_col,
        string_col=string_col)
print("Data returned:")
for int_val, string_val in zip(int_col.getvalue(), string_col.getvalue()):
    print(tuple([int_val, string_val]))
