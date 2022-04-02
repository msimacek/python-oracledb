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
# setup_test.py
#
# Creates users and populates their schemas with the tables and packages
# necessary for the test suite.
#------------------------------------------------------------------------------

import drop_test
import oracledb
import test_env

# connect as administrative user (usually SYSTEM or ADMIN)
conn = oracledb.connect(test_env.get_admin_connect_string())

# drop existing users and editions, if applicable
drop_test.drop_tests(conn)

# create test schemas
print("Creating test schemas...")
test_env.run_sql_script(conn, "setup_test",
                        main_user=test_env.get_main_user(),
                        main_password=test_env.get_main_password(),
                        proxy_user=test_env.get_proxy_user(),
                        proxy_password=test_env.get_proxy_password())
print("Done.")
