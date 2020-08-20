#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

import base
import oracledb

class TestCase(base.BaseTestCase):

    def __test_compare(self, db_type, api_type):
        self.assertEqual(db_type, db_type)
        self.assertEqual(db_type, api_type)
        self.assertEqual(api_type, db_type)
        self.assertNotEqual(db_type, 5)
        self.assertNotEqual(db_type, oracledb.DB_TYPE_OBJECT)

    def test_BFILE(self):
        "test oracledb.DB_TYPE_BFILE comparisons"
        self.assertEqual(oracledb.DB_TYPE_BFILE, oracledb.BFILE)

    def test_BINARY_DOUBLE(self):
        "test oracledb.DB_TYPE_BINARY_DOUBLE comparisons"
        self.__test_compare(oracledb.DB_TYPE_BINARY_DOUBLE, oracledb.NUMBER)
        self.assertEqual(oracledb.DB_TYPE_BINARY_DOUBLE,
                oracledb.NATIVE_FLOAT)

    def test_BINARY_FLOAT(self):
        "test oracledb.DB_TYPE_BINARY_FLOAT comparisons"
        self.__test_compare(oracledb.DB_TYPE_BINARY_FLOAT, oracledb.NUMBER)

    def test_BINARY_INTEGER(self):
        "test oracledb.DB_TYPE_BINARY_INTEGER comparisons"
        self.__test_compare(oracledb.DB_TYPE_BINARY_INTEGER, oracledb.NUMBER)
        self.assertEqual(oracledb.DB_TYPE_BINARY_INTEGER,
                oracledb.NATIVE_INT)

    def test_BLOB(self):
        "test oracledb.DB_TYPE_BLOB comparisons"
        self.assertEqual(oracledb.DB_TYPE_BLOB, oracledb.BLOB)

    def test_BOOLEAN(self):
        "test oracledb.DB_TYPE_BOOLEAN comparisons"
        self.assertEqual(oracledb.DB_TYPE_BOOLEAN, oracledb.BOOLEAN)

    def test_CHAR(self):
        "test oracledb.DB_TYPE_CHAR comparisons"
        self.__test_compare(oracledb.DB_TYPE_CHAR, oracledb.STRING)
        self.assertEqual(oracledb.DB_TYPE_CHAR, oracledb.FIXED_CHAR)

    def test_CLOB(self):
        "test oracledb.DB_TYPE_CLOB comparisons"
        self.assertEqual(oracledb.DB_TYPE_CLOB, oracledb.CLOB)

    def test_CURSOR(self):
        "test oracledb.DB_TYPE_CURSOR comparisons"
        self.assertEqual(oracledb.DB_TYPE_CURSOR, oracledb.CURSOR)

    def test_DATE(self):
        "test oracledb.DB_TYPE_DATE comparisons"
        self.__test_compare(oracledb.DB_TYPE_DATE, oracledb.DATETIME)

    def test_INTERVAL_DS(self):
        "test oracledb.DB_TYPE_INTERVAL_DS comparisons"
        self.assertEqual(oracledb.DB_TYPE_INTERVAL_DS, oracledb.INTERVAL)

    def test_LONG(self):
        "test oracledb.DB_TYPE_LONG comparisons"
        self.__test_compare(oracledb.DB_TYPE_LONG, oracledb.STRING)
        self.assertEqual(oracledb.DB_TYPE_LONG, oracledb.LONG_STRING)

    def test_LONG_RAW(self):
        "test oracledb.DB_TYPE_LONG_RAW comparisons"
        self.__test_compare(oracledb.DB_TYPE_LONG_RAW, oracledb.BINARY)
        self.assertEqual(oracledb.DB_TYPE_LONG_RAW, oracledb.LONG_BINARY)

    def test_NCHAR(self):
        "test oracledb.DB_TYPE_NCHAR comparisons"
        self.__test_compare(oracledb.DB_TYPE_NCHAR, oracledb.STRING)
        self.assertEqual(oracledb.DB_TYPE_NCHAR, oracledb.FIXED_NCHAR)

    def test_NCLOB(self):
        "test oracledb.DB_TYPE_NCLOB comparisons"
        self.assertEqual(oracledb.DB_TYPE_NCLOB, oracledb.NCLOB)

    def test_NUMBER(self):
        "test oracledb.DB_TYPE_NUMBER comparisons"
        self.__test_compare(oracledb.DB_TYPE_NUMBER, oracledb.NUMBER)

    def test_NVARCHAR(self):
        "test oracledb.DB_TYPE_NVARCHAR comparisons"
        self.__test_compare(oracledb.DB_TYPE_NVARCHAR, oracledb.STRING)
        self.assertEqual(oracledb.DB_TYPE_NVARCHAR, oracledb.NCHAR)

    def test_OBJECT(self):
        "test oracledb.DB_TYPE_OBJECT comparisons"
        self.assertEqual(oracledb.DB_TYPE_OBJECT, oracledb.OBJECT)

    def test_RAW(self):
        "test oracledb.DB_TYPE_RAW comparisons"
        self.__test_compare(oracledb.DB_TYPE_RAW, oracledb.BINARY)

    def test_ROWID(self):
        "test oracledb.DB_TYPE_ROWID comparisons"
        self.__test_compare(oracledb.DB_TYPE_ROWID, oracledb.ROWID)

    def test_TIMESTAMP(self):
        "test oracledb.DB_TYPE_TIMESTAMP comparisons"
        self.__test_compare(oracledb.DB_TYPE_TIMESTAMP, oracledb.DATETIME)
        self.assertEqual(oracledb.DB_TYPE_TIMESTAMP, oracledb.TIMESTAMP)

    def test_TIMESTAMP_LTZ(self):
        "test oracledb.DB_TYPE_TIMESTAMP_LTZ comparisons"
        self.__test_compare(oracledb.DB_TYPE_TIMESTAMP_LTZ, oracledb.DATETIME)

    def test_TIMESTAMP_TZ(self):
        "test oracledb.DB_TYPE_TIMESTAMP_TZ comparisons"
        self.__test_compare(oracledb.DB_TYPE_TIMESTAMP_TZ, oracledb.DATETIME)

    def test_VARCHAR(self):
        "test oracledb.DB_TYPE_VARCHAR comparisons"
        self.__test_compare(oracledb.DB_TYPE_VARCHAR, oracledb.STRING)

if __name__ == "__main__":
    base.run_test_cases()
