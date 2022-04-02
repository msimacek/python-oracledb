#------------------------------------------------------------------------------
# Copyright (c) 2016, 2022, Oracle and/or its affiliates.
# This program is free software: you can modify it and/or redistribute it
# under the terms of:
#
# (i)  the Universal Permissive License v 1.0 or at your option, any
#      later version (http://oss.oracle.com/licenses/upl); and/or
#
# (ii) the Apache License v 2.0. (http://www.apache.org/licenses/LICENSE-2.0)
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# array_dml_rowcounts.py
#
# Demonstrates the use of the 12.1 feature that allows cursor.executemany()
# to return the number of rows affected by each individual execution as a list.
# The parameter "arraydmlrowcounts" must be set to True in the call to
# cursor.executemany() after which cursor.getarraydmlrowcounts() can be called.
#------------------------------------------------------------------------------

import oracledb
import sample_env

# determine whether to use python-oracledb thin mode or thick mode
if not sample_env.get_is_thin():
    oracledb.init_oracle_client()

connection = oracledb.connect(sample_env.get_main_connect_string())
cursor = connection.cursor()

# show the number of rows for each parent ID as a means of verifying the
# output from the delete statement
for parent_id, count in cursor.execute("""
        select ParentId, count(*)
        from ChildTable
        group by ParentId
        order by ParentId"""):
    print("Parent ID:", parent_id, "has", int(count), "rows.")
print()

# delete the following parent IDs only
parent_ids_to_delete = [20, 30, 50]

print("Deleting Parent IDs:", parent_ids_to_delete)
print()

# enable array DML row counts for each iteration executed in executemany()
cursor.executemany("""
        delete from ChildTable
        where ParentId = :1""",
        [(i,) for i in parent_ids_to_delete],
        arraydmlrowcounts = True)

# display the number of rows deleted for each parent ID
row_counts = cursor.getarraydmlrowcounts()
for parent_id, count in zip(parent_ids_to_delete, row_counts):
    print("Parent ID:", parent_id, "deleted", count, "rows.")
