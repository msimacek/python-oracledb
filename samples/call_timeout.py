#------------------------------------------------------------------------------
# Copyright (c) 2019, 2022, Oracle and/or its affiliates.
# This program is free software: you can modify it and/or redistribute it
# under the terms of:
#
# (i)  the Universal Permissive License v 1.0 or at your option, any
#      later version (http://oss.oracle.com/licenses/upl); and/or
#
# (ii) the Apache License v 2.0. (http://www.apache.org/licenses/LICENSE-2.0)
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# call_timeout.py
#
# Demonstrates the use of the Oracle Client 18c feature that enables round
# trips to the database to time out if a specified amount of time
# (in milliseconds) has passed without a response from the database.
#
# This script requires Oracle Client 18.1 and higher when using thick mode.
#------------------------------------------------------------------------------

import oracledb
import sample_env

# determine whether to use python-oracledb thin mode or thick mode
if not sample_env.get_is_thin():
    oracledb.init_oracle_client()

connection = oracledb.connect(sample_env.get_main_connect_string())
connection.call_timeout = 2000
print("Call timeout set at", connection.call_timeout, "milliseconds...")

cursor = connection.cursor()
cursor.execute("select sysdate from dual")
today, = cursor.fetchone()
print("Fetch of current date before timeout:", today)

# dbms_session.sleep() replaces dbms_lock.sleep() from Oracle Database 18c
sleep_proc_name = "dbms_session.sleep" \
        if int(connection.version.split(".")[0]) >= 18 \
        else "dbms_lock.sleep"

print("Sleeping...should time out...")
try:
    cursor.callproc(sleep_proc_name, (3,))
except oracledb.DatabaseError as e:
    print("ERROR:", e)

cursor.execute("select sysdate from dual")
today, = cursor.fetchone()
print("Fetch of current date after timeout:", today)
