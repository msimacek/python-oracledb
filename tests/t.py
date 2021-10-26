#------------------------------------------------------------------------------
# Copyright (c) 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

"""
3600 - Module for testing the conversions of outputtype handler.
"""

import datetime
import decimal
import sys
import unittest

import oracledb
import test_env

class TestCase(test_env.BaseTestCase):

    def __test_type_handler(self, input_type, output_type, in_value,
                            expected_out_value):
        def type_handler(cursor, name, default_type, size, precision, scale):
            return cursor.var(output_type, arraysize=cursor.arraysize)
        self.cursor.outputtypehandler = type_handler
        var = self.cursor.var(input_type)
        var.setvalue(0, in_value)
        self.cursor.execute("select :1 from dual", [var])
        fetched_value, = self.cursor.fetchone()
        self.assertEqual(type(fetched_value), type(expected_out_value))
        self.assertEqual(fetched_value, expected_out_value)

    def __test_type_handler_blob(self, output_type):
        def type_handler(cursor, name, default_type, size, precision, scale):
            if default_type == oracledb.DB_TYPE_BLOB:
                return cursor.var(output_type, arraysize=cursor.arraysize)
        self.cursor.outputtypehandler = type_handler
        in_value = b"Some binary data"
        self.cursor.execute("truncate table TestBLOBs")
        self.cursor.execute("insert into TestBLOBs values(1, :val)",
                            val=in_value)
        self.connection.commit()
        self.cursor.execute("select BlobCol, IntCol, BlobCol from TestBLOBs")
        self.assertEqual(self.cursor.fetchone(), (in_value, 1, in_value))

    def __test_type_handler_clob(self, output_type):
        def type_handler(cursor, name, default_type, size, precision, scale):
            if default_type == oracledb.DB_TYPE_CLOB:
                return cursor.var(output_type, arraysize=cursor.arraysize)
        self.cursor.outputtypehandler = type_handler
        in_value = "Some clob data"
        self.cursor.execute("truncate table TestCLOBs")
        self.cursor.execute("insert into TestCLOBs values(1, :val)",
                            val=in_value)
        self.connection.commit()
        self.cursor.execute("select ClobCol, IntCol, ClobCol from TestCLOBs")
        self.assertEqual(self.cursor.fetchone(), (in_value, 1, in_value))

    def __test_type_handler_nclob(self, output_type):
        def type_handler(cursor, name, default_type, size, precision, scale):
            if default_type == oracledb.DB_TYPE_NCLOB:
                return cursor.var(output_type, arraysize=cursor.arraysize)
        self.cursor.outputtypehandler = type_handler
        in_value = "Some nclob data"
        self.cursor.execute("truncate table TestNCLOBs")
        self.cursor.execute("insert into TestNCLOBs values(1, :val)",
                            val=in_value)
        self.connection.commit()
        self.cursor.execute("select NClobCol, IntCol, NClobCol from TestNCLOBs")
        self.assertEqual(self.cursor.fetchone(), (in_value, 1, in_value))

    def setUp(self):
        super().setUp()
        stmt = "ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD HH24:MI:SS'" \
               "NLS_TIMESTAMP_FORMAT = 'YYYY-MM-DD HH24:MI:SS.FF6'" \
               "NLS_TIMESTAMP_TZ_FORMAT = 'YYYY-MM-DD HH24:MI:SS.FF6'" \
               "time_zone='Europe/London'"
        self.cursor.execute(stmt)

    def test_3674_cursor_description_unchanged(self):
        "3674 - use of output type handler does not affect name"
        def type_handler(cursor, name, default_type, size, precision, scale):
            return cursor.var(str, arraysize=cursor.arraysize)
        with self.connection.cursor() as cursor:
            cursor.execute("select 25 from dual")
            desc_before = cursor.description
        with self.connection.cursor() as cursor:
            cursor.outputtypehandler = type_handler
            cursor.execute("select 25 from dual")
            self.assertEqual(cursor.description, desc_before)

if __name__ == "__main__":
    test_env.run_test_cases()
