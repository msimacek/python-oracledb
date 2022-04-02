#------------------------------------------------------------------------------
# Copyright (c) 2020, 2022, Oracle and/or its affiliates.
# This program is free software: you can modify it and/or redistribute it
# under the terms of:
#
# (i)  the Universal Permissive License v 1.0 or at your option, any
#      later version (http://oss.oracle.com/licenses/upl); and/or
#
# (ii) the Apache License v 2.0. (http://www.apache.org/licenses/LICENSE-2.0)
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# drop_test.py
#
# Drops the database objects used by the test suite.
#------------------------------------------------------------------------------

import oracledb
import test_env

def drop_tests(conn):
    print("Dropping test schemas...")
    test_env.run_sql_script(conn, "drop_test",
                            main_user=test_env.get_main_user(),
                            proxy_user=test_env.get_proxy_user())

if __name__ == "__main__":
    conn = oracledb.connect(test_env.get_admin_connect_string())
    drop_tests(conn)
    print("Done.")
