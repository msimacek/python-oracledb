#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# SetupTest.py
#
# Creates users and populates their schemas with the tables and packages
# necessary for the oracledb test suite.
#------------------------------------------------------------------------------

import oracledb

import test_env
import DropTest

# connect as administrative user (usually SYSTEM or ADMIN)
conn = oracledb.connect(test_env.get_admin_connect_string(),
                        thin=test_env.get_is_thin())

# drop existing users and editions, if applicable
DropTest.drop_tests(conn)

# create test schemas
print("Creating test schemas...")
test_env.run_sql_script(conn, "SetupTest",
                        main_user=test_env.get_main_user(),
                        main_password=test_env.get_main_password(),
                        proxy_user=test_env.get_proxy_user(),
                        proxy_password=test_env.get_proxy_password())
print("Done.")
