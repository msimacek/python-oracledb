#------------------------------------------------------------------------------
# Copyright (c) 2017, 2022, Oracle and/or its affiliates.
# This program is free software: you can modify it and/or redistribute it
# under the terms of:
#
# (i)  the Universal Permissive License v 1.0 or at your option, any
#      later version (http://oss.oracle.com/licenses/upl); and/or
#
# (ii) the Apache License v 2.0. (http://www.apache.org/licenses/LICENSE-2.0)
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# return_numbers_as_decimals.py
#
# Returns all numbers as decimals. This is needed if the full decimal
# precision of Oracle numbers is required by the application. See this article
# (http://blog.reverberate.org/2016/02/06/floating-point-demystified-part2.html)
# for an explanation of why decimal numbers (like Oracle numbers) cannot be
# represented exactly by floating point numbers.
#------------------------------------------------------------------------------

import decimal

import oracledb
import sample_env

# determine whether to use python-oracledb thin mode or thick mode
if not sample_env.get_is_thin():
    oracledb.init_oracle_client()

# indicate that numbers should be fetched as decimals
oracledb.defaults.fetch_decimals = True

connection = oracledb.connect(sample_env.get_main_connect_string())
cursor = connection.cursor()
cursor.execute("select * from TestNumbers")
for row in cursor:
    print("Row:", row)
