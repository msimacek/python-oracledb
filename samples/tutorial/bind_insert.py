# ------------------------------------------------------------------------------
# bind_insert.py (Section 4.2 and 4.3)
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Copyright (c) 2017, 2022, Oracle and/or its affiliates.
# ------------------------------------------------------------------------------

import oracledb
import db_config

con = oracledb.connect(user=db_config.user,
                       password=db_config.pw, dsn=db_config.dsn)
cur = con.cursor()

rows = [(1, "First"), (2, "Second"),
        (3, "Third"), (4, "Fourth"),
        (5, "Fifth"), (6, "Sixth"),
        (7, "Seventh")]

cur.executemany("insert into mytab(id, data) values (:1, :2)", rows)

# Now query the results back

cur2 = con.cursor()
cur2.execute('select * from mytab')
res = cur2.fetchall()
print(res)
