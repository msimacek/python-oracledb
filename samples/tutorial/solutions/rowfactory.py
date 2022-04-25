# ------------------------------------------------------------------------------
# rowfactory.py (Section 8.1)
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Copyright (c) 2017, 2022, Oracle and/or its affiliates.
# ------------------------------------------------------------------------------

import collections
import oracledb
import db_config

con = oracledb.connect(user=db_config.user,
                       password=db_config.pw, dsn=db_config.dsn)

cur = con.cursor()

cur.execute("select deptno, dname from dept")
res = cur.fetchall()

print('Array indexes:')
for row in res:
    print(row[0], "->", row[1])

print('Loop target variables:')
for c1, c2 in res:
    print(c1, "->", c2)

print('Rowfactory:')
cur.execute("select deptno, dname from dept")
cur.rowfactory = collections.namedtuple("MyClass", ["DeptNumber", "DeptName"])

res = cur.fetchall()
for row in res:
    print(row.DeptNumber, "->", row.DeptName)
