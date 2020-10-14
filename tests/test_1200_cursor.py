#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

"""
1200 - Module for testing cursors
"""

import base
import oracledb
import decimal

class TestCase(base.BaseTestCase):

    def test_1201_execute_no_args(self):
        "1201 - test executing a statement without any arguments"
        result = self.cursor.execute("begin null; end;")
        self.assertEqual(result, None)

    def test_1202_execute_no_statement_with_args(self):
        "1202 - test executing a None statement with bind variables"
        self.assertRaises(oracledb.ProgrammingError, self.cursor.execute, None,
                          x=5)

    def test_1203_execute_empty_keyword_args(self):
        "1203 - test executing a statement with args and empty keyword args"
        simple_var = self.cursor.var(oracledb.NUMBER)
        args = [simple_var]
        kwargs = {}
        result = self.cursor.execute("begin :1 := 25; end;", args, **kwargs)
        self.assertEqual(result, None)
        self.assertEqual(simple_var.getvalue(), 25)

    def test_1204_execute_keyword_args(self):
        "1204 - test executing a statement with keyword arguments"
        simple_var = self.cursor.var(oracledb.NUMBER)
        result = self.cursor.execute("begin :value := 5; end;",
                                     value=simple_var)
        self.assertEqual(result, None)
        self.assertEqual(simple_var.getvalue(), 5)

    def test_1205_execute_dictionary_arg(self):
        "1205 - test executing a statement with a dictionary argument"
        simple_var = self.cursor.var(oracledb.NUMBER)
        dict_arg = dict(value=simple_var)
        result = self.cursor.execute("begin :value := 10; end;", dict_arg)
        self.assertEqual(result, None)
        self.assertEqual(simple_var.getvalue(), 10)

    def test_1206_execute_multiple_arg_types(self):
        "1206 - test executing a statement with both a dict and keyword args"
        simple_var = self.cursor.var(oracledb.NUMBER)
        dict_arg = dict(value=simple_var)
        self.assertRaises(oracledb.InterfaceError, self.cursor.execute,
                          "begin :value := 15; end;", dict_arg,
                          value=simple_var)

    def test_1208_callproc(self):
        "1208 - test executing a stored procedure"
        var = self.cursor.var(oracledb.NUMBER)
        results = self.cursor.callproc("proc_Test", ("hi", 5, var))
        self.assertEqual(results, ["hi", 10, 2.0])

    def test_1209_callproc_all_keywords(self):
        "1209 - test executing a stored procedure with all args keyword args"
        inout_value = self.cursor.var(oracledb.NUMBER)
        inout_value.setvalue(0, 5)
        out_value = self.cursor.var(oracledb.NUMBER)
        kwargs = dict(a_InOutValue=inout_value, a_InValue="hi",
                      a_OutValue=out_value)
        results = self.cursor.callproc("proc_Test", **kwargs)
        self.assertEqual(results, [])
        self.assertEqual(inout_value.getvalue(), 10)
        self.assertEqual(out_value.getvalue(), 2.0)

    def test_1210_callproc_only_last_keyword(self):
        "1210 - test executing a stored procedure with last arg as keyword arg"
        out_value = self.cursor.var(oracledb.NUMBER)
        kwargs = dict(a_OutValue=out_value)
        results = self.cursor.callproc("proc_Test", ("hi", 5), **kwargs)
        self.assertEqual(results, ["hi", 10])
        self.assertEqual(out_value.getvalue(), 2.0)

    def test_1212_callproc_no_args(self):
        "1212 - test executing a stored procedure without any arguments"
        results = self.cursor.callproc("proc_TestNoArgs")
        self.assertEqual(results, [])

    def test_1213_callfunc(self):
        "1213 - test executing a stored function"
        results = self.cursor.callfunc("func_Test", oracledb.NUMBER, ("hi", 5))
        self.assertEqual(results, 7)

    def test_1214_callfunc_no_args(self):
        "1214 - test executing a stored function without any arguments"
        results = self.cursor.callfunc("func_TestNoArgs", oracledb.NUMBER)
        self.assertEqual(results, 712)

    def test_1215_callfunc_negative(self):
        "1215 - test executing a stored function with wrong parameters"
        func_name = "func_Test"
        self.assertRaises(TypeError, self.cursor.callfunc, oracledb.NUMBER,
                          func_name, ("hi", 5))
        self.assertRaises(oracledb.DatabaseError, self.cursor.callfunc,
                          func_name, oracledb.NUMBER, ("hi", 5, 7))
        self.assertRaises(TypeError, self.cursor.callfunc, func_name,
                          oracledb.NUMBER, "hi", 7)
        self.assertRaises(oracledb.DatabaseError, self.cursor.callfunc,
                          func_name, oracledb.NUMBER, [5, "hi"])
        self.assertRaises(oracledb.DatabaseError, self.cursor.callfunc,
                          func_name, oracledb.NUMBER)
        self.assertRaises(TypeError, self.cursor.callfunc, func_name,
                          oracledb.NUMBER, 5)

    def test_1216_executemany_by_name(self):
        "1216 - test executing a statement multiple times (named args)"
        self.cursor.execute("truncate table TestTempTable")
        rows = [{"value": n} for n in range(250)]
        self.cursor.arraysize = 100
        statement = "insert into TestTempTable (IntCol) values (:value)"
        self.cursor.executemany(statement, rows)
        self.connection.commit()
        self.cursor.execute("select count(*) from TestTempTable")
        count, = self.cursor.fetchone()
        self.assertEqual(count, len(rows))

    def test_1217_executemany_by_position(self):
        "1217 - test executing a statement multiple times (positional args)"
        self.cursor.execute("truncate table TestTempTable")
        rows = [[n] for n in range(230)]
        self.cursor.arraysize = 100
        statement = "insert into TestTempTable (IntCol) values (:1)"
        self.cursor.executemany(statement, rows)
        self.connection.commit()
        self.cursor.execute("select count(*) from TestTempTable")
        count, = self.cursor.fetchone()
        self.assertEqual(count, len(rows))

    def test_1218_executemany_with_prepare(self):
        "1218 - test executing a statement multiple times (with prepare)"
        self.cursor.execute("truncate table TestTempTable")
        rows = [[n] for n in range(225)]
        self.cursor.arraysize = 100
        statement = "insert into TestTempTable (IntCol) values (:1)"
        self.cursor.prepare(statement)
        self.cursor.executemany(None, rows)
        self.connection.commit()
        self.cursor.execute("select count(*) from TestTempTable")
        count, = self.cursor.fetchone()
        self.assertEqual(count, len(rows))

    def test_1219_executemany_with_rebind(self):
        "1219 - test executing a statement multiple times (with rebind)"
        self.cursor.execute("truncate table TestTempTable")
        rows = [[n] for n in range(235)]
        self.cursor.arraysize = 100
        statement = "insert into TestTempTable (IntCol) values (:1)"
        self.cursor.executemany(statement, rows[:50])
        self.cursor.executemany(statement, rows[50:])
        self.connection.commit()
        self.cursor.execute("select count(*) from TestTempTable")
        count, = self.cursor.fetchone()
        self.assertEqual(count, len(rows))

    def test_1220_executemany_with_input_sizes_wrong(self):
        "1220 - test executing multiple times (with input sizes wrong)"
        cursor = self.connection.cursor()
        cursor.setinputsizes(oracledb.NUMBER)
        data = [[decimal.Decimal("25.8")], [decimal.Decimal("30.0")]]
        cursor.executemany("declare t number; begin t := :1; end;", data)

    def test_1221_executemany_with_multiple_batches(self):
        "1221 - test executing multiple times (with multiple batches)"
        self.cursor.execute("truncate table TestTempTable")
        sql = "insert into TestTempTable (IntCol, StringCol) values (:1, :2)"
        self.cursor.executemany(sql, [(1, None), (2, None)])
        self.cursor.executemany(sql, [(3, None), (4, "Testing")])

    def test_1222_execute_many_numeric(self):
        "1222 - test executemany() with various numeric types"
        self.cursor.execute("truncate table TestTempTable")
        data = [
            (1, 5),
            (2, 7.0),
            (3, 6.5),
            (4, 2 ** 65),
            (5, decimal.Decimal("24.5"))
        ]
        sql = "insert into TestTempTable (IntCol, NumberCol) values (:1, :2)"
        self.cursor.executemany(sql, data)
        self.cursor.execute("""
                select IntCol, NumberCol
                from TestTempTable
                order by IntCol""")
        self.assertEqual(self.cursor.fetchall(), data)

    def test_1223_execute_many_with_resize(self):
        "1223 - test executing a statement multiple times (with resize)"
        self.cursor.execute("truncate table TestTempTable")
        rows = [
             (1, "First"),
             (2, "Second"),
             (3, "Third"),
             (4, "Fourth"),
             (5, "Fifth"),
             (6, "Sixth"),
             (7, "Seventh and the longest one")
        ]
        sql = "insert into TestTempTable (IntCol, StringCol) values (:1, :2)"
        self.cursor.executemany(sql, rows)
        self.cursor.execute("""
                select IntCol, StringCol
                from TestTempTable
                order by IntCol""")
        fetchedRows = self.cursor.fetchall()
        self.assertEqual(fetchedRows, rows)

    def test_1224_executemany_with_exception(self):
        "1224 - test executing a statement multiple times (with exception)"
        self.cursor.execute("truncate table TestTempTable")
        rows = [{"value": n} for n in (1, 2, 3, 2, 5)]
        statement = "insert into TestTempTable (IntCol) values (:value)"
        self.assertRaises(oracledb.DatabaseError, self.cursor.executemany,
                statement, rows)
        self.assertEqual(self.cursor.rowcount, 3)

    def test_1225_executemany_with_invalid_parameters(self):
        "1225 - test calling executemany() with invalid parameters"
        self.assertRaises(oracledb.ProgrammingError, self.cursor.executemany,
                "insert into TestTempTable (IntCol, StringCol) values (:1, :2)",
                "These are not valid parameters")

    def test_1226_execute_many_no_parameters(self):
        "1226 - test calling executemany() without any bind parameters"
        numRows = 5
        self.cursor.execute("truncate table TestTempTable")
        self.cursor.executemany("""
                declare
                    t_Id          number;
                begin
                    select nvl(count(*), 0) + 1 into t_Id
                    from TestTempTable;

                    insert into TestTempTable (IntCol, StringCol)
                    values (t_Id, 'Test String ' || t_Id);
                end;""", numRows)
        self.assertEqual(self.cursor.rowcount, numRows)
        self.cursor.execute("select count(*) from TestTempTable")
        count, = self.cursor.fetchone()
        self.assertEqual(count, numRows)

    def test_1227_executemany_bound_earlier(self):
        "1227 - test calling executemany() with binds performed earlier"
        numRows = 9
        self.cursor.execute("truncate table TestTempTable")
        var = self.cursor.var(int, arraysize = numRows)
        self.cursor.setinputsizes(var)
        self.cursor.executemany("""
                declare
                    t_Id          number;
                begin
                    select nvl(count(*), 0) + 1 into t_Id
                    from TestTempTable;

                    insert into TestTempTable (IntCol, StringCol)
                    values (t_Id, 'Test String ' || t_Id);

                    select sum(IntCol) into :1
                    from TestTempTable;
                end;""", numRows)
        self.assertEqual(self.cursor.rowcount, numRows)
        expectedData = [1, 3, 6, 10, 15, 21, 28, 36, 45]
        self.assertEqual(var.values, expectedData)

    def test_1228_prepare(self):
        "1228 - test preparing a statement and executing it multiple times"
        self.assertEqual(self.cursor.statement, None)
        statement = "begin :value := :value + 5; end;"
        self.cursor.prepare(statement)
        var = self.cursor.var(oracledb.NUMBER)
        self.assertEqual(self.cursor.statement, statement)
        var.setvalue(0, 2)
        self.cursor.execute(None, value = var)
        self.assertEqual(var.getvalue(), 7)
        self.cursor.execute(None, value = var)
        self.assertEqual(var.getvalue(), 12)
        self.cursor.execute("begin :value2 := 3; end;", value2 = var)
        self.assertEqual(var.getvalue(), 3)

    def test_1229_exception_on_close(self):
        "1229 - confirm an exception is raised after closing a cursor"
        self.cursor.close()
        self.assertRaises(oracledb.InterfaceError, self.cursor.execute,
                          "select 1 from dual")

    def test_1233_bad_prepare(self):
        "1233 - test that subsequent executes succeed after bad prepare"
        self.assertRaises(oracledb.DatabaseError,
                self.cursor.execute,
                "begin raise_application_error(-20000, 'this); end;")
        self.cursor.execute("begin null; end;")

if __name__ == "__main__":
    base.run_test_cases()
