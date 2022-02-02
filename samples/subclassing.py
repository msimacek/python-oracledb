#------------------------------------------------------------------------------
# Copyright (c) 2016, 2022, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# subclassing.py
#
# Demonstrates how to subclass connections and cursors in order to add
# additional functionality (like logging) or create specialized interfaces for
# paticular applications.
#------------------------------------------------------------------------------

import oracledb
import sample_env

# determine whether to use thin driver or not
if not sample_env.get_is_thin():
    oracledb.init_oracle_client()

# sample subclassed connection which overrides the constructor (so no
# parameters are required) and the cursor() method (so that the subclassed
# cursor is returned instead of the default cursor implementation)
class Connection(oracledb.Connection):

    def __init__(self):
        connect_string = sample_env.get_main_connect_string()
        print("CONNECT to database")
        super().__init__(connect_string)

    def cursor(self):
        return Cursor(self)


# sample subclassed cursor which overrides the execute() and fetchone()
# methods in order to perform some simple logging
class Cursor(oracledb.Cursor):

    def execute(self, statement, args):
        print("EXECUTE", statement)
        print("ARGS:")
        for arg_index, arg in enumerate(args):
            print("   ", arg_index + 1, "=>", repr(arg))
        return super().execute(statement, args)

    def fetchone(self):
        print("FETCH ONE")
        return super().fetchone()


# create instances of the subclassed connection and cursor
connection = Connection()
cursor = connection.cursor()

# demonstrate that the subclassed connection and cursor are being used
cursor.execute("select count(*) from ChildTable where ParentId = :1", (30,))
count, = cursor.fetchone()
print("COUNT:", int(count))
