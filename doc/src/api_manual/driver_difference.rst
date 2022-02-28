.. _driverdiff:

*******************************************************************************
Difference between python-oracledb Thin Driver and python-oracledb Thick Driver
*******************************************************************************

The Thin and the Thick drivers work differently in the following ways.

Supported Database Types
========================

See `Oracle Database Types <https://docs.oracle.com/en/database/oracle/oracle-database/21/sqlrf/Data-Types.html#GUID-A3C0D836-BADB-44E5-A5D4-265BA5968483>`__ and `PL/SQL Types <https://docs.oracle.com/en/database/oracle/oracle-database/21/lnpls/plsql-data-types.html#GUID-391C58FD-16AF-486C-AF28-173E309CDBA5>`__.

The following table lists the Oracle database types that are supported in the python-oracledb Thin, python-oracledb Thick, and cx_Oracle drivers.

.. list-table-with-summary::  Oracle Database Types Supported in the python-oracledb Thin, python-oracle-db Thick, and cx_Oracle Drivers
    :header-rows: 1
    :align: center
    :summary: The first column displays the database type. The second column displays the python-oracledb Constant Name. The third column indicates if the datatype is supported in the three drivers.

    * - Database Type
      - python-oracledb Constant Name
      - Three Drivers Supported
    * - VARCHAR2
      - DB_TYPE_VARCHAR
      - Yes
    * - NVARCHAR2
      - DB_TYPE_NVARCHAR
      - Yes
    * - NUMBER, FLOAT
      - DB_TYPE_NUMBER
      - Yes
    * - DATE
      - DB_TYPE_DATE
      - Yes
    * - BOOLEAN (PL/SQL)
      - DB_TYPE_BOOLEAN
      - Yes
    * - BINARY_DOUBLE
      - DB_TYPE_BINARY_DOUBLE
      - Yes
    * - BINARY_FLOAT
      - DB_TYPE_BINARY_FLOAT
      - Yes
    * - TIMESTAMP
      - DB_TYPE_TIMESTAMP
      - Yes
    * - TIMESTAMP WITH TIME ZONE
      - DB_TYPE_TIMESTAMP_TZ
      - Yes
    * - TIMESTAMP WITH LOCAL TIME ZONE
      - DB_TYPE_TIMESTAMP_LTZ
      - Yes
    * - INTERVAL YEAR TO MONTH
      - DB_TYPE_INTERVAL_YM
      - No
    * - INTERVAL DAY TO SECOND
      - DB_TYPE_INTERVAL_DS
      - Yes
    * - RAW
      - DB_TYPE_RAW
      - Yes
    * - LONG
      - DB_TYPE_LONG
      - Yes
    * - LONG RAW
      - DB_TYPE_LONG_RAW
      - Yes
    * - ROWID
      - DB_TYPE_ROWID
      - Yes
    * - UROWID
      - DB_TYPE_ROWID (May show DB_TYPE_UROWID in metadata. See Query Metadata Differences.)
      - Yes
    * - CHAR
      - DB_TYPE_CHAR
      - Yes
    * - BLOB
      - DB_TYPE_BLOB
      - Yes
    * - CLOB
      - DB_TYPE_CLOB
      - Yes
    * - NCHAR
      - DB_TYPE_NCHAR
      - Yes
    * - NCLOB
      - DB_TYPE_NCLOB
      - Yes
    * - BFILE
      - DB_TYPE_BFILE
      - Not supported in Thin driver
    * - JSON
      - DB_TYPE_JSON
      - Yes for Oracle Database versions 19c and earlier. With Oracle Database 21c, use an output type handler. See Fetching JSON Differences.
    * - REF CURSOR (PL/SQL OR nested cursor)
      - DB_TYPE_CURSOR
      - Yes
    * - PLS_INTEGER
      - 
      - 
    * - BINARY_INTEGER
      - DB_TYPE_BINARY_INTEGER
      - Yes
    * - REF
      - DB_TYPE_OBJECT
      - No
    * - ANYTYPE
      - DB_TYPE_OBJECT
      - Not supported in Thin driver
    * - ANYDATA
      - DB_TYPE_OBJECT
      - Not supported in Thin driver
    * - ANYDATASET
      - DB_TYPE_OBJECT
      - Not supported in Thin driver
    * - XMLType
      - DB_TYPE_OBJECT
      - Not supported in Thin driver
    * - HTTPURIType
      - DB_TYPE_OBJECT
      - Not supported in Thin driver
    * - XDBURIType
      - DB_TYPE_OBJECT
      - Not supported in Thin driver
    * - DBURIType
      - DB_TYPE_OBJECT
      - Not supported in Thin driver
    * - User-defined types (object type, VARRAY, records, collections, SDO_*types)
      - DB_TYPE_OBJECT
      - Not supported in Thin driver

Binding of contiguous PL/SQL Index-by BINARY_INTEGER arrays of String, number, date are supported in Thin and Thick drivers. Use :meth:`Cursor.arrayvar()` to build these arrays.

Query Metadata
===============

In the python-oracledb Thin driver, :data:`Cursor.description` metadata distinguishes the ROWID and UROWID database types. The UROWID database type shows the new value DB_TYPE_UROWID, while the database type ROWID uses the existing value DB_TYPE_ROWID.

In the python-oracledb Thick driver, the value DB_TYPE_ROWID is shown for both ROWID and UROWID database types. In the python-oracledb Thick and Thin drivers, comparison with the type oracledb.ROWID (defined in the Python DB API) will match both ROWID and UROWID database types.

.. _stmtcaching:

Statement Caching
=================

The statement cache implemented in the python-oracledb Thin driver is capable of determining when different data types are used for the same bind variables when a statement is re-executed. This capability is missing in the python-oracledb Thick driver. In general, changing the type of bind variables for the same SQL is inappropriate or at least that it gives indeterminate results.

See also :ref:`statementcache` for more information.

oracledb.ConnectionPool()
=========================

Not all parameters in the :func:`oracledb.ConnectionPool()` apply (or will ever apply) to python-oracledb Thin driver. The :func:`oracledb.ConnectionPool()` in the Thin driver differs from the Thick driver in the following ways:

* The Thin driver currently supports the following ConnectionPool parameters: min, max, increment, getmode, wait_timeout, ping_interval, and stmtcachesize. The Thin driver ignores the unrecognized parameters.
* ``getmode=oracledb.SPOOL_ATTRVAL_TIMEDWAIT`` is not implemented in the Thin driver.
* Only homogeneous pools are supported in the Thin driver.
* The thin driver creates connections in a daemon thread and so ``oracledb.ConnectionPool()`` will return before any or all, minimum number of connections are created. The :attr:`ConnectionPool.opened` attribute will not be equal to :attr:`ConnectionPool.min` immediately after the pool is created but will increase to the minimum over a short time as the connections are established. Note that this behavior may also be true of recent versions of the OCI Session Pool used by the Thick driver.
  
  This behavior will not be an issue if the new ``getmode`` default value of ``POOL_GETMODE_WAIT`` is used, since any immediate :meth:`ConnectionPool.acquire()` calls will wait for connections to be created by the daemon thread. This new design improves the application startup time when compared to the python-oracledb Thick and cx_Oracle drivers, where ``oracledb.SessionPool()`` will not return control to the application until all ``pool.min`` connections have been created.

  If the old default value ``POOL_GETMODE_NOWAIT`` is required, then the application could check if :attr:`ConnectionPool.opened` has reached :attr:`ConnectionPool.min` and then continue with application startup.

* In python-oracledb Thick, when closing a SessionPool (or new ConnectionPool class) with the parameter ``force=True``, the underlying Oracle Client libraries wait for current SQL executions to complete before closing connections. All connections are then dropped from the pool and the pool is closed. Technically closing the pool in python-oracledb Thick could hang indefinitely, depending on the network and SQL*Net timeout parameters. This also applies to cx_Oracle. In python-oracledb Thin, the parameter ``force=True`` disconnects each connection's socket using a background thread, leaving the database to clean up its end of the connections.

See :ref:`connpool` for more information about the ConnectionPool class.

.. _fetchJSON:

Fetching JSON
=============

If an output type handler is used, then the python-oracledb Thin driver is able to fetch the Oracle Database 21c JSON datatype using the following code:

.. code-block:: python

    def type_handler(cursor, name, default_type, size, precision, scale):
        if default_type == oracledb.DB_TYPE_JSON:
            return cursor.var(str, arraysize=cursor.arraysize)

To automatically convert to a Python object (like it would automatically be done with an Oracle 21c thick client), use the following code:

.. code-block:: python

    def type_handler(cursor, name, default_type, size, precision, scale):
        if default_type == oracledb.DB_TYPE_JSON:
            return cursor.var(str, arraysize=cursor.arraysize,
                              outconverter=json.loads)

With a type handler, the python-oracledb Thin driver is effectively equivalent to using the Thick driver with Oracle Client 21c. The Thin driver returns timestamps in a string representation. Without a type handler, the Thin driver gives an error that DB_TYPE_JSON is not supported.

The type handler is not needed in the Thick driver. If the type handler is used, the behavior is the same as when it is used in the thin driver.

The type handler is not needed when fetching from the Oracle Database 19c JSON type, since this is represented as VARCHAR2 or LOB.

Connection and Connection Configuration
=======================================

See :ref:`connconfig`. 

.. _errorhandling:

Error Handling
==============

Error Message Prefixes
----------------------

Both the Thick and the Thin driver return error messages generated by the database unchanged. On the server side, Oracle Database and SQL*Net return error messages with the prefix "ORA". 

Error messages generated by the client behave differently. The Thick driver returns error messages generated by Oracle Call Interface (OCI) with the prefix "ORA", ODPI-C with the prefix "DPI", and the driver itself with the prefix "DPY". In contrast, the Thin driver generates all error messages with the prefix "DPY".

Exception Classes
------------------

The classes of exception in python-oracledb Thick and Thin drivers follow this approach:

* 1000-1999: exceptions.InterfaceError
* 2000-2999: exceptions.ProgrammingError
* 3000-3999: exceptions.NotSupportedError
* 4000-4999: exceptions.DatabaseError 

The class of each message is the same as in cx_Oracle. cx_Oracle code that used only the predefined exception classes will not need to be changed when migrating to python-oracledb, even with the introduction of a DPY prefix.

.. note::

   Some of the errors like DPY-6001 are OperationalError but this is a subclass of DatabaseError so they can be caught the same way as in cx_Oracle.

Error Messages
--------------

In the Thick driver, error messages generated by OCI and ODPI-C will be returned unchanged from cx_Oracle with the following exception:

pool.acquire(): ORA errors will be mapped to DPY errors. For example, "DPY-nnnn: timed out waiting for pool to have free connections available or create new connections" will replace the old cx_Oracle error "ORA-24459: OCISessionGet() timed out waiting for pool to create new connections".

Some of the client-side messages vary between the Thick and Thin drivers and are listed below:

* The error messages generated when binding is not done properly differs in the Thin and Thick driver. 
  The Thick driver generates these exceptions:

  - ORA-01008: not all variables bound
  - ORA-01036: illegal variable name/number

  The Thin driver, in contrast, generates these exceptions:

  - DPY-4010: a bind variable replacement value for placeholder "1" was not provided
  - DPY-4008: no placeholder named "x" was found in the SQL text
  - DPY-4009: 2 positional bind(s) required but only 1 positional bind(s) provided

* For Connection Pooling, the Thin driver pool is not based on the OCI Session Pool and has its own DPY messages.
* The Thin driver returns connection and network messages directly from the Python layers. The traditional Oracle connection errors with prefix ORA is not shown. Consider a scenario where the given hostname does not have a listener running. The errors differ in the Thick and Thin driver as shown below:
  
  Thick Code Error: oracledb.exceptions.DatabaseError: ORA-12541: TNS:no listener

  Thin Code Error: ConnectionRefusedError: [Errno 61] Connection refused

See :ref:`appendixa` for a complete list of feature support differences between the drivers.

Globalization
=============

See :ref:`globalization`.

Tracing
=======

See :ref:`tracingsql`.