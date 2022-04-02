#------------------------------------------------------------------------------
# Copyright (c) 2016, 2022, Oracle and/or its affiliates.
#
# Portions Copyright 2007-2015, Anthony Tuininga. All rights reserved.
#
# Portions Copyright 2001-2007, Computronix (Canada) Ltd., Edmonton, Alberta,
# Canada. All rights reserved.
#
# This program is free software: you can modify it and/or redistribute it
# under the terms of:
#
# (i)  the Universal Permissive License v 1.0 or at your option, any
#      later version (http://oss.oracle.com/licenses/upl); and/or
#
# (ii) the Apache License v 2.0. (http://www.apache.org/licenses/LICENSE-2.0)
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# editioning.py
#
# Demonstrates the use of Edition-Based Redefinition, a feature that is
# available in Oracle Database 11.2 and higher. See the Oracle documentation on
# the subject for additional information. Adjust the contents at the top of the
# script for your own database as needed.
#------------------------------------------------------------------------------

import os

import oracledb
import sample_env

# this script is currently only supported in python-oracledb thick mode
oracledb.init_oracle_client()

# connect to the editions user and create a procedure
edition_connect_string = sample_env.get_edition_connect_string()
edition_name = sample_env.get_edition_name()
connection = oracledb.connect(edition_connect_string)
print("Edition should be None, actual value is:", repr(connection.edition))
cursor = connection.cursor()
cursor.execute("""
        create or replace function TestEditions return varchar2 as
        begin
            return 'Base Procedure';
        end;""")
result = cursor.callfunc("TestEditions", str)
print("Function should return 'Base Procedure', actually returns:",
      repr(result))

# next, change the edition and recreate the procedure in the new edition
cursor.execute("alter session set edition = %s" % edition_name)
print("Edition should be", repr(edition_name.upper()),
      "actual value is:", repr(connection.edition))
cursor.execute("""
        create or replace function TestEditions return varchar2 as
        begin
            return 'Edition 1 Procedure';
        end;""")
result = cursor.callfunc("TestEditions", str)
print("Function should return 'Edition 1 Procedure', actually returns:",
      repr(result))

# next, change the edition back to the base edition and demonstrate that the
# original function is being called
cursor.execute("alter session set edition = ORA$BASE")
result = cursor.callfunc("TestEditions", str)
print("Function should return 'Base Procedure', actually returns:",
      repr(result))

# the edition can be set upon connection
connection = oracledb.connect(edition_connect_string,
                              edition=edition_name.upper())
cursor = connection.cursor()
result = cursor.callfunc("TestEditions", str)
print("Function should return 'Edition 1 Procedure', actually returns:",
      repr(result))

# it can also be set via the environment variable ORA_EDITION
os.environ["ORA_EDITION"] = edition_name.upper()
connection = oracledb.connect(edition_connect_string)
print("Edition should be", repr(edition_name.upper()),
      "actual value is:", repr(connection.edition))
cursor = connection.cursor()
result = cursor.callfunc("TestEditions", str)
print("Function should return 'Edition 1 Procedure', actually returns:",
      repr(result))
