.. _additionalfeatures:

*****************************************************
Additional Features of python-oracledb over cx_Oracle
*****************************************************

python-oracledb Thick has a few small changes in comparison to cx_Oracle. These changes are consistent with the changes made in previous major cx_Oracle releases. python-oracledb Thick also has additional new features.

python-oracledb Thin does not support all the features of python-oracledb Thick. Also, the python-oracledb Thin driver does not support all the features that the Oracle Client libraries provide to cx_Oracle and the python-oracledb Thick driver.

The additional features of python-oracledb are listed below:

  - :meth:`oracledb.defaults`: You can adjust the default behavior of python-oracledb in the application by modifying the attributes in this function.
  - :meth:`oracledb.init_oracle_client`: For the python-oracledb Thick driver, a call must be made to this function before any connection is established. The :meth:`oracledb.init_oracle_client` function may be called multiple times in each process. In each call, the arguments must be the same, otherwise an error will be thrown.
    
    In cx_Oracle, this function could only be called once per process.
    
  - :ref:`connparam`: This new class allows you to define connection parameters in one place.
  - :ref:`nclob`: To improve performance, a new DB_TYPE_LONG_NVARCHAR constant can be used in output type handlers when fetching NCLOB columns as String.
  - :ref:`stmtcache`: A new boolean parameter ``cache_statement`` is added to the :meth:`Cursor.prepare()` function to help the performance of re-executed statements. In cx_Oracle, statements were always added to the statement cache if the statement cache size was greater than zero. 
  - :ref:`tcp`: New functions to perform two-phase commit are added in python-oracledb to better comply with Python Database API. The ``Connection.begin()`` and ``Connection.prepare()`` functions that were used in cx_Oracle have been deprecated in python-oracledb.
  - :ref:`connobj`: A new function is added to the Connection class to check the health status of a connection.
  - :ref:`connpool`: A new ConnectionPool class is introduced in python-oracledb and it is synonymous with the SessionPool class.
  - Editors, Code Annotations and Code Completion

