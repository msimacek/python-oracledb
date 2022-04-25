# ------------------------------------------------------------------------------
# connect_drcp.py (Section 2.3 and 2.5)
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Copyright (c) 2017, 2022, Oracle and/or its affiliates.
# ------------------------------------------------------------------------------

import oracledb
import db_config

con = oracledb.connect(user=db_config.user, password=db_config.pw, dsn=db_config.dsn + ":pooled",
                       cclass="PYTHONDEMO", purity=oracledb.ATTR_PURITY_SELF)

print("Database version:", con.version)
