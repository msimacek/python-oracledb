# ------------------------------------------------------------------------------
# query_one.py (Section 3.2)
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Copyright (c) 2017, 2022, Oracle and/or its affiliates.
# ------------------------------------------------------------------------------

import oracledb
import db_config

con = oracledb.connect(user=db_config.user,
                       password=db_config.pw, dsn=db_config.dsn)
cur = con.cursor()

cur.execute("select * from dept order by deptno")
row = cur.fetchone()
print(row)

row = cur.fetchone()
print(row)
