.. _driverdiff:

********************************************************
Differences between python-oracledb Thin and Thick Modes
********************************************************

The python-oracledb Thin and Thick modes have a number of differences that are detailed in this section.

Supported Database Types
========================

See `Oracle Database Types <https://docs.oracle.com/en/database/oracle/oracle-database/21/sqlrf/Data-Types.html#GUID-A3C0D836-BADB-44E5-A5D4-265BA5968483>`__ and `PL/SQL Types <https://docs.oracle.com/en/database/oracle/oracle-database/21/lnpls/plsql-data-types.html#GUID-391C58FD-16AF-486C-AF28-173E309CDBA5>`__.

The following table lists the Oracle database types that are supported in the python-oracledb driver (both Thin and Thick modes) and the cx_Oracle driver.

.. list-table-with-summary::  Oracle Database Types Supported in the python-oracledb Thin Mode, python-oracle-db Thick Mode, and cx_Oracle Driver
    :header-rows: 1
    :align: center
    :summary: The first column displays the database type. The second column displays the python-oracledb Constant Name. The third column indicates if the datatype is supported in the python-oracledb Thin mode, python-oracledb Thick mode, and cx_Oracle.

    * - Database Type
      - python-oracledb Constant Name
      - Supported in python-oracledb (Thin and Thick modes) and cx_Oracle
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
      - DB_TYPE_ROWID (May show DB_TYPE_UROWID in metadata. See :ref:`Query Metadata Differences <querymetadata>`.)
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
      - Not supported in Thin mode
    * - JSON
      - DB_TYPE_JSON
      - Yes for Oracle Database versions 19c and earlier. With Oracle Database 21c, use an output type handler. See :ref:`Fetching JSON Differences <fetchJSON>`.
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
      - Not supported in Thin mode
    * - ANYDATA
      - DB_TYPE_OBJECT
      - Not supported in Thin mode
    * - ANYDATASET
      - DB_TYPE_OBJECT
      - Not supported in Thin mode
    * - XMLType
      - DB_TYPE_OBJECT
      - Not supported in Thin mode
    * - HTTPURIType
      - DB_TYPE_OBJECT
      - Not supported in Thin mode
    * - XDBURIType
      - DB_TYPE_OBJECT
      - Not supported in Thin mode
    * - DBURIType
      - DB_TYPE_OBJECT
      - Not supported in Thin mode
    * - User-defined types (object type, VARRAY, records, collections, SDO_*types)
      - DB_TYPE_OBJECT
      - Not supported in Thin mode

Binding of contiguous PL/SQL Index-by BINARY_INTEGER arrays of string, number, and date are supported in python-oracledb Thin and Thick modes. Use :meth:`Cursor.arrayvar()` to build these arrays.

.. _querymetadata:

Query Metadata
===============

In python-oracledb Thin mode, :data:`Cursor.description` metadata distinguishes the ROWID and UROWID database types. The UROWID database type shows the new value DB_TYPE_UROWID, while the database type ROWID uses the existing value DB_TYPE_ROWID.

In python-oracledb Thick mode, the value DB_TYPE_ROWID is shown for both ROWID and UROWID database types. In python-oracledb Thick and Thin modes, comparison with the type oracledb.ROWID (defined in the Python DB API) will match both ROWID and UROWID database types.

.. _stmtcaching:

Statement Caching
=================

The statement cache implemented in the python-oracledb Thin mode is capable of determining when different data types are used for the same bind variables when a statement is re-executed. This capability is missing in the Oracle Client libraries that are used in python-oracledb Thick mode. Changing the type of bind variables for the same SQL text is inappropriate and gives indeterminate results.

See also :ref:`stmtcache` for more information.

oracledb.ConnectionPool()
=========================

All the parameters in the :func:`oracledb.ConnectionPool()` are not applicable to the python-oracledb Thin mode. The :func:`oracledb.ConnectionPool()` in the python-oracledb Thin mode differs from the python-oracledb Thick mode in the following ways:

* The python-oracledb Thin mode ignores unrecognized parameters. The python-oracledb Thin mode supports the following ``ConnectionPool`` parameters:
   - min
   - max
   - increment
   - getmode
   - wait_timeout
   - ping_interval
   - stmtcachesize
* ``getmode=oracledb.SPOOL_ATTRVAL_TIMEDWAIT`` is not implemented in the Thin mode.
* Only homogeneous pools are supported in the python-oracled Thin mode.
* The python-oracled Thin mode creates connections in a daemon thread and so :func:`oracledb.ConnectionPool()` returns before any or all minimum number of connections are created. The :attr:`ConnectionPool.opened` attribute will not be equal to :attr:`ConnectionPool.min` immediately after the pool is created but will increase to the minimum over a short time as the connections are established. Note that this behavior may also be true of recent versions of the Oracle Call Interface (OCI) Session Pool used in the Thin mode.
  
  This behavior will not be an issue if the new ``getmode`` default value of ``POOL_GETMODE_WAIT`` is used, since any immediate :meth:`ConnectionPool.acquire()` calls will wait for connections to be created by the daemon thread. This new design improves the application startup time when compared to the python-oracledb Thick mode and cx_Oracle driver, where :func:`oracledb.SessionPool()` will not return control to the application until all ``pool.min`` connections have been created.

  If the old default value ``POOL_GETMODE_NOWAIT`` is required, then the application could check if :attr:`ConnectionPool.opened` has reached :attr:`ConnectionPool.min` and then continue with application startup.

* In python-oracledb Thick mode, when you close a SessionPool (or a ConnectionPool class) with the parameter ``force=True``, the underlying Oracle Client libraries wait for the current SQL executions to complete before closing the connections. All of the connections are then dropped from the pool and the pool is closed. Closing the pool in python-oracledb Thick mode could stop responding indefinitely, depending on the network and Oracle Net Services timeout parameters. This is also applicable to the cx_Oracle driver. In python-oracledb Thin mode, the parameter ``force=True`` disconnects each connection's socket using a background thread, leaving the database to clean up its end of the connections.
* In python-oracled Thin mode, ``cclass`` is not used to tag connections in the application connection pool. It is only used for Database Resident Connection Pooling (DRCP).

Also, see :ref:`Connections <connconfig>`.

See :ref:`connpool` for more information about the ConnectionPool class.

.. _fetchJSON:

Fetching JSON
=============

If an output type handler is used, then the python-oracledb Thin mode is able to fetch the Oracle Database 21c JSON datatype using the following code:

.. code-block:: python

    def type_handler(cursor, name, default_type, size, precision, scale):
        if default_type == oracledb.DB_TYPE_JSON:
            return cursor.var(str, arraysize=cursor.arraysize)

To automatically convert to a Python object (like it would automatically be done with an Oracle 21c Thick client), use the following code:

.. code-block:: python

    def type_handler(cursor, name, default_type, size, precision, scale):
        if default_type == oracledb.DB_TYPE_JSON:
            return cursor.var(str, arraysize=cursor.arraysize,
                              outconverter=json.loads)

With a type handler, the python-oracledb Thin mode is effectively equivalent to using the python-oracledb Thick mode with Oracle Client 21c. The python-oracled Thin mode returns timestamps in a string representation. Without a type handler, the python-oracled Thin mode gives an error that DB_TYPE_JSON is not supported.

The type handler is not needed in python-oracled Thick mode. If the type handler is used, the behavior is the same as when it is used in the python-oracled Thin mode.

The type handler is not needed when fetching from the Oracle Database 19c JSON type, since this is represented as VARCHAR2 or LOB.

Connection and Connection Configuration
=======================================

The way the connection is established to the Oracle Database and the connection configurations required differs in the python-oracledb Thin and Thick modes. See :ref:`connconfig`. 

.. _errorhandling:

Error Handling
==============

Error Message Prefixes
----------------------

Both the python-oracled Thick and the Thin modes return error messages generated by the database unchanged. On the server side, Oracle Database and Oracle Net Services return error messages with the prefix "ORA". 

Error messages generated by the client behave differently. The python-oracled Thick mode returns error messages generated by Oracle Call Interface (OCI) with the prefix "ORA", ODPI-C with the prefix "DPI", and the driver itself with the prefix "DPY". In contrast, the python-oracled Thin mode generates all error messages with the prefix "DPY".

Exception Classes
------------------

The classes of exception in the python-oracledb Thick and Thin modes follow this approach:

  * 1000-1999: exceptions.InterfaceError
  * 2000-2999: exceptions.ProgrammingError
  * 3000-3999: exceptions.NotSupportedError
  * 4000-4999: exceptions.DatabaseError 

The class of each message is the same as in cx_Oracle. cx_Oracle code that used only the predefined exception classes will not need to be changed when migrating to python-oracledb, even with the introduction of a DPY prefix.

.. note::

   Some of the errors like DPY-6001 are OperationalError but this is a subclass of DatabaseError so they can be caught the same way as in cx_Oracle.

Error Messages
--------------

In python-oracled Thick mode, error messages generated by OCI and ODPI-C will be returned unchanged from cx_Oracle with the following exception:

``pool.acquire()``: ORA errors will be mapped to DPY errors. For example::

  DPY-nnnn: timed out waiting for pool to have free connections available or create new connections

will replace the old cx_Oracle error::

  ORA-24459: OCISessionGet() timed out waiting for pool to create new connections

Some of the client-side messages vary between the python-oracled Thick and Thin modes and are listed below:

* Binding: The error messages that are generated when binding is not done properly differs in the python-oracled Thin and Thick modes. 
  The python-oracled Thick mode generates these exceptions::

    ORA-01008: not all variables bound
    ORA-01036: illegal variable name/number

  In contrast, the python-oracled Thin mode generates these exceptions::

    DPY-4010: a bind variable replacement value for placeholder "1" was not provided
    DPY-4008: no placeholder named "x" was found in the SQL text
    DPY-4009: 2 positional bind(s) required but only 1 positional bind(s) provided

* Connection Pooling: The python-oracled Thin mode pool is not based on the Oracle Call Interface (OCI) Session Pool and has its own DPY messages.
* Connection and Network messages: The python-oracled Thin mode returns connection and network messages directly from the Python layers. The traditional Oracle connection errors with prefix ``ORA`` is not shown. For example, the scenarios detailed below show how the connection and network error messages differ for the python-oracled Thick and Thin modes on a macOS:

  * Scenario 1: The given hostname does not have a listener running.

    Thick Error::

      oracledb.exceptions.DatabaseError: ORA-12541: TNS:no listener

    Thin Error::

      ConnectionRefusedError: [Errno 61] Connection refused

  * Scenario 2: dsn="xyz" and there is no tnsnames.ora file.

    Thick Error::

      oracledb.exceptions.DatabaseError: ORA-12154: TNS:could not resolve the connect identifier specified

    Thin Error::

      oracledb.exceptions.DatabaseError: DPY-4000: unable to find xyz in tnsnames.ora

  * Scenario 3: dsn="localhost/xyz" where there is a listener on the host

    Thick Error::

      oracledb.exceptions.DatabaseError: ORA-12514: TNS:listener does not currently know of service requested in connect descriptor

    Thin Error::

      oracledb.exceptions.OperationalError: DPY-6001: listener doesn't recognize service name see ORA-12514

* Dead Connection Detection messages: Application code which detects dead connections will need to check for new error numbers. The scenarios detailed below show the various dead connection detection messages that are displayed for the python-oracledb Thin and Thick modes and the cx_Oracle driver.

  * Scenario 1: An already closed or dead connection was attempted to be used.

    Thin Error::

      DPY-1001: not connected to database

    Thick Error::

      DPY-1001: not connected to database

    cx_Oracle Error::

      not connected

  * Scenario 2: A connection error occurred while using the connection. For example, the database side of the connection was terminated.

    Thin Error::

      DPY-4011: the database or network closed the connection
      DPI-1080: connection was closed by ORA-%d

    Thick Error::

      DPY-4011: the database or network closed the connection
      DPI-1080: not connected

    cx_Oracle Error::

      DPI-1080: connection was closed by ORA-%d

  * Scenario 3: Using connection.call_timeout

    Thin Error::

      DPY-4024: call timeout of {timeout} ms exceeded

    Thick Error::

      DPY-4024: call timeout of {timeout} ms exceeded
      DPI-1067: call timeout of %u ms exceeded with ORA-%d

    cx_Oracle::

      DPI-1067: call timeout of %u ms exceeded with ORA-%d


See the :ref:`list of features <appendixa>` for a complete list of features that are supported in the python-oracledb Thin and Thick modes and the cx_Oracle driver.

Globalization
=============

See :ref:`globalization`.

Tracing
=======

See :ref:`tracingsql`.