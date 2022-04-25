# ------------------------------------------------------------------------------
# query_scroll.py (Section 11.1)
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Copyright 2017, 2022, Oracle and/or its affiliates.
# ------------------------------------------------------------------------------

import oracledb
import db_config_thick as db_config

con = oracledb.connect(user=db_config.user,
                       password=db_config.pw, dsn=db_config.dsn)
cur = con.cursor(scrollable=True)

cur.execute("select * from dept order by deptno")

cur.scroll(2, mode="absolute")  # go to second row
print(cur.fetchone())

cur.scroll(-1)                  # go back one row
print(cur.fetchone())

cur.scroll(1)  # go to next row
print(cur.fetchone())

cur.scroll(mode="first")  # go to first row
print(cur.fetchone())
