# oracledb version 0.0.1

oracledb is a Python extension module that enables access to Oracle Database.
It requires Python 3.6 and higher.

This is a work in progress. It is intended to replace cx_Oracle and contains
both a thick (requiring the Oracle Client libraries to be installed) and a
thin (not requiring Oracle Client libraries to be installed) driver.

The thin driver currently supports:
    - connecting to the database
    - executing SQL and PL/SQL with or without bind variables
        - bind variables currently only support strings
    - fetching data from the database
        - only strings and numbers can be fetched currently
