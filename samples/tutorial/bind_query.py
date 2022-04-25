# ------------------------------------------------------------------------------
# bind_query.py (Section 4.1)
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Copyright (c) 2017, 2022, Oracle and/or its affiliates.
# ------------------------------------------------------------------------------

import oracledb
import db_config

con = oracledb.connect(user=db_config.user,
                       password=db_config.pw, dsn=db_config.dsn)
cur = con.cursor()

sql = "select * from dept where deptno = :id order by deptno"

cur.execute(sql, id=20)
res = cur.fetchall()
print(res)

cur.execute(sql, id=10)
res = cur.fetchall()
print(res)
