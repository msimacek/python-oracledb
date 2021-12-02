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
        self.assertEqual(params.protocol, "tcps")

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

    def test_4509_connect_descriptor_expire_time(self):
        "4509 - connect descriptor with expire_time setting"
        connect_string = \
            "(DESCRIPTION=(EXPIRE_TIME=12)" \
            "(ADDRESS=(PROTOCOL=TCP)(HOST=my_host11)(PORT=1594))" \
            "(CONNECT_DATA=(SERVICE_NAME=my_service_name11)))"
        params = oracledb.ConnectParams()
        params.parse_connect_string(connect_string)
        self.assertEqual(params.expire_time, 12)

    def test_4510_pool_parameters(self):
        "4510 - connect descriptor with pool parameters"
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

    def test_4511_invalid_pool_purity(self):
        "4511 - connect descriptor with invalid pool purity"
        connect_string = \
            "(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=my_host13)(PORT=695))" \
            "(CONNECT_DATA=(SERVICE_NAME=my_service_name13)" \
            "(POOL_CONNECTION_CLASS=cclass_13)(POOL_PURITY=INVALID)))"
        params = oracledb.ConnectParams()
        self.assertRaisesRegex(oracledb.DatabaseError, "^DPY-4022:",
                               params.parse_connect_string, connect_string)

    def test_4512_tcp_connect_timeout(self):
        "4512 - connect descriptor with transport connect timeout values"
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

    def test_4513_ezconnect_without_service_name(self):
        "4513 - test EZConnect string parsing with no service name specified"
        params = oracledb.ConnectParams()
        params.parse_connect_string("my_host15:1578")
        self.assertEqual(params.host, "my_host15")
        self.assertEqual(params.port, 1578)
        self.assertEqual(params.service_name, "")

    def test_4514_ezconnect_without_port_and_service_name(self):
        "4514 - test EZConnect string parsing with no port and service name"
        params = oracledb.ConnectParams()
        self.assertRaisesRegex(oracledb.DatabaseError, "DPY-4000",
                               params.parse_connect_string, "my_host16")

    def test_4515_ezconnect_with_port_missing(self):
        "4515 - test EZConnect string parsing with port value missing"
        params = oracledb.ConnectParams()
        params.parse_connect_string("my_host17:/my_service_name17")
        self.assertEqual(params.host, "my_host17")
        self.assertEqual(params.port, 1521)
        self.assertEqual(params.service_name, "my_service_name17")

    def test_4516_invalid_number_in_connect_string(self):
        "4516 - test connect descriptor with invalid number"
        params = oracledb.ConnectParams()
        connect_string = \
            "(DESCRIPTION=(RETRY_COUNT=wrong)(RETRY_DELAY=5)" \
            "(ADDRESS=(PROTOCOL=TCP)(HOST=my_host18)(PORT=1598))" \
            "(CONNECT_DATA=(SERVICE_NAME=my_service_name18)))"
        self.assertRaisesRegex(oracledb.DatabaseError, "DPY-4018",
                               params.parse_connect_string, connect_string)

    def test_4517_security_options(self):
        "4517 - test connect descriptor with security options"
        params = oracledb.ConnectParams()
        connect_string = \
            '(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=my_host19)(PORT=872))' \
            '(CONNECT_DATA=(SERVICE_NAME=my_service_name19))' \
            '(SECURITY=(SSL_SERVER_CERT_DN="CN=unknown19")' \
            '(MY_WALLET_DIRECTORY="/wallet_loc19")))'
        params.parse_connect_string(connect_string)
        self.assertEqual(params.ssl_server_cert_dn, "CN=unknown19")
        self.assertEqual(params.wallet_location, "/wallet_loc19")

    def test_4518_ezconnect_security_options(self):
        "4518 - test easy connect string with security options"
        params = oracledb.ConnectParams()
        connect_string = 'my_host20/my_server_name20?' \
            'ssl_server_cert_dn="CN=unknown20"&' \
            'ssl_server_dn_match= off &' \
            'wallet_location = "/wallet_loc20"'
        params.parse_connect_string(connect_string)
        self.assertEqual(params.ssl_server_cert_dn, "CN=unknown20")
        self.assertEqual(params.ssl_server_dn_match, False)
        self.assertEqual(params.wallet_location, "/wallet_loc20")

    def test_4519_ezconnect_description_options(self):
        "4519 - test easy connect string with description options"
        params = oracledb.ConnectParams()
        connect_string = 'my_host21/my_server_name21?' \
            'expire_time=5&' \
            'retry_delay=10&' \
            'retry_count=12&' \
            'transport_connect_timeout=2.5'
        params.parse_connect_string(connect_string)
        self.assertEqual(params.expire_time, 5)
        self.assertEqual(params.retry_delay, 10)
        self.assertEqual(params.retry_count, 12)
        self.assertEqual(params.tcp_connect_timeout, 2.5)

    def test_4520_ezconnect_invalid_parameters(self):
        "4520 - test easy connect string with invalid parameters"
        params = oracledb.ConnectParams()
        connect_string_prefix = 'my_host22/my_server_name22?'
        suffixes = [
            'unknown_parameter=5',
            'expire_time=invalid',
            'expire_time'
        ]
        for suffix in suffixes:
            self.assertRaisesRegex(oracledb.DatabaseError, "DPY-4023",
                                   params.parse_connect_string,
                                   connect_string_prefix + suffix)

    def test_4521_connect_string_with_newlines_and_spaces(self):
        "4521 - test connect string containing spaces and newlines"
        params = oracledb.ConnectParams()
        connect_string = \
            '(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP) \n(HOST=my_host23)\n' \
            '(PORT=1560))(CONNECT_DATA=  (SERVICE_NAME=my_service_name23))' \
            '(SECURITY=(MY_WALLET_DIRECTORY="my wallet dir 23")))'
        params.parse_connect_string(connect_string)
        self.assertEqual(params.host, "my_host23")
        self.assertEqual(params.port, 1560)
        self.assertEqual(params.service_name, "my_service_name23")
        self.assertEqual(params.wallet_location, "my wallet dir 23")

if __name__ == "__main__":
    test_env.run_test_cases()
