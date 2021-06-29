#------------------------------------------------------------------------------
# Copyright (c) 2016, 2021, Oracle and/or its affiliates. All rights reserved.
#
# Portions Copyright 2007-2015, Anthony Tuininga. All rights reserved.
#
# Portions Copyright 2001-2007, Computronix (Canada) Ltd., Edmonton, Alberta,
# Canada. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# return_lobs_as_strings.py
#   Returns all CLOB values as strings and BLOB values as bytes. The
# performance of this technique is significantly better than fetching the LOBs
# and then reading the contents of the LOBs as it avoids round-trips to the
# database. Be aware, however, that this method requires contiguous memory so
# is not suitable for very large LOBs.
#------------------------------------------------------------------------------

import oracledb
import sample_env

# determine whether to use thin driver or not
oracledb.defaults.thin = sample_env.get_is_thin()

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
