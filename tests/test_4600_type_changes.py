#------------------------------------------------------------------------------
# Copyright (c) 2022, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

"""
4600 - Module for testing the handling of type changes in queries.
"""

import unittest

import oracledb
import test_env

class TestCase(test_env.BaseTestCase):

    def __test_type_change(self, query_frag_1, query_value_1, query_frag_2,
                           query_value_2):
        self.cursor.execute(f"""
                create or replace view TestTypesChanged as
                select {query_frag_1} as value
                from dual""")
        self.cursor.execute("select * from TestTypesChanged")
        self.assertEqual(self.cursor.fetchall(), [(query_value_1,)])
        self.cursor.execute(f"""
                create or replace view TestTypesChanged as
                select {query_frag_2} as value
                from dual""")
        self.cursor.execute("select * from TestTypesChanged")
        self.assertEqual(self.cursor.fetchall(), [(query_value_2,)])

    @unittest.skipIf(not test_env.get_is_thin(),
                     "thick driver doesn't support this type change")
    def test_4600_VARCHAR_to_CLOB(self):
        "4600 - test data type changing from VARCHAR to CLOB"
        self.__test_type_change("cast('string_4600' as VARCHAR2(15))",
                                "string_4600", "to_clob('clob_4600')",
                                "clob_4600")

if __name__ == "__main__":
    test_env.run_test_cases()
