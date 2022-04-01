#------------------------------------------------------------------------------
# Copyright (c) 2016, 2022, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# generic_row_factory.py
#
# Demonstrates the ability to return named tuples for all queries using a
# subclassed cursor and row factory.
#------------------------------------------------------------------------------

import collections

import oracledb
import sample_env

# determine whether to use python-oracledb thin mode or thick mode
if not sample_env.get_is_thin():
    oracledb.init_oracle_client()

class Connection(oracledb.Connection):

    def cursor(self):
        return Cursor(self)


class Cursor(oracledb.Cursor):

    def execute(self, statement, args=None):
        prepare_needed = (self.statement != statement)
        result = super().execute(statement, args or [])
        if prepare_needed:
            description = self.description
            if description is not None:
                names = [d[0] for d in description]
                self.rowfactory = collections.namedtuple("GenericQuery", names)
        return result


# create new subclassed connection and cursor
connection = Connection(sample_env.get_main_connect_string())
cursor = connection.cursor()

# the names are now available directly for each query executed
for row in cursor.execute("select ParentId, Description from ParentTable"):
    print(row.PARENTID, "->", row.DESCRIPTION)
print()

for row in cursor.execute("select ChildId, Description from ChildTable"):
    print(row.CHILDID, "->", row.DESCRIPTION)
print()
