#------------------------------------------------------------------------------
# Copyright (c) 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

"""
4400 - Module for testing TPC (two-phase commit) transactions.
"""

import unittest

import oracledb
import test_env

@unittest.skipIf(oracledb.defaults.thin,
                 "thin driver doesn't support two-phase commit yet")
class TestCase(test_env.BaseTestCase):

    def test_4400_tpc_with_rolback(self):
        "3900 - test begin, prepare, roll back global transaction"
        self.cursor.execute("truncate table TestTempTable")
        xid = self.connection.xid(3900, "txn3900", "branchId")
        self.connection.tpc_begin(xid)
        self.assertEqual(self.connection.tpc_prepare(), False)
        self.connection.tpc_begin(xid)
        self.cursor.execute("""
                insert into TestTempTable (IntCol, StringCol)
                values (1, 'tesName')""")
        self.assertEqual(self.connection.tpc_prepare(), True)
        self.connection.tpc_rollback()
        self.cursor.execute("select count(*) from TestTempTable")
        count, = self.cursor.fetchone()
        self.assertEqual(count, 0)

    def test_4401_tpc_with_commit(self):
        "3901 - test begin, prepare, commit global transaction"
        self.cursor.execute("truncate table TestTempTable")
        xid = self.connection.xid(3901, "txn3901", "branchId")
        self.connection.tpc_begin(xid)
        self.cursor.execute("""
                insert into TestTempTable (IntCol, StringCol)
                values (1, 'tesName')""")
        self.assertEqual(self.connection.tpc_prepare(), True)
        self.connection.tpc_commit()
        self.cursor.execute("select IntCol, StringCol from TestTempTable")
        self.assertEqual(self.cursor.fetchall(), [(1, 'tesName')])

    def test_4402_tpc_multiple_transactions(self):
        "3902 - test multiple global transactions on the same connection"
        self.cursor.execute("truncate table TestTempTable")
        xid1 = self.connection.xid(3902, "txn3902", "branch1")
        xid2 = self.connection.xid(3902, "txn3902", "branch2")
        self.connection.tpc_begin(xid1)
        self.cursor.execute("""
                insert into TestTempTable (IntCol, StringCol)
                values (1, 'tesName')""")
        self.connection.tpc_end()
        self.connection.tpc_begin(xid2)
        self.cursor.execute("""
                insert into TestTempTable (IntCol, StringCol)
                values (2, 'tesName')""")
        self.connection.tpc_end()
        needs_commit1 = self.connection.tpc_prepare(xid1)
        needs_commit2 = self.connection.tpc_prepare(xid2)
        if needs_commit1:
            self.connection.tpc_commit(xid1)
        if needs_commit2:
            self.connection.tpc_commit(xid2)
        self.cursor.execute("""
                select IntCol, StringCol
                from TestTempTable
                order by IntCol""")
        expected_rows = [(1, 'tesName'), (2, 'tesName')]
        self.assertEqual(self.cursor.fetchall(), expected_rows)

if __name__ == "__main__":
    test_env.run_test_cases()
