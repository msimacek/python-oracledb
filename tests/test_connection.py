#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

import base
import oracledb

class TestCase(base.BaseTestCase):

    def setUp(self):
        pass

    def tearDown(self):
        pass

    def test_bad_password(self):
        "connection to database with bad password"
        thin = base.get_is_thin()
        self.assertRaises(oracledb.DatabaseError, oracledb.connect,
                base.get_connect_string(), user=base.get_main_user(),
                password=base.get_main_password() + "X", thin=thin)

    def test_version(self):
        "connection version is a string"
        conn = base.get_connection()
        self.assertTrue(isinstance(conn.version, str))


if __name__ == "__main__":
    base.run_test_cases()
