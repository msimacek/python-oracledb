# ------------------------------------------------------------------------------
# connect_health.py (Section 1.7)
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Copyright (c) 2017, 2022, Oracle and/or its affiliates.
# ------------------------------------------------------------------------------

import oracledb
import db_config

con = oracledb.connect(user=db_config.user,
                       password=db_config.pw, dsn=db_config.dsn)
if con.is_healthy():
    print("Healthy connection!")
else:
    print("Unusable connection. Please check the database and network settings.")
