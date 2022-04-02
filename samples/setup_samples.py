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
# setup_samples.py
#
# Creates users and populates their schemas with the tables and packages
# necessary for running the sample scripts. An edition is also created for the
# demonstration of PL/SQL editioning.
#------------------------------------------------------------------------------

import oracledb

import sample_env
import drop_samples

# determine whether to use python-oracledb thin mode or thick mode
if not sample_env.get_is_thin():
    oracledb.init_oracle_client()

# connect as administrative user (usually SYSTEM or ADMIN)
conn = oracledb.connect(sample_env.get_admin_connect_string())

# drop existing users and editions, if applicable
drop_samples.drop_samples(conn)

# create sample schema and edition
print("Creating sample schemas and edition...")
sample_env.run_sql_script(conn, "setup_samples",
                          main_user=sample_env.get_main_user(),
                          main_password=sample_env.get_main_password(),
                          edition_user=sample_env.get_edition_user(),
                          edition_password=sample_env.get_edition_password(),
                          edition_name=sample_env.get_edition_name())
print("Done.")
