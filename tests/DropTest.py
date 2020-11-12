#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# DropTest.py
#
# Drops the database objects used by the oracledb test suite.
#------------------------------------------------------------------------------

import oracledb
import base

def drop_tests(conn):
    print("Dropping test schemas...")
    base.run_sql_script(conn, "DropTest",
                        main_user=base.get_main_user(),
                        proxy_user=base.get_proxy_user())

if __name__ == "__main__":
    conn = oracledb.connect(base.get_admin_connect_string(),
                            thin=base.get_is_thin())
    drop_tests(conn)
    print("Done.")
