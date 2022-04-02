#------------------------------------------------------------------------------
# Copyright (c) 2016, 2022, Oracle and/or its affiliates.
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
# return_lobs_as_strings.py
#
# Returns all CLOB values as strings and BLOB values as bytes. The
# performance of this technique is significantly better than fetching the LOBs
# and then reading the contents of the LOBs as it avoids round-trips to the
# database. Be aware, however, that this method requires contiguous memory so
# is not suitable for very large LOBs.
#------------------------------------------------------------------------------

import oracledb
import sample_env

# determine whether to use python-oracledb thin mode or thick mode
if not sample_env.get_is_thin():
    oracledb.init_oracle_client()

# indicate that LOBS should not be fetched
oracledb.defaults.fetch_lobs = False

connection = oracledb.connect(sample_env.get_main_connect_string())
cursor = connection.cursor()

# add some data to the tables
print("Populating tables with data...")
cursor.execute("truncate table TestClobs")
cursor.execute("truncate table TestBlobs")
long_string = ""
for i in range(10):
    char = chr(ord('A') + i)
    long_string += char * 25000
    cursor.execute("insert into TestClobs values (:1, :2)",
                   (i + 1, "STRING " + long_string))
    cursor.execute("insert into TestBlobs values (:1, :2)",
                   (i + 1, long_string.encode("ascii")))
connection.commit()

# fetch the data and show the results
print("CLOBS returned as strings")
cursor.execute("""
        select
            IntCol,
            ClobCol
        from TestClobs
        order by IntCol""")
for int_col, value in cursor:
    print("Row:", int_col, "string of length", len(value))
print()
print("BLOBS returned as bytes")
cursor.execute("""
        select
            IntCol,
            BlobCol
        from TestBlobs
        order by IntCol""")
for int_col, value in cursor:
    print("Row:", int_col, "string of length", value and len(value) or 0)
