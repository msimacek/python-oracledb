#------------------------------------------------------------------------------
# Copyright (c) 2020, 2022, Oracle and/or its affiliates.
#
# This software is dual-licensed to you under the Universal Permissive License
# (UPL) 1.0 as shown at https://oss.oracle.com/licenses/upl and Apache License
# 2.0 as shown at http://www.apache.org/licenses/LICENSE-2.0. You may choose
# either license.
#
# If you elect to accept the software under the Apache License, Version 2.0,
# the following applies:
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
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
