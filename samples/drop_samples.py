#------------------------------------------------------------------------------
# Copyright (c) 2020, 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# drop_samples.py
#
# Drops the database objects used for the py-oracledb samples.
#------------------------------------------------------------------------------

import oracledb
import sample_env

# determine whether to use thin driver or not
oracledb.defaults.thin = sample_env.get_is_thin()

def drop_samples(conn):
    print("Dropping sample schemas and edition...")
    sample_env.run_sql_script(conn, "drop_samples",
                              main_user=sample_env.get_main_user(),
                              edition_user=sample_env.get_edition_user(),
                              edition_name=sample_env.get_edition_name())

if __name__ == "__main__":
    conn = oracledb.connect(sample_env.get_admin_connect_string())
    drop_samples(conn)
    print("Done.")
