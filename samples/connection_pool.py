#------------------------------------------------------------------------------
# Copyright (c) 2017, 2022, Oracle and/or its affiliates.
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
# connection_pool.py
#
# Demonstrates the use of connection pooling. Pools can significantly reduce
# connection times for long running applications that repeatedly open and close
# connections. Internal features help protect against dead connections, and
# also aid use of Oracle Database features such as FAN and
# Application Continuity.
#
# The script uses threading to show multiple users of the pool. One thread
# performs a database sleep while another performs a query. A more typical
# application might be a web service that handles requests from multiple users.
# Note only one operation (such as an execute or fetch) can take place at a time
# on each connection.
#
# Also see session_callback.py.
#------------------------------------------------------------------------------

import threading

import oracledb
import sample_env

# determine whether to use python-oracledb thin mode or thick mode
if not sample_env.get_is_thin():
    oracledb.init_oracle_client(lib_dir=sample_env.get_oracle_client())

# Create a Connection Pool
pool = oracledb.create_pool(user=sample_env.get_main_user(),
                            password=sample_env.get_main_password(),
                            dsn=sample_env.get_connect_string(), min=2, max=5,
                            increment=1)

def the_long_query():
    with pool.acquire() as conn:
        cursor = conn.cursor()
        cursor.arraysize = 25000
        print("the_long_query(): beginning execute...")
        cursor.execute("""
                select *
                from
                    TestNumbers
                    cross join TestNumbers
                    cross join TestNumbers
                    cross join TestNumbers
                    cross join TestNumbers
                    cross join TestNumbers""")
        print("the_long_query(): done execute...")
        while True:
            rows = cursor.fetchmany()
            if not rows:
                break
            print("the_long_query(): fetched", len(rows), "rows...")
        print("the_long_query(): all done!")


def do_a_lock():
    with pool.acquire() as conn:
        # dbms_session.sleep() replaces dbms_lock.sleep()
        # from Oracle Database 18c
        sleep_proc_name = "dbms_session.sleep" \
                if int(conn.version.split(".")[0]) >= 18 \
                else "dbms_lock.sleep"
        cursor = conn.cursor()
        print("do_a_lock(): beginning execute...")
        cursor.callproc(sleep_proc_name, (5,))
        print("do_a_lock(): done execute...")


thread1 = threading.Thread(target=the_long_query)
thread1.start()

thread2 = threading.Thread(target=do_a_lock)
thread2.start()

thread1.join()
thread2.join()

print("All done!")
