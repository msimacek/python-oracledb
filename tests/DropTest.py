#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# DropTest.py
#
# Drops the database objects used by the oracledb test suite.
#------------------------------------------------------------------------------

import oracledb
import test_env

def drop_tests(conn):
    print("Dropping test schemas...")
    test_env.run_sql_script(conn, "DropTest",
                            main_user=test_env.get_main_user(),
                            proxy_user=test_env.get_proxy_user())

if __name__ == "__main__":
    conn = oracledb.connect(test_env.get_admin_connect_string(),
                            thin=test_env.get_is_thin())
    drop_tests(conn)
    print("Done.")
