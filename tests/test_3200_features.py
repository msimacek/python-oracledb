#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

"""
3200 - Module for testing batcherrors and arraydmlrowcount
"""

import base
import oracledb

class TestCase(base.BaseTestCase):

    def test_3200_arraydmlrowcounts_off(self):
        "3200 - test executing with arraydmlrowcounts mode disabled"
        self.cursor.execute("truncate table TestArrayDML")
        rows = [
            (1, "First"),
            (2, "Second")
        ]
        sql = "insert into TestArrayDML (IntCol,StringCol) values (:1,:2)"
        self.cursor.executemany(sql, rows, arraydmlrowcounts = False)
        self.assertRaises(oracledb.DatabaseError,
                self.cursor.getarraydmlrowcounts)
        rows = [
            (3, "Third"),
            (4, "Fourth")
        ]
        self.cursor.executemany(sql, rows)
        self.assertRaises(oracledb.DatabaseError,
                self.cursor.getarraydmlrowcounts)

    def test_3201_arraydmlrowcounts_on(self):
        "3201 - test executing with arraydmlrowcounts mode enabled"
        self.cursor.execute("truncate table TestArrayDML")
        rows =  [
            (1, "First", 100),
            (2, "Second", 200),
            (3, "Third", 300),
            (4, "Fourth", 300),
            (5, "Fifth", 300)
        ]
        sql = "insert into TestArrayDML (IntCol,StringCol,IntCol2) " \
                "values (:1,:2,:3)"
        self.cursor.executemany(sql, rows, arraydmlrowcounts = True)
        self.connection.commit()
        self.assertEqual(self.cursor.getarraydmlrowcounts(), [1, 1, 1, 1, 1])
        self.cursor.execute("select count(*) from TestArrayDML")
        count, = self.cursor.fetchone()
        self.assertEqual(count, len(rows))

    def test_3222_insert_with_batcherror(self):
        "3222 - test executing insert with multiple distinct batch errors"
        self.cursor.execute("truncate table TestArrayDML")
        rows = [
            (1, "First", 100),
            (2, "Second", 200),
            (2, "Third", 300),
            (4, "Fourth", 400),
            (5, "Fourth", 1000)
        ]
        sql = "insert into TestArrayDML (IntCol, StringCol, IntCol2) " \
                "values (:1, :2, :3)"
        self.cursor.executemany(sql, rows, batcherrors = True,
                arraydmlrowcounts = True)
        user = base.get_main_user()
        expectedErrors = [
            (4, 1438, "ORA-01438: value larger than specified " \
             "precision allowed for this column" ),
            (2, 1, "ORA-00001: unique constraint " \
             "(%s.TESTARRAYDML_PK) violated" % user.upper())
        ]
        actualErrors = [(e.offset, e.code, e.message) \
                for e in self.cursor.getbatcherrors()]
        self.assertEqual(actualErrors, expectedErrors)
        self.assertEqual(self.cursor.getarraydmlrowcounts(), [1, 1, 0, 1, 0])

    def test_3223_batcherror_false(self):
        "3223 - test batcherrors mode set to False"
        self.cursor.execute("truncate table TestArrayDML")
        rows = [
            (1, "First", 100),
            (2, "Second", 200),
            (2, "Third", 300)
        ]
        sql = "insert into TestArrayDML (IntCol, StringCol, IntCol2) " \
                "values (:1, :2, :3)"
        self.assertRaises(oracledb.DatabaseError,
                self.cursor.executemany, sql, rows, batcherrors = False)

    def test_3224_update_with_batcherror(self):
        "3224 - test executing in succession with batch error"
        self.cursor.execute("truncate table TestArrayDML")
        rows = [
            (1, "First", 100),
            (2, "Second", 200),
            (3, "Third", 300),
            (4, "Second", 300),
            (5, "Fifth", 300),
            (6, "Sixth", 400),
            (6, "Seventh", 400),
            (8, "Eighth", 100)
        ]
        sql = "insert into TestArrayDML (IntCol, StringCol, IntCol2) " \
                "values (:1, :2, :3)"
        self.cursor.executemany(sql, rows, batcherrors = True)
        user = base.get_main_user()
        expectedErrors = [
                ( 6, 1, "ORA-00001: unique constraint " \
                        "(%s.TESTARRAYDML_PK) violated" % user.upper())
        ]
        actualErrors = [(e.offset, e.code, e.message) \
                for e in self.cursor.getbatcherrors()]
        self.assertEqual(actualErrors, expectedErrors)
        rows = [
            (101, "First"),
            (201, "Second"),
            (3000, "Third"),
            (900, "Ninth"),
            (301, "Third")
        ]
        sql = "update TestArrayDML set IntCol2 = :1 where StringCol = :2"
        self.cursor.executemany(sql, rows, arraydmlrowcounts = True,
                batcherrors = True)
        expectedErrors = [
            (2, 1438, "ORA-01438: value larger than specified " \
             "precision allowed for this column")
        ]
        actualErrors = [(e.offset, e.code, e.message) \
                for e in self.cursor.getbatcherrors()]
        self.assertEqual(actualErrors, expectedErrors)
        self.assertEqual(self.cursor.getarraydmlrowcounts(),
                [1, 2, 0, 0, 1])
        self.assertEqual(self.cursor.rowcount, 4)

if __name__ == "__main__":
    base.run_test_cases()
