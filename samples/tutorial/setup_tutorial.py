# ------------------------------------------------------------------------------
# setup_tutorial.py (Setup Section)
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Copyright (c) 2022, Oracle and/or its affiliates.
# ------------------------------------------------------------------------------
import oracledb
import db_config
import run_sql_script

# Connect using the System User ID and password
con = oracledb.connect(user=db_config.user,
                       password=db_config.pw, dsn=db_config.dsn)

# create sample schemas and defintions for the tutorial
print("Setting up the sample tables and other DB objects for the tutorial...")
run_sql_script.run_sql_script(
    con, "setup_tutorial", user=db_config.user, pw=db_config.pw)
print("Done.")
