#------------------------------------------------------------------------------
# Copyright (c) 2020, 2022, Oracle and/or its affiliates.
# This program is free software: you can modify it and/or redistribute it
# under the terms of:
#
# (i)  the Universal Permissive License v 1.0 or at your option, any
#      later version (http://oss.oracle.com/licenses/upl); and/or
#
# (ii) the Apache License v 2.0. (http://www.apache.org/licenses/LICENSE-2.0)
#------------------------------------------------------------------------------

"""
1000 - Module for testing top-level module methods
"""

import datetime
import time

import oracledb
import test_env

class TestCase(test_env.BaseTestCase):
    requires_connection = False

    def test_1000_date_from_ticks(self):
        "1000 - test DateFromTicks()"
        today = datetime.datetime.today()
        timestamp = time.mktime(today.timetuple())
        date = oracledb.DateFromTicks(timestamp)
        self.assertEqual(date, today.date())

    def test_1001_future_obj(self):
        "1001 - test management of __future__ object"
        self.assertEqual(oracledb.__future__.dummy, None)
        oracledb.__future__.dummy = "Unimportant"
        self.assertEqual(oracledb.__future__.dummy, None)

    def test_1002_timestamp_from_ticks(self):
        "1002 - test TimestampFromTicks()"
        timestamp = time.mktime(datetime.datetime.today().timetuple())
        today = datetime.datetime.fromtimestamp(timestamp)
        date = oracledb.TimestampFromTicks(timestamp)
        self.assertEqual(date, today)

    def test_1003_unsupported_functions(self):
        "1003 - test unsupported time functions"
        self.assertRaisesRegex(oracledb.NotSupportedError, "^DPY-3000:",
                               oracledb.Time, 12, 0, 0)
        self.assertRaisesRegex(oracledb.NotSupportedError, "^DPY-3000:",
                               oracledb.TimeFromTicks, 100)

    def test_1004_makedsn(self):
        "1004 - test makedsn() with valid arguments"
        format_string = "(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)" + \
                        "(HOST=%s)(PORT=%d))(CONNECT_DATA=(SID=%s)))"
        args = ("hostname", 1521, "TEST")
        result = oracledb.makedsn(*args)
        self.assertEqual(result, format_string % args)

    def test_1005_makedsn_invalid_args(self):
        "1005 - test makedsn() with invalid arguments"
        self.assertRaisesRegex(oracledb.ProgrammingError, "^DPY-2020:",
                               oracledb.makedsn, host="(invalid)", port=1521)
        self.assertRaisesRegex(oracledb.ProgrammingError, "^DPY-2020:",
                               oracledb.makedsn, host="host", port=1521,
                               sid="(invalid)")
        self.assertRaisesRegex(oracledb.ProgrammingError, "^DPY-2020:",
                               oracledb.makedsn, host="host", port=1521,
                               service_name="(invalid)")
        self.assertRaisesRegex(oracledb.ProgrammingError, "^DPY-2020:",
                               oracledb.makedsn, host="host", port=1521,
                               region="(invalid)")
        self.assertRaisesRegex(oracledb.ProgrammingError, "^DPY-2020:",
                               oracledb.makedsn, host="host", port=1521,
                               sharding_key="(invalid)")
        self.assertRaisesRegex(oracledb.ProgrammingError, "^DPY-2020:",
                               oracledb.makedsn, host="host", port=1521,
                               super_sharding_key="(invalid)")

if __name__ == "__main__":
    test_env.run_test_cases()
