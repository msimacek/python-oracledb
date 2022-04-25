# ------------------------------------------------------------------------------
# connect_params2.py (Section 1.6)
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Copyright (c) 2017, 2022, Oracle and/or its affiliates.
# ------------------------------------------------------------------------------

import oracledb
import db_config

params = oracledb.ConnectParams(
    host="localhost", port=1521, service_name="orclpdb")
con = oracledb.connect(user=db_config.user,
                       password=db_config.pw, params=params)
print("Database version:", con.version)
