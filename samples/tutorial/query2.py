# ------------------------------------------------------------------------------
# query2.py (Section 3.1)
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Copyright (c) 2017, 2022, Oracle and/or its affiliates.
# ------------------------------------------------------------------------------

import oracledb
import db_config

con = oracledb.connect(user=db_config.user,
                       password=db_config.pw, dsn=db_config.dsn)

cur = con.cursor()
cur.execute('select * from dept order by deptno')
for deptno, dname, loc in cur:
    print("Department number: ", deptno)
    print("Department name: ", dname)
    print("Department location:", loc)
