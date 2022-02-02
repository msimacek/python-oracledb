#------------------------------------------------------------------------------
# Copyright (c) 2016, 2022, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# query.py
#
# Demonstrates how to perform a query in different ways.
#------------------------------------------------------------------------------

import oracledb
import sample_env

# determine whether to use thin driver or not
if not sample_env.get_is_thin():
    oracledb.init_oracle_client()

connection = oracledb.connect(sample_env.get_main_connect_string())

sql = """
        select * from SampleQueryTab
        where id < 6
        order by id"""

print("Get all rows via iterator")
cursor = connection.cursor()
for result in cursor.execute(sql):
    print(result)
print()

print("Query one row at a time")
cursor.execute(sql)
row = cursor.fetchone()
print(row)
row = cursor.fetchone()
print(row)
print()

print("Fetch many rows")
cursor.execute(sql)
res = cursor.fetchmany(3)
print(res)
print()

print("Fetch each row as a Dictionary")
cursor.execute(sql)
columns = [col[0] for col in cursor.description]
cursor.rowfactory = lambda *args: dict(zip(columns, args))
for row in cursor:
    print(row)
