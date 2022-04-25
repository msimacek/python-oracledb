# ------------------------------------------------------------------------------
# query_arraysize.py (Section 3.5)
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Copyright (c) 2017, 2022, Oracle and/or its affiliates.
# ------------------------------------------------------------------------------

import oracledb
import time
import db_config

con = oracledb.connect(user=db_config.user,
                       password=db_config.pw, dsn=db_config.dsn)

start = time.time()

cur = con.cursor()
cur.prefetchrows = 100
cur.arraysize = 100
cur.execute("select * from bigtab")
res = cur.fetchall()
# print(res)  # uncomment to display the query results

elapsed = (time.time() - start)
print(elapsed, "seconds")
