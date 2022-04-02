#------------------------------------------------------------------------------
# Copyright (c) 2016, 2022, Oracle and/or its affiliates.
# This program is free software: you can modify it and/or redistribute it
# under the terms of:
#
# (i)  the Universal Permissive License v 1.0 or at your option, any
#      later version (http://oss.oracle.com/licenses/upl); and/or
#
# (ii) the Apache License v 2.0. (http://www.apache.org/licenses/LICENSE-2.0)
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# plsql_record.py
#
# Demonstrates how to bind (in and out) a PL/SQL record.
#
# This feature is only available in Oracle Database 12.1 and higher.
#------------------------------------------------------------------------------

import datetime

import oracledb
import sample_env

# this script is currently only supported in python-oracledb thick mode
oracledb.init_oracle_client()

connection = oracledb.connect(sample_env.get_main_connect_string())

# create new object of the correct type
# note the use of a PL/SQL record defined in a package
# a table record identified by TABLE%ROWTYPE can also be used
type_obj = connection.gettype("PKG_DEMO.UDT_DEMORECORD")
obj = type_obj.newobject()
obj.NUMBERVALUE = 6
obj.STRINGVALUE = "Test String"
obj.DATEVALUE = datetime.datetime(2016, 5, 28)
obj.BOOLEANVALUE = False

# show the original values
print("NUMBERVALUE ->", obj.NUMBERVALUE)
print("STRINGVALUE ->", obj.STRINGVALUE)
print("DATEVALUE ->", obj.DATEVALUE)
print("BOOLEANVALUE ->", obj.BOOLEANVALUE)
print()

# call the stored procedure which will modify the object
cursor = connection.cursor()
cursor.callproc("pkg_Demo.DemoRecordsInOut", (obj,))

# show the modified values
print("NUMBERVALUE ->", obj.NUMBERVALUE)
print("STRINGVALUE ->", obj.STRINGVALUE)
print("DATEVALUE ->", obj.DATEVALUE)
print("BOOLEANVALUE ->", obj.BOOLEANVALUE)
print()
