#------------------------------------------------------------------------------
# Copyright (c) 2020, 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

"""
1100 - Module for testing connections
"""

import random
import string
import threading
import time
import unittest

import oracledb
import test_env

class TestCase(test_env.BaseTestCase):
    requires_connection = False

    def __connect_and_drop(self):
        """Connect to the database, perform a query and drop the connection."""
        connection = test_env.get_connection(threaded=True)
        cursor = connection.cursor()
        cursor.execute("select count(*) from TestNumbers")
        count, = cursor.fetchone()
        self.assertEqual(count, 10)

    def __verify_fetched_data(self, connection):
        expected_data = [f"String {i + 1}" for i in range(10)]
        sql = "select StringCol from TestStrings order by IntCol"
        for i in range(5):
            with connection.cursor() as cursor:
                fetched_data = [s for s, in cursor.execute(sql)]
                self.assertEqual(fetched_data, expected_data)

    def __verify_args(self, connection):
        self.assertEqual(connection.username, test_env.get_main_user(),
                         "user name differs")
        self.assertEqual(connection.dsn, test_env.get_connect_string(),
                         "dsn differs")

    def __verify_attributes(self, connection, attrName, value, sql):
        setattr(connection, attrName, value)
        cursor = connection.cursor()
        cursor.execute(sql)
        result, = cursor.fetchone()
        self.assertEqual(result, value, "%s value mismatch" % attrName)

    def test_1103_attributes(self):
        "1103 - test connection end-to-end tracing attributes"
        connection = test_env.get_connection()
        if test_env.get_client_version() >= (12, 1) \
                and not self.is_on_oracle_cloud(connection):
            sql = "select dbop_name from v$sql_monitor " \
                  "where sid = sys_context('userenv', 'sid')" \
                  "and status = 'EXECUTING'"
            self.__verify_attributes(connection, "dbop", "oracledb_dbop", sql)
        sql = "select sys_context('userenv', 'action') from dual"
        self.__verify_attributes(connection, "action", "oracledb_Action", sql)
        sql = "select sys_context('userenv', 'module') from dual"
        self.__verify_attributes(connection, "module", "oracledb_Module", sql)
        sql = "select sys_context('userenv', 'client_info') from dual"
        self.__verify_attributes(connection, "clientinfo", "oracledb_cinfo",
                                 sql)
        sql = "select sys_context('userenv', 'client_identifier') from dual"
        self.__verify_attributes(connection, "client_identifier",
                                 "oracledb_cid", sql)
        if not oracledb.defaults.thin:
            sql = "select ecid from v$session " \
                  "where sid = sys_context('userenv', 'sid')"
            self.__verify_attributes(connection, "econtext_id",
                                     "oracledb_ecid" + "X" * 100, sql)

if __name__ == "__main__":
    test_env.run_test_cases()
