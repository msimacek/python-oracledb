# ------------------------------------------------------------------------------
# type_converter.py (Section 6.2)
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Copyright (c) 2017, 2022, Oracle and/or its affiliates.
# ------------------------------------------------------------------------------

import oracledb
import decimal
import db_config

con = oracledb.connect(user=db_config.user,
                       password=db_config.pw, dsn=db_config.dsn)
cur = con.cursor()


def ReturnNumbersAsDecimal(cursor, name, defaultType, size, precision, scale):
    if defaultType == oracledb.NUMBER:
        return cursor.var(str, 9, cursor.arraysize, outconverter=decimal.Decimal)


cur.outputtypehandler = ReturnNumbersAsDecimal

for value, in cur.execute("select 0.1 from dual"):
    print("Value:", value, "* 3 =", value * 3)
