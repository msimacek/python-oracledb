#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Sets the environment used by the oracledb test suite. Production applications
# should consider using External Authentication to avoid hard coded
# credentials.
#
# You can set values in environment variables to bypass having the test suite
# request the information it requires.
#
#     PY_ORACLEDB_TEST_MAIN_USER: user used for most test cases
#     PY_ORACLEDB_TEST_MAIN_PASSWORD: password of user used for most test cases
#     PY_ORACLEDB_TEST_PROXY_USER: user for testing proxying
#     PY_ORACLEDB_TEST_PROXY_PASSWORD: password of user for testing proxying
#     PY_ORACLEDB_TEST_CONNECT_STRING: connect string for test suite
#     PY_ORACLEDB_TEST_ADMIN_USER: administrative user for test suite
#     PY_ORACLEDB_TEST_ADMIN_PASSWORD: administrative password for test suite
#     PY_ORACLEDB_TEST_DRIVER_TYPE: type of driver (thick|thin) to use
#
# PY_ORACLEDB_TEST_CONNECT_STRING can be set to an Easy Connect string, or a
# Net Service Name from a tnsnames.ora file or external naming service,
# or it can be the name of a local Oracle database instance.
#
# If oracledb is using Instant Client, then an Easy Connect string is generally
# appropriate. The syntax is:
#
#   [//]host_name[:port][/service_name][:server_type][/instance_name]
#
# Commonly just the host_name and service_name are needed
# e.g. "localhost/orclpdb1" or "localhost/XEPDB1"
#
# If using a tnsnames.ora file, the file can be in a default
# location such as $ORACLE_HOME/network/admin/tnsnames.ora or
# /etc/tnsnames.ora.  Alternatively set the TNS_ADMIN environment
# variable and put the file in $TNS_ADMIN/tnsnames.ora.
#
# The administrative user for cloud databases is ADMIN and the administrative
# user for on premises databases is SYSTEM.
#------------------------------------------------------------------------------

import oracledb

import getpass
import os
import sys
import unittest

# default values
DEFAULT_MAIN_USER = "pythontest"
DEFAULT_PROXY_USER = "pythontestproxy"
DEFAULT_CONNECT_STRING = "localhost/orclpdb1"

# dictionary containing all parameters; these are acquired as needed by the
# methods below (which should be used instead of consulting this dictionary
# directly) and then stored so that a value is not requested more than once
PARAMETERS = {}

def get_value(name, label, default_value=""):
    value = PARAMETERS.get(name)
    if value is not None:
        return value
    env_name = "PY_ORACLEDB_TEST_" + name
    value = os.environ.get(env_name)
    if value is None:
        if default_value:
            label += " [%s]" % default_value
        label += ": "
        if default_value:
            value = input(label).strip()
        else:
            value = getpass.getpass(label)
        if not value:
            value = default_value
    PARAMETERS[name] = value
    return value

def get_admin_connect_string():
    admin_user = get_value("ADMIN_USER", "Administrative user", "admin")
    admin_password = get_value("ADMIN_PASSWORD",
                               "Password for %s" % admin_user)
    return "%s/%s@%s" % (admin_user, admin_password, get_connect_string())

def get_connection(**kwargs):
    return oracledb.connect(get_connect_string(), user=get_main_user(),
            password=get_main_password(), thin=get_is_thin(), **kwargs)

def get_connect_string():
    return get_value("CONNECT_STRING", "Connect String",
                     DEFAULT_CONNECT_STRING)

def get_driver_type():
    return get_value("DRIVER_TYPE", "Driver type (thin|thick)", "thin")

def get_is_thin():
    return get_driver_type() == "thin"

def get_main_password():
    return get_value("MAIN_PASSWORD", "Password for %s" % get_main_user())

def get_main_user():
    return get_value("MAIN_USER", "Main User Name", DEFAULT_MAIN_USER)

def get_proxy_password():
    return get_value("PROXY_PASSWORD", "Password for %s" % get_proxy_user())

def get_proxy_user():
    return get_value("PROXY_USER", "Proxy User Name", DEFAULT_PROXY_USER)

def run_sql_script(conn, script_name, **kwargs):
    statement_parts = []
    cursor = conn.cursor()
    replace_values = [("&" + k + ".", v) for k, v in kwargs.items()] + \
                     [("&" + k, v) for k, v in kwargs.items()]
    script_dir = os.path.dirname(os.path.abspath(sys.argv[0]))
    file_name = os.path.join(script_dir, "sql", script_name + "Exec.sql")
    for line in open(file_name):
        if line.strip() == "/":
            statement = "".join(statement_parts).strip()
            if statement:
                for search_value, replace_value in replace_values:
                    statement = statement.replace(search_value, replace_value)
                try:
                    cursor.execute(statement)
                except:
                    print("Failed to execute SQL:", statement)
                    raise
            statement_parts = []
        else:
            statement_parts.append(line)
    cursor.execute("""
            select name, type, line, position, text
            from dba_errors
            where owner = upper(:owner)
            order by name, type, line, position""",
            owner = get_main_user())
    prev_name = prev_obj_type = None
    for name, obj_type, line_num, position, text in cursor:
        if name != prev_name or obj_type != prev_obj_type:
            print("%s (%s)" % (name, obj_type))
            prev_name = name
            prev_obj_type = obj_type
        print("    %s/%s %s" % (line_num, position, text))

def run_test_cases():
    unittest.main(testRunner=unittest.TextTestRunner(verbosity=2))


class BaseTestCase(unittest.TestCase):
    requires_connection = True

    def is_on_oracle_cloud(self, connection=None):
        if connection is None:
            connection = self.connection
        cursor = connection.cursor()
        cursor.execute("""
                select sys_context('userenv', 'service_name')
                from dual""")
        service_name, = cursor.fetchone()
        return service_name.endswith("oraclecloud.com")

    def setUp(self):
        if self.requires_connection:
            self.connection = get_connection()
            self.cursor = self.connection.cursor()

    def tearDown(self):
        if self.requires_connection:
            self.connection.close()
            del self.cursor
            del self.connection
