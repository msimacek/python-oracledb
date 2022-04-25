# ------------------------------------------------------------------------------
# clob_string.py (Section 7.2)
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


def OutputTypeHandler(cursor, name, defaultType, size, precision, scale):
    if defaultType == oracledb.CLOB:
        return cursor.var(oracledb.LONG_STRING, arraysize=cursor.arraysize)


con.outputtypehandler = OutputTypeHandler

print("Querying data...")
cur.execute("select * from testclobs where id = :id", {'id': 1})
(id, clobdata) = cur.fetchone()
print("CLOB length:", len(clobdata))
print("CLOB data:", clobdata)
