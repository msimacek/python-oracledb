#------------------------------------------------------------------------------
# Copyright (c) 2020, 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# setup_samples.py
#
# Creates users and populates their schemas with the tables and packages
# necessary for the py-oracledb samples. An edition is also created for the
# demonstration of PL/SQL editioning.
#------------------------------------------------------------------------------

import oracledb

import sample_env
import drop_samples

# connect as administrative user (usually SYSTEM or ADMIN)
conn = oracledb.connect(sample_env.get_admin_connect_string(),
                        thin=sample_env.get_is_thin())

# drop existing users and editions, if applicable
drop_samples.drop_samples(conn)

# create sample schema and edition
print("Creating sample schemas and edition...")
sample_env.run_sql_script(conn, "SetupSamples",
                          main_user=sample_env.get_main_user(),
                          main_password=sample_env.get_main_password(),
                          edition_user=sample_env.get_edition_user(),
                          edition_password=sample_env.get_edition_password(),
                          edition_name=sample_env.get_edition_name())
print("Done.")
