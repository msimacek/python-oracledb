.. _additionalfeatures:

*************************************************
Additional Features Supported in python-oracledb
*************************************************

In comparison to cx_Oracle 8.3, the python-oracledb Thick mode has new features
and a few changes that are consistent with the changes made in previous major 
cx_Oracle releases. The python-oracledb Thin mode does not support all of the 
features in python-oracledb Thick mode. Also, since the python-oracledb Thin mode 
does not require Oracle Client libraries, it does not support all the features that 
these libraries provide to cx_Oracle and the python-oracledb Thick mode.

The new features introduced in the python-oracledb driver are listed below:

  - :meth:`oracledb.defaults`: You can adjust the default behavior of python-oracledb 
    in the application by modifying the attributes in this function.

  - :meth:`oracledb.init_oracle_client`: For the python-oracledb Thick driver, a call
    must be made to this function before any connection is established. 
    The :meth:`oracledb.init_oracle_client` function may be called multiple times in 
    each process. In each call, the arguments must be the same, otherwise an error 
    will be thrown.
    
    In cx_Oracle 8.3, this function could only be called once per process.
    
  - :ref:`connparam`: This new class allows you to define connection parameters in one place.

  - :ref:`nclob`: To improve performance, a new :data:`~oracledb.DB_TYPE_LONG_NVARCHAR` constant 
    can be used in output type handlers when fetching NCLOB columns as String.

  - :ref:`stmtcache`: A new boolean parameter ``cache_statement`` is added to the 
    :meth:`Cursor.prepare()` function to help the performance of re-executed statements. 
    In cx_Oracle, statements were always added to the statement cache if the statement 
    cache size was greater than zero.

  - :ref:`tcp`: New functions to perform two-phase commit are added in python-oracledb 
    to better comply with Python Database API. The ``Connection.begin()`` and 
    ``Connection.prepare()`` functions that were used in cx_Oracle have been deprecated 
    in python-oracledb.

  - :ref:`aqusermanual`: Oracle Advanced Queuing supports recipient lists in python-oracledb 
    with the introduction of a new :attr:`~Messageproperties.recipient` attribute.

  - :ref:`connobj`: A new function, :meth:`Connection.is_healthy()` is added to the 
    Connection class to check the health status of a connection.

  - :ref:`connpool`: A new ConnectionPool class is introduced in python-oracledb and it is 
    synonymous with the SessionPool class.

  - :ref:`exception`: A new attribute, :attr:`~oracledb._Error.full_code`, is added which displays
    the top-level error prefix and the error message. For example, ``DPY-6003`` or ``ORA-12505``.

  .. - Editors, Code Annotations and Code Completion

