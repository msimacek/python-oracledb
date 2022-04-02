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
# plsql_collection.py
#
# Demonstrates how to get the value of a PL/SQL collection from a stored
# procedure.
#
# This feature is only available in Oracle Database 12.1 and higher.
#------------------------------------------------------------------------------

import oracledb
import sample_env

# this script is currently only supported in python-oracledb thick mode
oracledb.init_oracle_client()

connection = oracledb.connect(sample_env.get_main_connect_string())

# create new empty object of the correct type
# note the use of a PL/SQL type defined in a package
type_obj = connection.gettype("PKG_DEMO.UDT_STRINGLIST")
obj = type_obj.newobject()

# call the stored procedure which will populate the object
cursor = connection.cursor()
cursor.callproc("pkg_Demo.DemoCollectionOut", (obj,))

# show the indexes that are used by the collection
print("Indexes and values of collection:")
ix = obj.first()
while ix is not None:
    print(ix, "->", obj.getelement(ix))
    ix = obj.next(ix)
print()

# show the values as a simple list
print("Values of collection as list:")
print(obj.aslist())
print()

# show the values as a simple dictionary
print("Values of collection as dictionary:")
print(obj.asdict())
print()
