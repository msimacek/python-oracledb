#------------------------------------------------------------------------------
# Copyright (c) 2020, 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

"""
4300 - Module for testing other cursor methods and attributes.
"""

import decimal
import unittest

import oracledb
import test_env

class TestCase(test_env.BaseTestCase):

    def test_4348_reexecute_query_with_blob_as_bytes(self):
        "4347 - test re-executing a query with blob as bytes"
        def type_handler(cursor, name, default_type, size, precision, scale):
            if default_type == oracledb.DB_TYPE_BLOB:
                return cursor.var(bytes, arraysize=cursor.arraysize)
        self.connection.outputtypehandler = type_handler
        blob_data = b"An arbitrary set of blob data for test case 4348"
        self.cursor.execute("truncate table TestBLOBs")
        self.cursor.execute("insert into TestBLOBs values (1, :data)",
                            [blob_data])
        self.cursor.execute("select * from TestBLOBs")
        self.assertEqual(self.cursor.fetchall(), [(1, blob_data)])
        self.cursor.execute("truncate table TestBLOBs")
        self.cursor.execute("insert into TestBLOBs values (1, :data)",
                            [blob_data])
        self.cursor.execute("select * from TestBLOBs")
        self.assertEqual(rows, [(1, blob_data)])

if __name__ == "__main__":
    test_env.run_test_cases()
