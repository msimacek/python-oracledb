# ------------------------------------------------------------------------------
# drop_user.py (Setup Section)
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Copyright (c) 2022, Oracle and/or its affiliates.
# ------------------------------------------------------------------------------
import oracledb
import db_config_sys
import db_config
import run_sql_script

# Connect using the System User ID and password
con = oracledb.connect(user=db_config_sys.sysuser,
                       password=db_config_sys.syspw, dsn=db_config_sys.dsn)

# drop the tutorial user and schema
print("Dropping the tutorial user...")
run_sql_script.run_sql_script(con, "drop_user", user=db_config.user)
print("Done.")
