.. _driverdiff:

********************************************************
Differences between python-oracledb Thin and Thick Modes
********************************************************

The python-oracledb Thin and Thick modes have a number of differences that are 
detailed in this section.

Supported Database Types
========================

See :ref:`supporteddbtypes` for a complete list of database types that are supported in the python-oracledb Thin and Thick modes.

.. _querymetadatadiff:

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

* Only homogeneous pools are supported in the python-oracledb Thin mode.

* The python-oracledb Thin mode creates connections in a daemon thread and so :func:`oracledb.ConnectionPool()` returns before any or all minimum number of connections are created. The :attr:`ConnectionPool.opened` attribute will not be equal to :attr:`ConnectionPool.min` immediately after the pool is created but will increase to the minimum over a short time as the connections are established. Note that this behavior may also be true of recent versions of the Oracle Call Interface (OCI) Session Pool used in the Thin mode.
  
  This behavior will not be an issue if the new ``getmode`` default value of ``POOL_GETMODE_WAIT`` is used, since any immediate :meth:`ConnectionPool.acquire()` calls will wait for connections to be created by the daemon thread. This new design improves the application startup time when compared to the python-oracledb Thick mode and  8.3 driver, where :func:`oracledb.SessionPool()` will not return control to the application until all ``pool.min`` connections have been created.

  If the old default value ``POOL_GETMODE_NOWAIT`` is required, then the application could check if :attr:`ConnectionPool.opened` has reached :attr:`ConnectionPool.min` and then continue with application startup.

* In python-oracledb Thick mode, when you close a SessionPool (or a ConnectionPool class) with the parameter ``force=True``, the underlying Oracle Client libraries wait for the current SQL executions to complete before closing the connections. All of the connections are then dropped from the pool and the pool is closed. Closing the pool in python-oracledb Thick mode could stop responding indefinitely, depending on the network and Oracle Net Services timeout parameters. This is also applicable to the cx_Oracle 8.3 driver. In python-oracledb Thin mode, the parameter ``force=True`` disconnects each connection's socket using a background thread, leaving the database to clean up its end of the connections.

* In python-oracledb Thin mode, ``cclass`` is not used to tag connections in the application connection pool. It is only used for Database Resident Connection Pooling (DRCP).

* In python-oracledb Thin mode, the connection pool supports all the connection mode privileges:

    - :data:`~oracledb.AUTH_MODE_SYSDBA`
    - :data:`~oracledb.AUTH_MODE_SYSOPER`
    - :data:`~oracledb.AUTH_MODE_SYSASM`
    - :data:`oracledb.AUTH_MODE_SYSBKP`
    - :data:`oracledb.AUTH_MODE_SYSDGD`
    - :data:`oracledb.AUTH_MODE_SYSKMT`
    - :data:`oracledb.AUTH_MODE_SYSRAC`
  
  The python-oracledb Thick mode does not support all of these privileges.

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

With a type handler, the python-oracledb Thin mode is effectively equivalent to using the python-oracledb Thick mode with Oracle Client 21c. The python-oracledb Thin mode returns timestamps in a string representation. Without a type handler, the python-oracledb Thin mode gives an error that DB_TYPE_JSON is not supported.

The type handler is not needed in python-oracledb Thick mode. If the type handler is used, the behavior is the same as when it is used in the python-oracledb Thin mode.

The type handler is not needed when fetching from the Oracle Database 19c JSON type, since this is represented as VARCHAR2 or LOB.

Connection and Connection Configuration
=======================================

The way the connection is established to the Oracle Database and the connection configurations required differs in the python-oracledb Thin and Thick modes. See :ref:`connconfig`. 

.. _errorhandling:

Error Handling
==============

Error Message Prefixes
----------------------

Both the python-oracledb Thick and the Thin modes return error messages generated by the database unchanged. On the server side, Oracle Database and Oracle Net Services return error messages with the prefix "ORA". 

Error messages generated by the client behave differently. The python-oracledb Thick mode returns error messages generated by Oracle Call Interface (OCI) with the prefix "ORA", ODPI-C with the prefix "DPI", and the driver itself with the prefix "DPY". In contrast, the python-oracledb Thin mode generates all error messages with the prefix "DPY".

Error Messages
--------------

In python-oracledb Thick mode, error messages generated by OCI and ODPI-C will be returned unchanged from cx_Oracle 8.3 with the following exception:

``pool.acquire()``: ORA errors will be mapped to DPY errors. For example::

  DPY-nnnn: timed out waiting for pool to have free connections available or create new connections

will replace the old cx_Oracle 8.3 error::

  ORA-24459: OCISessionGet() timed out waiting for pool to create new connections

Some of the client-side messages vary between the python-oracledb Thick and Thin modes and are listed below:

* Binding: The error messages that are generated when binding is not done properly differs in the python-oracledb Thin and Thick modes. 
  The python-oracledb Thick mode generates these exceptions::

    ORA-01008: not all variables bound
    ORA-01036: illegal variable name/number

  In contrast, the python-oracledb Thin mode generates these exceptions::

    DPY-4010: a bind variable replacement value for placeholder "1" was not provided
    DPY-4008: no placeholder named "x" was found in the SQL text
    DPY-4009: 2 positional bind(s) required but only 1 positional bind(s) provided

* Connection Pooling: The python-oracledb Thin mode pool is not based on the Oracle Call Interface (OCI) Session Pool and has its own DPY messages.
* Connection and Network messages: The python-oracledb Thin mode returns connection and network messages directly from the Python layers. The traditional Oracle connection errors with prefix ``ORA`` is not shown. For example, the scenarios detailed below show how the connection and network error messages differ for the python-oracledb Thick and Thin modes on a macOS:

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


See the :ref:`list of features <appendixa>` for a complete list of features that are supported in the python-oracledb Thin and Thick modes and the cx_Oracle 8.3 driver.

Globalization
=============

See :ref:`globalization`.

Tracing
=======

See :ref:`tracingsql`.