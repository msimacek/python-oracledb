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
# app_context.py
#
# Demonstrates the use of application context. Application context is available
# within logon triggers and can be retrieved by using the function
# sys_context().
#------------------------------------------------------------------------------

import oracledb
import sample_env

# this script is currently only supported in python-oracledb thick mode
oracledb.init_oracle_client()

# define constants used throughout the script; adjust as desired
APP_CTX_NAMESPACE = "CLIENTCONTEXT"
APP_CTX_ENTRIES = [
    ( APP_CTX_NAMESPACE, "ATTR1", "VALUE1" ),
    ( APP_CTX_NAMESPACE, "ATTR2", "VALUE2" ),
    ( APP_CTX_NAMESPACE, "ATTR3", "VALUE3" )
]

connection = oracledb.connect(sample_env.get_main_connect_string(),
                              appcontext=APP_CTX_ENTRIES)
cursor = connection.cursor()
for namespace, name, value in APP_CTX_ENTRIES:
    cursor.execute("select sys_context(:1, :2) from dual", (namespace, name))
    value, = cursor.fetchone()
    print("Value of context key", name, "is", value)
