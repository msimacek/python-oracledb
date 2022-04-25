# ------------------------------------------------------------------------------
# query_many.py (Section 3.3)
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
num_rows = 3
res = cur.fetchmany(num_rows)
print(res)

print(res[0])    # first row
print(res[0][1])  # second element of first row
