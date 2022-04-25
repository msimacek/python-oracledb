# ------------------------------------------------------------------------------
# clob.py (Section 7.1)
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Copyright (c) 2017, 2022, Oracle and/or its affiliates.
# ------------------------------------------------------------------------------

import oracledb
import db_config

con = oracledb.connect(user=db_config.user,
                       password=db_config.pw, dsn=db_config.dsn)
cur = con.cursor()

print("Inserting data...")
cur.execute("truncate table testclobs")
long_string = ""
for i in range(5):
    char = chr(ord('A') + i)
    long_string += char * 250
    cur.execute("insert into testclobs values (:1, :2)",
                (i + 1, "String data " + long_string + ' End of string'))
con.commit()

print("Querying data...")
cur.execute("select * from testclobs where id = :id", {'id': 1})
(id, clob) = cur.fetchone()
print("CLOB length:", clob.size())
clobdata = clob.read()
print("CLOB data:", clobdata)
