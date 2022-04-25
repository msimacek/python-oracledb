# ------------------------------------------------------------------------------
# subclass.py (Section 9.1 and 9.2)
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Copyright (c) 2017, 2022, Oracle and/or its affiliates.
# ------------------------------------------------------------------------------

import oracledb
import db_config


class MyConnection(oracledb.Connection):

    def __init__(self):
        print("Connecting to database")
        return super(MyConnection, self).__init__(user=db_config.user, password=db_config.pw, dsn=db_config.dsn)


con = MyConnection()
cur = con.cursor()

cur.execute("select count(*) from emp where deptno = :bv", (10,))
count, = cur.fetchone()
print("Number of rows:", count)
