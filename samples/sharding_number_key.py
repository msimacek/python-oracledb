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
# sharding_number_key.py
#
# Demonstrates how to use sharding keys with a sharded database.
# The sample schema provided does not include support for running this demo. A
# sharded database must first be created. Information on how to create a
# sharded database can be found in the documentation:
# https://www.oracle.com/pls/topic/lookup?ctx=dblatest&id=SHARD
#------------------------------------------------------------------------------

import oracledb
import sample_env

# this script is currently only supported in python-oracledb thick mode
oracledb.init_oracle_client()

pool = oracledb.create_pool(user=sample_env.get_main_user(),
                            password=sample_env.get_main_password(),
                            dsn=sample_env.get_connect_string(), min=1, max=5,
                            increment=1)

def connect_and_display(sharding_key):
    print("Connecting with sharding key:", sharding_key)
    with pool.acquire(shardingkey=[sharding_key]) as conn:
        cursor = conn.cursor()
        cursor.execute("select sys_context('userenv', 'db_name') from dual")
        name, = cursor.fetchone()
        print("--> connected to database", name)

connect_and_display(100)
connect_and_display(167)
