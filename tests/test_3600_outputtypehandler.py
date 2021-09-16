#------------------------------------------------------------------------------
# Copyright (c) 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

"""
3600 - Module for testing the conversions of outputtype handler.
"""

import datetime
import decimal
import sys
import unittest

import oracledb
import test_env

class TestCase(test_env.BaseTestCase):

    def __test_type_handler(self, input_type, output_type, in_value,
                            expected_out_value):
        def type_handler(cursor, name, default_type, size, precision, scale):
            return cursor.var(output_type, arraysize=cursor.arraysize)
        self.cursor.outputtypehandler = type_handler
        var = self.cursor.var(input_type)
        var.setvalue(0, in_value)
        self.cursor.execute("select :1 from dual", [var])
        fetched_value, = self.cursor.fetchone()
        self.assertEqual(type(fetched_value), type(expected_out_value))
        self.assertEqual(fetched_value, expected_out_value)

    def __test_type_handler_blob(self, output_type):
        def type_handler(cursor, name, default_type, size, precision, scale):
            if default_type == oracledb.DB_TYPE_BLOB:
                return cursor.var(output_type, arraysize=cursor.arraysize)
        self.cursor.outputtypehandler = type_handler
        in_value = b"Some binary data"
        self.cursor.execute("truncate table TestBLOBs")
        self.cursor.execute("insert into TestBLOBs values(1, :val)",
                            val=in_value)
        self.connection.commit()
        self.cursor.execute("select BlobCol, IntCol, BlobCol from TestBLOBs")
        self.assertEqual(self.cursor.fetchone(), (in_value, 1, in_value))

    def __test_type_handler_clob(self, output_type):
        def type_handler(cursor, name, default_type, size, precision, scale):
            if default_type == oracledb.DB_TYPE_CLOB:
                return cursor.var(output_type, arraysize=cursor.arraysize)
        self.cursor.outputtypehandler = type_handler
        in_value = "Some clob data"
        self.cursor.execute("truncate table TestCLOBs")
        self.cursor.execute("insert into TestCLOBs values(1, :val)",
                            val=in_value)
        self.connection.commit()
        self.cursor.execute("select ClobCol, IntCol, ClobCol from TestCLOBs")
        self.assertEqual(self.cursor.fetchone(), (in_value, 1, in_value))

    def __test_type_handler_nclob(self, output_type):
        def type_handler(cursor, name, default_type, size, precision, scale):
            if default_type == oracledb.DB_TYPE_NCLOB:
                return cursor.var(output_type, arraysize=cursor.arraysize)
        self.cursor.outputtypehandler = type_handler
        in_value = "Some nclob data"
        self.cursor.execute("truncate table TestNCLOBs")
        self.cursor.execute("insert into TestNCLOBs values(1, :val)",
                            val=in_value)
        self.connection.commit()
        self.cursor.execute("select NClobCol, IntCol, NClobCol from TestNCLOBs")
        self.assertEqual(self.cursor.fetchone(), (in_value, 1, in_value))

    def setUp(self):
        super().setUp()
        stmt = "ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD HH24:MI:SS'" \
               "NLS_TIMESTAMP_FORMAT = 'YYYY-MM-DD HH24:MI:SS.FF6'" \
               "NLS_TIMESTAMP_TZ_FORMAT = 'YYYY-MM-DD HH24:MI:SS.FF6'" \
               "time_zone='Europe/London'"
        self.cursor.execute(stmt)

    def test_3600_VARCHAR_to_NUMBER(self):
        "3600 - output type handler conversion from varchar to number"
        self.__test_type_handler(oracledb.DB_TYPE_VARCHAR,
                                 oracledb.DB_TYPE_NUMBER, "31.5", 31.5)

    def test_3601_CHAR_to_NUMBER(self):
        "3601 - output type handler conversion from char to number"
        self.__test_type_handler(oracledb.DB_TYPE_CHAR,
                                 oracledb.DB_TYPE_NUMBER, "31.5", 31.5)

    def test_3602_LONG_to_NUMBER(self):
        "3602 - output type handler conversion from long to number"
        self.__test_type_handler(oracledb.DB_TYPE_LONG,
                                 oracledb.DB_TYPE_NUMBER, "31.5", 31.5)

    def test_3603_BINT_to_NUMBER(self):
        "3603 - test output type handler conversion from integer to number"
        self.__test_type_handler(oracledb.DB_TYPE_BINARY_INTEGER,
                                 oracledb.DB_TYPE_NUMBER, 31, 31)

    def test_3604_VARCHAR_to_BINT(self):
        "3604 - output type handler conversion from varchar to integer"
        self.__test_type_handler(oracledb.DB_TYPE_VARCHAR,
                                 oracledb.DB_TYPE_BINARY_INTEGER, "31.5", 31)

    def test_3605_CHAR_to_BINT(self):
        "3605 - output type handler conversion from char to integer"
        self.__test_type_handler(oracledb.DB_TYPE_CHAR,
                                 oracledb.DB_TYPE_BINARY_INTEGER, "31.5", 31)

    def test_3606_LONG_to_BINT(self):
        "3606 - output type handler conversion from long to integer"
        self.__test_type_handler(oracledb.DB_TYPE_LONG,
                                 oracledb.DB_TYPE_BINARY_INTEGER, "31.5", 31)

    def test_3607_NUMBER_to_BINT(self):
        "3607 - output type handler conversion from number to integer"
        self.__test_type_handler(oracledb.DB_TYPE_NUMBER,
                                 oracledb.DB_TYPE_BINARY_INTEGER, 31.5, 31)

    def test_3608_BINARY_DOUBLE_to_BINT(self):
        "3608 - output type handler conversion from double to integer"
        self.__test_type_handler(oracledb.DB_TYPE_BINARY_DOUBLE,
                                 oracledb.DB_TYPE_BINARY_INTEGER, 31.5, 31)

    def test_3609_BINARY_FLOAT_to_BINT(self):
        "3609 - output type handler conversion from varchar to integer"
        self.__test_type_handler(oracledb.DB_TYPE_BINARY_FLOAT,
                                 oracledb.DB_TYPE_BINARY_INTEGER, 31.5, 31)

    def test_3610_DATE_to_VARCHAR(self):
        "3610 - output type handler conversion from date to varchar"
        in_val = datetime.date(2021, 2, 1)
        out_val = "2021-02-01 00:00:00"
        self.__test_type_handler(oracledb.DB_TYPE_DATE,
                                 oracledb.DB_TYPE_VARCHAR, in_val, out_val)

    def test_3611_DATE_to_CHAR(self):
        "3611 - output type handler conversion from date to char"
        in_val = datetime.date(2021, 2, 1)
        out_val = "2021-02-01 00:00:00"
        self.__test_type_handler(oracledb.DB_TYPE_DATE,
                                 oracledb.DB_TYPE_CHAR, in_val, out_val)

    def test_3612_DATE_to_LONG(self):
        "3612 - output type handler conversion from date to long"
        in_val = datetime.date(2021, 2, 1)
        out_val = "2021-02-01 00:00:00"
        self.__test_type_handler(oracledb.DB_TYPE_DATE,
                                 oracledb.DB_TYPE_LONG, in_val , out_val)

    def test_3613_NUMBER_to_VARCHAR(self):
        "3613 - output type handler conversion from number to varchar"
        self.__test_type_handler(oracledb.DB_TYPE_NUMBER,
                                 oracledb.DB_TYPE_VARCHAR, 31.5, "31.5")
        self.__test_type_handler(oracledb.DB_TYPE_NUMBER,
                                 oracledb.DB_TYPE_VARCHAR, 0, "0")

    def test_3614_NUMBER_to_CHAR(self):
        "3614 - output type handler conversion from number to char"
        self.__test_type_handler(oracledb.DB_TYPE_NUMBER,
                                 oracledb.DB_TYPE_CHAR, 31.5, "31.5")
        self.__test_type_handler(oracledb.DB_TYPE_NUMBER,
                                 oracledb.DB_TYPE_CHAR, 0, "0")

    def test_3615_NUMBER_to_LONG(self):
        "3615 - output type handler conversion from number to long"
        self.__test_type_handler(oracledb.DB_TYPE_NUMBER,
                                 oracledb.DB_TYPE_LONG, 31.5, "31.5")

    def test_3616_INTERVAL_to_VARCHAR(self):
        "3616 - output type handler conversion from interval to varchar"
        in_val = datetime.timedelta(days=-1, seconds=86314,
                                    microseconds=431152)
        if oracledb.defaults.thin:
            out_val = str(in_val)
        else:
            out_val = "-000000001 23:58:34.431152000"
        self.__test_type_handler(oracledb.DB_TYPE_INTERVAL_DS,
                                 oracledb.DB_TYPE_VARCHAR, in_val, out_val)

    def test_3617_INTERVAL_to_CHAR(self):
        "3617 - output type handler conversion from interval to char"
        in_val = datetime.timedelta(days=-1, seconds=86314,
                                    microseconds=431152)
        if oracledb.defaults.thin:
            out_val = str(in_val)
        else:
            out_val = "-000000001 23:58:34.431152000"
        self.__test_type_handler(oracledb.DB_TYPE_INTERVAL_DS,
                                 oracledb.DB_TYPE_CHAR, in_val, out_val)

    def test_3618_INTERVAL_to_LONG(self):
        "3618 - output type handler conversion from interval to long"
        in_val = datetime.timedelta(days=-1, seconds=86314,
                                    microseconds=431152)
        if oracledb.defaults.thin:
            out_val = str(in_val)
        else:
            out_val = "-000000001 23:58:34.431152000"
        self.__test_type_handler(oracledb.DB_TYPE_INTERVAL_DS,
                                 oracledb.DB_TYPE_LONG, in_val, out_val)

    def test_3619_TIMESTAMP_to_VARCHAR(self):
        "3619 - output type handler conversion from timestamp to varchar"
        in_val = datetime.datetime(2002, 12, 17, 1, 2, 16, 400000)
        self.__test_type_handler(oracledb.DB_TYPE_TIMESTAMP,
                                 oracledb.DB_TYPE_VARCHAR, in_val, str(in_val))

    def test_3620_TIMESTAMP_to_CHAR(self):
        "3620 - output type handler conversion from timestamp to char"
        in_val = datetime.datetime(2002, 12, 17, 1, 2, 16, 400000)
        self.__test_type_handler(oracledb.DB_TYPE_TIMESTAMP,
                                 oracledb.DB_TYPE_CHAR, in_val, str(in_val))

    def test_3621_TIMESTAMP_to_LONG(self):
        "3621 - output type handler conversion from timestamp to long"
        in_val = datetime.datetime(2002, 12, 17, 1, 2, 16, 400000)
        self.__test_type_handler(oracledb.DB_TYPE_TIMESTAMP,
                                 oracledb.DB_TYPE_LONG, in_val, str(in_val))

    def test_3622_TIMESTAMP_TZ_to_VARCHAR(self):
        "3622 - output type handler conversion from timestamptz to varchar"
        in_val = datetime.datetime(2002, 12, 17, 1, 2, 16, 400000)
        self.__test_type_handler(oracledb.DB_TYPE_TIMESTAMP_TZ,
                                 oracledb.DB_TYPE_VARCHAR, in_val, str(in_val))

    def test_3623_TIMESTAMP_TZ_to_CHAR(self):
        "3623 - output type handler conversion from timestamptz to char"
        in_val = datetime.datetime(2002, 12, 17, 1, 2, 16, 400000)
        self.__test_type_handler(oracledb.DB_TYPE_TIMESTAMP_TZ,
                                 oracledb.DB_TYPE_CHAR, in_val, str(in_val))

    def test_3624_TIMESTAMP_TZ_to_LONG(self):
        "3624 - output type handler conversion from timestamptz to long"
        in_val = datetime.datetime(2002, 12, 17, 1, 2, 16, 400000)
        self.__test_type_handler(oracledb.DB_TYPE_TIMESTAMP_TZ,
                                 oracledb.DB_TYPE_LONG, in_val, str(in_val))

    def test_3625_TIMESTAMP_LTZ_to_VARCHAR(self):
        "3625 - output type handler conversion from timestampltz to varchar"
        in_val = datetime.datetime(2002, 12, 17, 1, 2, 16, 400000)
        self.__test_type_handler(oracledb.DB_TYPE_TIMESTAMP_LTZ,
                                 oracledb.DB_TYPE_VARCHAR, in_val, str(in_val))

    def test_3626_TIMESTAMP_LTZ_to_CHAR(self):
        "3626 - output type handler conversion from timestamp_ltz to char"
        in_val = datetime.datetime(2002, 12, 17, 1, 2, 16, 400000)
        self.__test_type_handler(oracledb.DB_TYPE_TIMESTAMP_LTZ,
                                 oracledb.DB_TYPE_CHAR, in_val, str(in_val))

    def test_3627_TIMESTAMP_LTZ_to_LONG(self):
        "3627 - output type handler conversion from timestamp_LTZ to long"
        in_val = datetime.datetime(2002, 12, 17, 1, 2, 16, 400000)
        self.__test_type_handler(oracledb.DB_TYPE_TIMESTAMP_LTZ,
                                 oracledb.DB_TYPE_LONG, in_val, str(in_val))

    def test_3628_BINT_to_VARCHAR(self):
        "3628 - output type handler conversion from integer to varchar"
        self.__test_type_handler(oracledb.DB_TYPE_BINARY_INTEGER,
                                 oracledb.DB_TYPE_VARCHAR, 31, "31")

    def test_3629_BINT_to_CHAR(self):
        "3629 - output type handler conversion from integer to char"
        self.__test_type_handler(oracledb.DB_TYPE_BINARY_INTEGER,
                                 oracledb.DB_TYPE_CHAR, 31, "31")

    def test_3630_BINT_to_LONG(self):
        "3630 - output type handler conversion from integer to long"
        self.__test_type_handler(oracledb.DB_TYPE_BINARY_INTEGER,
                                 oracledb.DB_TYPE_LONG, 31, "31")

    def test_3631_NUMBER_to_BINARY_DOUBLE(self):
        "3631 - output type handler conversion from number to double"
        self.__test_type_handler(oracledb.DB_TYPE_NUMBER,
                                 oracledb.DB_TYPE_BINARY_DOUBLE, 31.5, 31.5)

    def test_3632_BINARY_FLOAT_to_BINARY_DOUBLE(self):
        "3632 - output type handler conversion from float to double"
        self.__test_type_handler(oracledb.DB_TYPE_BINARY_FLOAT,
                                 oracledb.DB_TYPE_BINARY_DOUBLE, 31.5, 31.5)

    def test_3633_VARCHAR_to_BINARY_DOUBLE(self):
        "3633 - output type handler conversion from varchar to double"
        self.__test_type_handler(oracledb.DB_TYPE_VARCHAR,
                                 oracledb.DB_TYPE_BINARY_DOUBLE, "31.5", 31.5)

    def test_3634_CHAR_to_BINARY_DOUBLE(self):
        "3634 - output type handler conversion from char to double"
        self.__test_type_handler(oracledb.DB_TYPE_CHAR,
                                 oracledb.DB_TYPE_BINARY_DOUBLE, "31.5", 31.5)

    def test_3635_LONG_to_BINARY_DOUBLE(self):
        "3635 - output type handler conversion from long to double"
        self.__test_type_handler(oracledb.DB_TYPE_LONG,
                                 oracledb.DB_TYPE_BINARY_DOUBLE, "31.5", 31.5)

    def test_3636_NUMBER_to_BINARY_FLOAT(self):
        "3636 - output type handler conversion from number to binary float"
        self.__test_type_handler(oracledb.DB_TYPE_NUMBER,
                                 oracledb.DB_TYPE_BINARY_FLOAT, 31.5, 31.5)

    def test_3637_BINARY_DOUBLE_to_BINARY_FLOAT(self):
        "3637 - output type handler conversion from double to float"
        self.__test_type_handler(oracledb.DB_TYPE_BINARY_DOUBLE,
                                 oracledb.DB_TYPE_BINARY_FLOAT, 31.5, 31.5)

    def test_3638_VARCHAR_to_BINARY_FLOAT(self):
        "3638 - output type handler conversion from varchar to binary float"
        self.__test_type_handler(oracledb.DB_TYPE_VARCHAR,
                                 oracledb.DB_TYPE_BINARY_FLOAT, "31.5", 31.5)

    def test_3639_CHAR_to_BINARY_FLOAT(self):
        "3639 - output type handler conversion from char to binary float"
        self.__test_type_handler(oracledb.DB_TYPE_CHAR,
                                 oracledb.DB_TYPE_BINARY_FLOAT, "31.5", 31.5)

    def test_3640_LONG_to_BINARY_FLOAT(self):
        "3640 - output type handler conversion from varchar to binary float"
        self.__test_type_handler(oracledb.DB_TYPE_LONG,
                                 oracledb.DB_TYPE_BINARY_FLOAT, "31.5", 31.5)

    def test_3641_VARCHAR_to_CHAR(self):
        "3641 - output type handler from varchar to char"
        self.__test_type_handler(oracledb.DB_TYPE_VARCHAR,
                                 oracledb.DB_TYPE_CHAR, "31.5", "31.5")

    def test_3642_VARCHAR_to_LONG(self):
        "3642 - output type handler from varchar to long"
        self.__test_type_handler(oracledb.DB_TYPE_VARCHAR,
                                 oracledb.DB_TYPE_LONG, "31.5", "31.5")

    def test_3643_LONG_to_VARCHAR(self):
        "3643 - output type handler from long to varchar"
        self.__test_type_handler(oracledb.DB_TYPE_LONG,
                                 oracledb.DB_TYPE_VARCHAR, "31.5", "31.5")

    def test_3644_LONG_to_CHAR(self):
        "3644 - output type handler from long to varhcar"
        self.__test_type_handler(oracledb.DB_TYPE_LONG,
                                 oracledb.DB_TYPE_CHAR, "31.5", "31.5")

    def test_3645_CHAR_to_VARCHAR(self):
        "3645 - output type handler from char to varchar"
        self.__test_type_handler(oracledb.DB_TYPE_CHAR,
                                 oracledb.DB_TYPE_VARCHAR, "31.5", "31.5")

    def test_3646_CHAR_to_LONG(self):
        "3646 - output type handler from char to long"
        self.__test_type_handler(oracledb.DB_TYPE_CHAR,
                                 oracledb.DB_TYPE_LONG, "31.5", "31.5")

    def test_3647_TIMESTAMP_to_TIMESTAMP_TZ(self):
        "3647 - output type handler from timestamp to timestamptz"
        val = datetime.datetime(2002, 12, 17, 0, 0, 16, 400000)
        self.__test_type_handler(oracledb.DB_TYPE_TIMESTAMP,
                                 oracledb.DB_TYPE_TIMESTAMP_LTZ, val, val)

    def test_3648_TIMESTAMP_to_TIMESTAMP_LTZ(self):
        "3648 - output type handler from timestamp to timestampltz"
        val = datetime.datetime(2002, 12, 17, 0, 0, 16, 400000)
        self.__test_type_handler(oracledb.DB_TYPE_TIMESTAMP,
                                 oracledb.DB_TYPE_TIMESTAMP_LTZ, val, val)

    def test_3649_TIMESTAMP_TZ_to_TIMESTAMP(self):
        "3649 - output type handler from timestamptz to timestamp"
        val = datetime.datetime(2002, 12, 17, 0, 0, 16, 400000)
        self.__test_type_handler(oracledb.DB_TYPE_TIMESTAMP_TZ,
                                 oracledb.DB_TYPE_TIMESTAMP, val, val)

    def test_3650_NUMBER_TO_DATE(self):
        "3650 - output type handler conversion from number to date is invalid"
        self.assertRaisesRegex(oracledb.DatabaseError, "^DPY-4007:|^ORA-00932:",
                               self.__test_type_handler,
                               oracledb.DB_TYPE_NUMBER, oracledb.DB_TYPE_DATE,
                               3, 3)

    def test_3651_CLOB_TO_CHAR(self):
        "3651 - output type handler from CLOB to CHAR"
        val = "Some Clob String"
        self.__test_type_handler(oracledb.DB_TYPE_CLOB,
                                 oracledb.DB_TYPE_CHAR, val, val)

    def test_3652_CLOB_TO_VARCHAR(self):
        "3652 - output type handler from CLOB to VARCHAR"
        val = "Some Clob String"
        self.__test_type_handler(oracledb.DB_TYPE_CLOB,
                                 oracledb.DB_TYPE_VARCHAR, val, val)

    def test_3653_CLOB_TO_LONG(self):
        "3653 - output type handler from CLOB to LONG"
        val = "Some Clob String"
        self.__test_type_handler(oracledb.DB_TYPE_CLOB,
                                 oracledb.DB_TYPE_LONG, val, val)

    def test_3654_BLOB_TO_RAW(self):
        "3654 - output type handler from BLOB to RAW"
        val = b"Some binary data"
        self.__test_type_handler(oracledb.DB_TYPE_BLOB,
                                 oracledb.DB_TYPE_RAW, val, val)

    def test_3655_BLOB_TO_LONG_RAW(self):
        "3655 - output type handler from BLOB to LONGRAW"
        val = b"Some binary data"
        self.__test_type_handler(oracledb.DB_TYPE_BLOB,
                                 oracledb.DB_TYPE_LONG_RAW, val, val)

    def test_3656_BLOB_TO_LONG_RAW(self):
        "3656 - output type handler from permanant BLOBs to LONG_RAW"
        self.__test_type_handler_blob(oracledb.DB_TYPE_LONG_RAW)

    def test_3657_BLOB_TO_RAW(self):
        "3657 - output type handler from permanant BLOBs to RAW"
        self.__test_type_handler_blob(oracledb.DB_TYPE_RAW)

    def test_3658_CLOB_TO_VARCHAR(self):
        "3658 - output type handler from permanant CLOBs to VARCHAR"
        self.__test_type_handler_clob(oracledb.DB_TYPE_VARCHAR)

    def test_3659_CLOB_TO_CHAR(self):
        "3659 - output type handler from permanant CLOBs to CHAR"
        self.__test_type_handler_clob(oracledb.DB_TYPE_CHAR)

    def test_3660_CLOB_TO_LONG(self):
        "3660 - output type handler from permanant CLOBs to LONG"
        self.__test_type_handler_clob(oracledb.DB_TYPE_LONG)

    def test_3661_NCLOB_TO_CHAR(self):
        "3661 - output type handler from NCLOB to CHAR"
        val = "Some nclob data"
        self.__test_type_handler(oracledb.DB_TYPE_NCLOB,
                                 oracledb.DB_TYPE_CHAR, val, val)

    def test_3662_NCLOB_TO_VARCHAR(self):
        "3662 - output type handler from NCLOB to VARCHAR"
        val = "Some nclob data"
        self.__test_type_handler(oracledb.DB_TYPE_NCLOB,
                                 oracledb.DB_TYPE_VARCHAR, val, val)

    def test_3663_NCLOB_TO_LONG(self):
        "3663 - output type handler from NCLOB to LONG"
        val = "Some nclob data"
        self.__test_type_handler(oracledb.DB_TYPE_NCLOB,
                                 oracledb.DB_TYPE_LONG, val, val)

    def test_3664_NCLOB_TO_VARCHAR(self):
        "3664 - output type handler from permanant NCLOBs to VARCHAR"
        self.__test_type_handler_nclob(oracledb.DB_TYPE_VARCHAR)

    def test_3665_NCLOB_TO_CHAR(self):
        "3665 - output type handler from permanant NCLOBs to CHAR"
        self.__test_type_handler_nclob(oracledb.DB_TYPE_CHAR)

    def test_3666_NCLOB_TO_LONG(self):
        "3666 - output type handler from permanant NCLOBs to LONG"
        self.__test_type_handler_nclob(oracledb.DB_TYPE_LONG)

    def test_3667_NVARCHAR_to_VARCHAR(self):
        "3667 - output type handler from nvarchar to varchar"
        self.__test_type_handler(oracledb.DB_TYPE_NVARCHAR,
                                 oracledb.DB_TYPE_VARCHAR, "31.5", "31.5")

    def test_3668_VARCHAR_to_NVARCHAR(self):
        "3668 - output type handler from varchar to nvarchar"
        self.__test_type_handler(oracledb.DB_TYPE_VARCHAR,
                                 oracledb.DB_TYPE_NVARCHAR, "31.5", "31.5")

    def test_3669_NCHAR_to_CHAR(self):
        "3669 - output type handler from nchar to char"
        self.__test_type_handler(oracledb.DB_TYPE_NCHAR,
                                 oracledb.DB_TYPE_CHAR, "31.5", "31.5")

    def test_3670_CHAR_to_NCHAR(self):
        "3670 - output type handler from char to nchar"
        self.__test_type_handler(oracledb.DB_TYPE_CHAR,
                                 oracledb.DB_TYPE_NCHAR, "31.5", "31.5")

    def test_3671_incorrect_arraysize(self):
        "3671 - execute raises an error if an incorrect arraysize is used"
        def type_handler(cursor, name, default_type, size,
                         precision, scale):
            return cursor.var(str)
        cursor = self.connection.cursor()
        cursor.arraysize = 100
        cursor.outputtypehandler = type_handler
        self.assertRaisesRegex(oracledb.ProgrammingError, "^DPY-2016:",
                               cursor.execute, "select :1 from dual", [5])

    def test_3672_incorrect_outputtypehandler_return_type(self):
        "3672 - execute raises an error if a var is not returned"
        def type_handler(cursor, name, default_type, size,
                    precision, scale):
            return "incorrect_return"
        cursor = self.connection.cursor()
        cursor.outputtypehandler = type_handler
        self.assertRaisesRegex(oracledb.ProgrammingError, "^DPY-2015:",
                               cursor.execute, "select :1 from dual", [5])

    def test_3673_NUMBER_to_DECIMAL(self):
        "3673 - output type handler conversion from number to decimal.Decimal"
        self.__test_type_handler(oracledb.DB_TYPE_NUMBER, decimal.Decimal,
                                 31.5, decimal.Decimal("31.5"))
        self.__test_type_handler(oracledb.DB_TYPE_NUMBER, decimal.Decimal, 0,
                                 decimal.Decimal("0"))

    def test_3674_cursor_description_unchanged(self):
        "3674 - use of output type handler does not affect variable name"
        def type_handler(cursor, name, default_type, size,
                         precision, scale):
            return cursor.var(str, arraysize=cursor.arraysize)
        with self.connection.cursor() as cursor:
            cursor.execute("select user from dual")
            name_before = cursor.description[0][0]
        with self.connection.cursor() as cursor:
            cursor.outputtypehandler = type_handler
            cursor.execute("select user from dual")
            self.assertEqual(cursor.description[0][0], name_before)

if __name__ == "__main__":
    test_env.run_test_cases()
