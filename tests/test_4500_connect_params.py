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

    def test_4503_simple_connect_descriptor(self):
        "4503 - test simple name-value pair format connect string"
        connect_string = \
            "(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=my_host4)(PORT=1589))" \
            "(CONNECT_DATA=(SERVICE_NAME=my_service_name4)))"
        params = oracledb.ConnectParams()
        params.parse_connect_string(connect_string)
        self.assertEqual(params.host, "my_host4")
        self.assertEqual(params.port, 1589)
        self.assertEqual(params.service_name, "my_service_name4")

    def test_4504_search_tnsnames(self):
        "4504 - test simple tnsnames entry"
        connect_string = \
            "(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=my_host5)(PORT=1624))" \
            "(CONNECT_DATA=(SERVICE_NAME=my_service_name5)))"
        alias = "tns_alias = " + connect_string
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
        connect_string = \
            "(DESCRIPTION=(ADDRESS=(PROTOCOL=ipc)(KEY=my_view8))" \
            "(CONNECT_DATA=(SERVICE_NAME=my_service_name8)))"
        params = oracledb.ConnectParams()
        self.assertRaisesRegex(oracledb.DatabaseError, "^DPY-4021:",
                               params.parse_connect_string, connect_string)

    def test_4508_retry_count_and_delay(self):
        "4508 - connect descriptor with retry count and retry delay"
        connect_string = \
            "(DESCRIPTION=(RETRY_COUNT=6)(RETRY_DELAY=5)" \
            "(ADDRESS=(PROTOCOL=TCP)(HOST=my_host9)(PORT=1593))" \
            "(CONNECT_DATA=(SERVICE_NAME=my_service_name9)))"
        params = oracledb.ConnectParams()
        params.parse_connect_string(connect_string)
        self.assertEqual(params.retry_count, 6)
        self.assertEqual(params.retry_delay, 5)

    def test_4509_keepalive_basic(self):
        "4509 - connect descriptor with basic keepalive setting"
        connect_string = \
            "(DESCRIPTION=(ENABLE=BROKEN)" \
            "(ADDRESS=(PROTOCOL=TCP)(HOST=my_host10)(PORT=1594))" \
            "(CONNECT_DATA=(SERVICE_NAME=my_service_name10)))"
        params = oracledb.ConnectParams()
        params.parse_connect_string(connect_string)
        self.assertEqual(params.enable_keepalive, True)

    def test_4510_keepalive_tuned(self):
        "4510 - connect descriptor tuned keepalive setting"
        connect_string = \
            "(DESCRIPTION=(EXPIRE_TIME=12)" \
            "(ADDRESS=(PROTOCOL=TCP)(HOST=my_host11)(PORT=1594))" \
            "(CONNECT_DATA=(SERVICE_NAME=my_service_name11)))"
        params = oracledb.ConnectParams()
        params.parse_connect_string(connect_string)
        self.assertEqual(params.keepalive_idle_time, 12)

    def test_4511_pool_parameters(self):
        "4511 - connect descriptor with pool parameters"
        connect_string = \
            "(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=my_host12)(PORT=694))" \
            "(CONNECT_DATA=(SERVICE_NAME=my_service_name12)" \
            "(POOL_CONNECTION_CLASS=cclass_12)(POOL_PURITY=SELF)))"
        params = oracledb.ConnectParams()
        params.parse_connect_string(connect_string)
        self.assertEqual(params.cclass, "cclass_12")
        self.assertEqual(params.purity, oracledb.PURITY_ANY)
        connect_string = connect_string.replace("SELF", "NEW")
        params.parse_connect_string(connect_string)
        self.assertEqual(params.purity, oracledb.PURITY_NEW)

    def test_4512_invalid_pool_purity(self):
        "4512 - connect descriptor with invalid pool purity"
        connect_string = \
            "(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=my_host13)(PORT=695))" \
            "(CONNECT_DATA=(SERVICE_NAME=my_service_name13)" \
            "(POOL_CONNECTION_CLASS=cclass_13)(POOL_PURITY=INVALID)))"
        params = oracledb.ConnectParams()
        self.assertRaisesRegex(oracledb.DatabaseError, "^DPY-4022:",
                               params.parse_connect_string, connect_string)

    def test_4513_tcp_connect_timeout(self):
        "4513 - connect descriptor with transport connect timeout values"
        connect_string = \
            "(DESCRIPTION=(TRANSPORT_CONNECT_TIMEOUT=500 ms)" \
            "(ADDRESS=(PROTOCOL=TCP)(HOST=my_host14)(PORT=695))" \
            "(CONNECT_DATA=(SERVICE_NAME=my_service_name14)))"
        params = oracledb.ConnectParams()
        params.parse_connect_string(connect_string)
        self.assertEqual(params.tcp_connect_timeout, 0.5)
        connect_string = connect_string.replace("500 ms", "15 SEC")
        params.parse_connect_string(connect_string)
        self.assertEqual(params.tcp_connect_timeout, 15)
        connect_string = connect_string.replace("15 SEC", "5 min")
        params.parse_connect_string(connect_string)
        self.assertEqual(params.tcp_connect_timeout, 300)
        connect_string = connect_string.replace("5 min", "34")
        params.parse_connect_string(connect_string)
        self.assertEqual(params.tcp_connect_timeout, 34)

    def test_4514_ezconnect_without_service_name(self):
        "4514 - test EZConnect string parsing with no service name specified"
        params = oracledb.ConnectParams()
        params.parse_connect_string("my_host15:1578")
        self.assertEqual(params.host, "my_host15")
        self.assertEqual(params.port, 1578)
        self.assertEqual(params.service_name, "")

    def test_4515_ezconnect_without_port_and_service_name(self):
        "4515 - test EZConnect string parsing with no port and service name"
        params = oracledb.ConnectParams()
        self.assertRaisesRegex(oracledb.DatabaseError, "DPY-4000",
                               params.parse_connect_string, "my_host16")

    def test_4516_ezconnect_with_port_missing(self):
        "4516 - test EZConnect string parsing with port value missing"
        params = oracledb.ConnectParams()
        params.parse_connect_string("my_host17:/my_service_name17")
        self.assertEqual(params.host, "my_host17")
        self.assertEqual(params.port, 1521)
        self.assertEqual(params.service_name, "my_service_name17")

if __name__ == "__main__":
    test_env.run_test_cases()
