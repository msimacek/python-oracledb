#------------------------------------------------------------------------------
# Copyright (c) 2017, 2022, Oracle and/or its affiliates. All rights reserved.
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

# determine whether to use thin driver or not
if not sample_env.get_is_thin():
    oracledb.init_oracle_client()

# indicate that numbers should be fetched as decimals
oracledb.defaults.fetch_decimals = True

connection = oracledb.connect(sample_env.get_main_connect_string())
cursor = connection.cursor()
cursor.execute("select * from TestNumbers")
for row in cursor:
    print("Row:", row)
