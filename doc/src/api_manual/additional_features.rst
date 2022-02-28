.. _additionalfeatures:

*****************************************************
Additional Features of python-oracledb over cx_Oracle
*****************************************************

python-oracledb Thick has a few small changes in comparison to cx_Oracle. These changes are consistent with the changes made in previous major cx_Oracle releases. python-oracledb Thick also has additional new features.

python-oracledb Thin does not support all the features of python-oracledb Thick. Also, the python-oracledb Thin driver does not support all the features that the Oracle Client libraries provide to cx_Oracle and the python-oracledb Thick driver.

The additional features of python-oracledb are listed below:

  - :meth:`oracledb.defaults`: You can adjust the default behavior of python-oracledb in the application by modifying the attributes in this function.
  - :ref:`connparam`: This new class allows you to define connection parameters in one place.
  - :ref:`nclob`: To improve performance, a new DB_TYPE_LONG_NVARCHAR constant can be used in output type handlers when fetching NCLOB columns as String.
  - :ref:`statementcache`: With statement caching, cursors can be used without re-parsing the statement.
  - :ref:`tcp`: New functions to perform two-phase commit are added in python-oracledb to better comply with Python Database API. The ``Connection.begin()`` and ``Connection.prepare()`` functions that were used in cx_Oracle have been deprecated in python-oracledb.
  - :ref:`connobj`: A new function is added to the Connection class to check the health status of a connection.
  - :ref:`connpool`: A new ConnectionPool class is introduced in python-oracledb and it is synonymous with the SessionPool class.
  - Editors, Code Annotations and Code Completion

