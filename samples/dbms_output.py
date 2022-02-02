#------------------------------------------------------------------------------
# Copyright (c) 2020, 2022, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# dbms_output.py
#
# Demonstrates one method of fetching the lines produced by the DBMS_OUTPUT
# package.
#------------------------------------------------------------------------------

import oracledb
import sample_env

# determine whether to use thin driver or not
if not sample_env.get_is_thin():
    oracledb.init_oracle_client()

connection = oracledb.connect(sample_env.get_main_connect_string())
cursor = connection.cursor()

# enable DBMS_OUTPUT
cursor.callproc("dbms_output.enable")

# execute some PL/SQL that generates output with DBMS_OUTPUT.PUT_LINE
cursor.execute("""
        begin
            dbms_output.put_line('This is the oracledb manual');
            dbms_output.put_line('');
            dbms_output.put_line('Demonstrating use of DBMS_OUTPUT');
        end;""")

# tune this size for your application
chunk_size = 10

# create variables to hold the output
lines_var = cursor.arrayvar(str, chunk_size)
num_lines_var = cursor.var(int)
num_lines_var.setvalue(0, chunk_size)

# fetch the text that was added by PL/SQL
while True:
    cursor.callproc("dbms_output.get_lines", (lines_var, num_lines_var))
    num_lines = num_lines_var.getvalue()
    lines = lines_var.getvalue()[:num_lines]
    for line in lines:
        print(line or "")
    if num_lines < chunk_size:
        break
