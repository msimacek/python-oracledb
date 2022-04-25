# ------------------------------------------------------------------------------
# plsql_proc.py (Section 5.2)
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Copyright (c) 2017, 2022, Oracle and/or its affiliates.
# ------------------------------------------------------------------------------

import oracledb
import db_config

con = oracledb.connect(user=db_config.user,
                       password=db_config.pw, dsn=db_config.dsn)
cur = con.cursor()

myvar = cur.var(int)
cur.callproc('myproc', (123, myvar))
print(myvar.getvalue())
