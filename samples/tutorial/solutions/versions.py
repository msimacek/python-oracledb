# ------------------------------------------------------------------------------
# versions.py (Section 1.5)
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Copyright (c) 2017, 2022, Oracle and/or its affiliates.
# ------------------------------------------------------------------------------

import oracledb
import db_config

con = oracledb.connect(user=db_config.user,
                       password=db_config.pw, dsn=db_config.dsn)

print(oracledb.__version__)  # two underscores before and after version
print("Database version:", con.version)
#print("Client version:", oracledb.clientversion())
