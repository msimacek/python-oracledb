#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

"""
3100 - Module for testing boolean variables
"""

import unittest
import test_env

import oracledb

@unittest.skipUnless(test_env.get_client_version() >= (12, 1),
                     "unsupported client")
class TestCase(test_env.BaseTestCase):

    def __test_bind_value_as_boolean(self, value):
        expected_result = str(bool(value)).upper()
        var = self.cursor.var(bool)
        var.setvalue(0, value)
        result = self.cursor.callfunc("pkg_TestBooleans.GetStringRep", str,
                                      (var,))
        self.assertEqual(result, expected_result)

    def test_3100_bind_false(self):
        "3100 - test binding in a False value"
        result = self.cursor.callfunc("pkg_TestBooleans.GetStringRep", str,
                                      (False,))
        self.assertEqual(result, "FALSE")

if __name__ == "__main__":
    test_env.run_test_cases()
