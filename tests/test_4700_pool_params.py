#------------------------------------------------------------------------------
# Copyright (c) 2022, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

"""
4700 - Module for testing pool parameters.
"""

import oracledb
import test_env

class TestCase(test_env.BaseTestCase):
    requires_connection = False

    def __test_writable_parameter(self, name, value):
        """
        Tests that a writable parameter can be written to and the modified
        value read back successfully.
        """
        params = oracledb.PoolParams()
        setattr(params, name, value)
        self.assertEqual(getattr(params, name), value)

    def test_4700_writable_params(self):
        "4700 - test writable parameters"
        self.__test_writable_parameter("min", 8)
        self.__test_writable_parameter("max", 12)
        self.__test_writable_parameter("increment", 2)
        self.__test_writable_parameter("connectiontype", oracledb.Connection)
        self.__test_writable_parameter("getmode", oracledb.POOL_GETMODE_NOWAIT)
        self.__test_writable_parameter("homogeneous", False)
        self.__test_writable_parameter("externalauth", True)
        self.__test_writable_parameter("timeout", 25)
        self.__test_writable_parameter("wait_timeout", 45)
        self.__test_writable_parameter("max_lifetime_session", 65)
        self.__test_writable_parameter("session_callback", lambda c: None)
        self.__test_writable_parameter("max_sessions_per_shard", 5)
        self.__test_writable_parameter("soda_metadata_cache", True)
        self.__test_writable_parameter("ping_interval", 20)

if __name__ == "__main__":
    test_env.run_test_cases()
