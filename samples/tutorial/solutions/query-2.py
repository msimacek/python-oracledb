# ------------------------------------------------------------------------------
# query.py (Section 1.4)
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
res = cur.fetchall()
for row in res:
    print(row)

cur.close()
con.close()
