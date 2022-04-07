#------------------------------------------------------------------------------
# Copyright (c) 2020, 2021, Oracle and/or its affiliates.
# This program is free software: you can modify it and/or redistribute it
# under the terms of:
#
# (i)  the Universal Permissive License v 1.0 or at your option, any
#      later version (http://oss.oracle.com/licenses/upl); and/or
#
# (ii) the Apache License v 2.0. (http://www.apache.org/licenses/LICENSE-2.0)
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# drop_samples.py
#
# Drops the database objects used for the python-oracledb samples.
#------------------------------------------------------------------------------

import oracledb
import sample_env

# determine whether to use python-oracledb thin mode or thick mode
if not sample_env.get_is_thin():
    oracledb.init_oracle_client()

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
