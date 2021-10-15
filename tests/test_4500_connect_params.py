#------------------------------------------------------------------------------
# Copyright (c) 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

"""
4500 - Module for testing connection parameters.
"""

import os
import tempfile

import oracledb
import test_env

class TestCase(test_env.BaseTestCase):
    requires_connection = False

    def test_4500_simple_ezconnect_with_port(self):
        "4500 - test simple EZConnect string parsing with port specified"
        params = oracledb.ConnectParams()
        params.parse_connect_string("my_host:1578/my_service_name")
        self.assertEqual(params.host, "my_host")
        self.assertEqual(params.port, 1578)
        self.assertEqual(params.service_name, "my_service_name")

    def test_4501_simple_ezconnect_without_port(self):
        "4501 - test simple EZConnect string parsing with no port specified"
        params = oracledb.ConnectParams()
        params.parse_connect_string("my_host2/my_service_name2")
        self.assertEqual(params.host, "my_host2")
        self.assertEqual(params.port, 1521)
        self.assertEqual(params.service_name, "my_service_name2")

    def test_4502_simple_ezconnect_with_drcp(self):
        "4502 - test simple EZConnect string parsing with DRCP enabled"
        params = oracledb.ConnectParams()
        params.parse_connect_string("my_host3/my_service_name3:pooled")
        self.assertEqual(params.host, "my_host3")
        self.assertEqual(params.service_name, "my_service_name3")
        self.assertEqual(params.enable_drcp, True)

    def test_4503_simple_nvpair_data(self):
        "4503 - test simple name-value pair format connect string"
        nvpair_data = \
            "(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=my_host4)(PORT=1589))" \
            "(CONNECT_DATA=(SERVICE_NAME=my_service_name4)))"
        params = oracledb.ConnectParams()
        params.parse_connect_string(nvpair_data)
        self.assertEqual(params.host, "my_host4")
        self.assertEqual(params.port, 1589)
        self.assertEqual(params.service_name, "my_service_name4")

    def test_4504_search_tnsnames(self):
        "4504 - test simple tnsnames entry"
        nvpair_data = \
            "(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=my_host5)(PORT=1624))" \
            "(CONNECT_DATA=(SERVICE_NAME=my_service_name5)))"
        alias = "tns_alias = " + nvpair_data
        with tempfile.TemporaryDirectory() as temp_dir:
            file_name = os.path.join(temp_dir, "tnsnames.ora")
            open(file_name, "w").write(alias)
            params = oracledb.ConnectParams(config_dir=temp_dir)
            params.parse_connect_string("tns_alias")
        self.assertEqual(params.host, "my_host5")
        self.assertEqual(params.port, 1624)
        self.assertEqual(params.service_name, "my_service_name5")

    def test_4505_ezconnect_with_protocol(self):
        "4505 - test EZConnect with protocol"
        params = oracledb.ConnectParams()
        params.parse_connect_string("tcps://my_host6/my_service_name6")
        self.assertEqual(params.host, "my_host6")
        self.assertEqual(params.service_name, "my_service_name6")
        self.assertEqual(params.secure_transport, True)

    def test_4506_ezconnect_with_invalid_protocol(self):
        "4506 - test EZConnect with invalid protocol"
        params = oracledb.ConnectParams()
        self.assertRaisesRegex(oracledb.DatabaseError, "^DPY-4021:",
                               params.parse_connect_string,
                               "invalid_proto://my_host7/my_service_name7")

    def test_4507_exception_on_ipc_protocol(self):
        "4507 - confirm an exception is raised if using ipc protocol"
        nvpair_data = \
            "(DESCRIPTION=(ADDRESS=(PROTOCOL=ipc)(KEY=my_view8))" \
            "(CONNECT_DATA=(SERVICE_NAME=my_service_name8)))"
        params = oracledb.ConnectParams()
        self.assertRaisesRegex(oracledb.DatabaseError, "^DPY-4021:",
                               params.parse_connect_string, nvpair_data)

    def test_4508_retry_count_and_delay(self):
        "4508 - name/value pair with retry count and retry delay"
        nvpair_data = \
            "(DESCRIPTION=(RETRY_COUNT=6)(RETRY_DELAY=5)" \
            "(ADDRESS=(PROTOCOL=TCP)(HOST=my_host9)(PORT=1593))" \
            "(CONNECT_DATA=(SERVICE_NAME=my_service_name9)))"
        params = oracledb.ConnectParams()
        params.parse_connect_string(nvpair_data)
        self.assertEqual(params.retry_count, 6)
        self.assertEqual(params.retry_delay, 5)

    def test_4509_keepalive_basic(self):
        "4509 - name/value pair with basic keepalive setting"
        nvpair_data = \
            "(DESCRIPTION=(ENABLE=BROKEN)" \
            "(ADDRESS=(PROTOCOL=TCP)(HOST=my_host10)(PORT=1594))" \
            "(CONNECT_DATA=(SERVICE_NAME=my_service_name10)))"
        params = oracledb.ConnectParams()
        params.parse_connect_string(nvpair_data)
        self.assertEqual(params.enable_keepalive, True)

    def test_4510_keepalive_tuned(self):
        "4510 - name/value pair tuned keepalive setting"
        nvpair_data = \
            "(DESCRIPTION=(EXPIRE_TIME=12)" \
            "(ADDRESS=(PROTOCOL=TCP)(HOST=my_host11)(PORT=1594))" \
            "(CONNECT_DATA=(SERVICE_NAME=my_service_name11)))"
        params = oracledb.ConnectParams()
        params.parse_connect_string(nvpair_data)
        self.assertEqual(params.keepalive_idle_time, 12)

if __name__ == "__main__":
    test_env.run_test_cases()
