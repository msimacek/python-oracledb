#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

import base
import oracledb

class TestCase(base.BaseTestCase):

    def test_execute_no_args(self):
        "test executing a statement without any arguments"
        result = self.cursor.execute("begin null; end;")
        self.assertEqual(result, None)

    def test_execute_no_statement_with_args(self):
        "test executing a None statement with bind variables"
        self.assertRaises(oracledb.ProgrammingError, self.cursor.execute, None,
                          x=5)

    def test_execute_empty_keyword_args(self):
        "test executing a statement with args and empty keyword args"
        simple_var = self.cursor.var(oracledb.NUMBER)
        args = [simple_var]
        kwargs = {}
        result = self.cursor.execute("begin :1 := 25; end;", args, **kwargs)
        self.assertEqual(result, None)
        self.assertEqual(simple_var.getvalue(), 25)

    def test_execute_keyword_args(self):
        "test executing a statement with keyword arguments"
        simple_var = self.cursor.var(oracledb.NUMBER)
        result = self.cursor.execute("begin :value := 5; end;",
                                     value=simple_var)
        self.assertEqual(result, None)
        self.assertEqual(simple_var.getvalue(), 5)

    def test_execute_dictionary_arg(self):
        "test executing a statement with a dictionary argument"
        simple_var = self.cursor.var(oracledb.NUMBER)
        dict_arg = dict(value=simple_var)
        result = self.cursor.execute("begin :value := 10; end;", dict_arg)
        self.assertEqual(result, None)
        self.assertEqual(simple_var.getvalue(), 10)

    def test_execute_multiple_arg_types(self):
        "test executing a statement with both a dict arg and keyword args"
        simple_var = self.cursor.var(oracledb.NUMBER)
        dict_arg = dict(value=simple_var)
        self.assertRaises(oracledb.InterfaceError, self.cursor.execute,
                          "begin :value := 15; end;", dict_arg,
                          value=simple_var)

    def test_callproc(self):
        "test executing a stored procedure"
        var = self.cursor.var(oracledb.NUMBER)
        results = self.cursor.callproc("proc_Test", ("hi", 5, var))
        self.assertEqual(results, ["hi", 10, 2.0])

    def test_callproc_all_keywords(self):
        "test executing a stored procedure with all args keyword args"
        inout_value = self.cursor.var(oracledb.NUMBER)
        inout_value.setvalue(0, 5)
        out_value = self.cursor.var(oracledb.NUMBER)
        kwargs = dict(a_InOutValue=inout_value, a_InValue="hi",
                      a_OutValue=out_value)
        results = self.cursor.callproc("proc_Test", **kwargs)
        self.assertEqual(results, [])
        self.assertEqual(inout_value.getvalue(), 10)
        self.assertEqual(out_value.getvalue(), 2.0)

    def test_callproc_only_last_keyword(self):
        "test executing a stored procedure with last arg as keyword arg"
        out_value = self.cursor.var(oracledb.NUMBER)
        kwargs = dict(a_OutValue=out_value)
        results = self.cursor.callproc("proc_Test", ("hi", 5), **kwargs)
        self.assertEqual(results, ["hi", 10])
        self.assertEqual(out_value.getvalue(), 2.0)

    def test_callproc_no_args(self):
        "test executing a stored procedure without any arguments"
        results = self.cursor.callproc("proc_TestNoArgs")
        self.assertEqual(results, [])

    def test_callfunc(self):
        "test executing a stored function"
        results = self.cursor.callfunc("func_Test", oracledb.NUMBER, ("hi", 5))
        self.assertEqual(results, 7)

    def test_callfunc_no_args(self):
        "test executing a stored function without any arguments"
        results = self.cursor.callfunc("func_TestNoArgs", oracledb.NUMBER)
        self.assertEqual(results, 712)

    def test_callfunc_negative(self):
        "test executing a stored function with wrong parameters"
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

    def test_exception_on_close(self):
        "confirm an exception is raised after closing a cursor"
        self.cursor.close()
        self.assertRaises(oracledb.InterfaceError, self.cursor.execute,
                          "select 1 from dual")


if __name__ == "__main__":
    base.run_test_cases()
