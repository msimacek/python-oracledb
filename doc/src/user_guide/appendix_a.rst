.. _appendixa:

***********************************************************************************************************
Appendix A: Features Supported in python-oracledb Thin Mode, python-oracledb Thick Mode, and cx_Oracle 8.3
***********************************************************************************************************

By default, python-oracledb runs in a 'Thin' mode which connects directly to
Oracle Database.  This mode does not need Oracle Client libraries however some
additional functionality are available when python-oracledb uses them.
Python-oracledb connections are said to be in 'Thick' mode when these libraries
are used.  Both modes have comprehensive functionality supporting the Python
Database API v2.0 Specification.

The following table describes the Oracle Database features supported by
python-oracledb Thin and Thick modes, and by cx_Oracle 8.3.

.. list-table-with-summary::  Features Supported in python-oracledb (Thin mode and Thick mode) and cx_Oracle 8.3 Drivers
    :header-rows: 1
    :align: center
    :summary: The first column displays the Oracle feature. The second column indicates whether the feature is supported in the python-oracledb Thin mode. The third column indicates whether the feature is supported in the python-oracledb Thick mode. The fourth column indicates if the feature is supported in cx_Oracle 8.3.

    * - Oracle Feature
      - python-oracledb Thin Mode
      - python-oracledb Thick Mode
      - cx_Oracle 8.3
    * - Oracle Client version
      - Not applicable
      - Release 11.2 and later
      - Release 11.2 and later
    * - Oracle Database version
      - Release 12.1 and later
      - Release 9.2 and later depending on Oracle Client library version
      - Release 9.2 and later depending on Oracle Client library version
    * - Standalone connections
      - Yes - Must use named arguments, see :ref:`syntax`
      - Yes - Must use named arguments, see :ref:`syntax`
      - Yes
    * - Connection pooling
      - Yes - See :ref:`connpooling`. Must use named arguments, see :ref:`syntax`.
      - Yes - See :ref:`connpooling`. Must use named arguments, see :ref:`syntax`.
      - Yes
    * - Homogeneous connection pools
      - Yes
      - Yes
      - Yes
    * - Heterogeneous connection pools
      - No
      - Yes
      - Yes
    * - Pool draining
      - Yes
      - Yes
      - Yes
    * - Connection pool session state callback
      - Yes - Python function but not PL/SQL function
      - Yes
      - Yes
    * - Connection pool session tagging
      - No
      - Yes
      - Yes
    * - Proxy connections
      - No
      - Yes
      - Yes
    * - Set the current schema using an attribute
      - Yes
      - Yes
      - Yes
    * - External authentication
      - No
      - Yes
      - Yes
    * - SYSDBA, SYSOPER, SYSASM, SYSBKP, SYSDGD, SYSKMT, SYSRAC
      - Yes
      - Yes
      - Yes
    * - Prelim connections
      - No
      - Yes
      - Yes
    * - RAC
      - Yes
      - Yes
      - Yes
    * - Sharding
      - No
      - Yes - No TIMESTAMP support (for example, Bug 30570712 or NJS Bug 31574904)
      - Yes - No TIMESTAMP support (for example, Bug 30570712 or NJS Bug 31574904)
    * - Connection Pool Connection Load Balancing (CLB)
      - Yes
      - Yes
      - Yes
    * - Connection Pool Runtime Load Balancing (RLB)
      - No
      - Yes
      - Yes
    * - IAM Tokens
      - No
      - Yes - in connection string with appropriate Oracle Client
      - Yes - in connection string with appropriate Oracle Client
    * - Kerberos, Radius etc authentication
      - No
      - Yes
      - Yes
    * - Native Network Encryption (NNE)
      - No
      - Yes
      - Yes
    * - Connection pinging API
      - Yes
      - Yes
      - Yes
    * - ``tnsnames.ora``
      - Yes
      - Yes
      - Yes
    * - ``sqlnet.ora``
      - No - many values can be set using the :ref:`ConnectParams class <connparam>`.
      - Yes
      - Yes
    * - Oracle Client library configuration file ``oraaccess.xml``
      - No
      - Yes
      - Yes
    * - Easy Connect connection strings
      - Yes - mostly supported. Unknown settings are ignored and not passed to Oracle Database.
      - Yes
      - Yes
    * - Cloud connectivity
      - Yes
      - Yes
      - Yes
    * - One-way TLS (SSL connections)
      - Yes
      - Yes
      - Yes
    * - Two-way TLS (Mutual TLS or mTLS)
      - Yes - with manual conversion from PKCS#12 to PEM format, subject to Cloud wallet enhancements
      - Yes
      - Yes
    * - Dedicated Servers
      - Yes
      - Yes
      - Yes
    * - Shared Servers
      - Yes
      - Yes
      - Yes
    * - Database Resident Connection Pooling (DRCP)
      - Yes
      - Yes
      - Yes
    * - Multitenant Databases
      - Yes
      - Yes
      - Yes
    * - CMAN, CMAN-TDM
      - Yes
      - Yes
      - Yes
    * - Password changing
      - Yes
      - Yes
      - Yes
    * - Break/reset (:meth:`Connection.cancel()`)
      - Yes
      - Yes
      - Yes
    * - Edition Based Redefinition (EBR)
      - No
      - Yes
      - Yes
    * - Python DATABASE API Support
      - Yes - some features are not feasible. Many extensions.
      - Yes - some features are not feasible. Many extensions.
      - Yes - some features are not feasible. Many extensions.
    * - SQL execution
      - Yes - bind and fetch all types except BFILE, OBJECT, and JSON
      - Yes
      - Yes
    * - PL/SQL execution
      - Yes for scalar types. Yes for collection types using array interface.
      - Yes
      - Yes
    * - Bind variables for data binding
      - Yes
      - Yes
      - Yes
    * - Array DML binding for bulk DML and PL/SQL (:meth:`Cursor.executemany()`)
      - Yes
      - Yes
      - Yes
    * - SQL and PL/SQL type and collections
      - No
      - Yes
      - Yes
    * - Column metadata
      - Yes
      - Yes
      - Yes
    * - Client character set support
      - UTF-8 - see :ref:`globalization`
      - UTF-8
      - Yes - can use Python encodings. Default in 8.0 is UTF-8
    * - Oracle Globalization support
      - No - NLS_* environment variables are ignored
      - Yes - NLS_* environment variables are respected except character set
      - Yes - NLS_* environment variables are respected (except character set in NLS_LANG as of cx_Oracle 8.0)
    * - Statement caching
      - Yes - New driver supports dropping from the cache, see :ref:`stmtcache`.
      - Yes - New driver supports dropping from the cache, see :ref:`stmtcache`.
      - Yes
    * - Row prefetching on first execute
      - Yes
      - Yes
      - Yes
    * - Array fetching
      - Yes
      - Yes
      - Yes
    * - Client Result Caching (CRC)
      - No
      - Yes
      - Yes
    * - In-band notifications
      - Yes
      - Yes
      - Yes
    * - Continuous Query Notification (CQN)
      - No
      - Yes
      - Yes
    * - Advanced Queuing (AQ)
      - No
      - Yes - must use "new" cx_Oracle 7.2 and later API. See the cx_Oracle `Advanced Queuing
        (AQ) <https://cx-oracle.readthedocs.io/en/latest/api_manual/aq.html>`__ documentation.
      - Yes
    * - Call timeouts :attr:`Connection.call_timeout`
      - Yes
      - Yes
      - Yes
    * - Scrollable cursors
      - No
      - Yes
      - Yes
    * - DATABASE startup & shutdown
      - No
      - Yes
      - Yes
    * - Transaction management
      - Yes
      - Yes
      - Yes
    * - Automatic Diagnostic Repository (ADR)
      - No
      - Yes
      - Yes
    * - ''Events'' mode for notifications
      - No
      - Yes
      - Yes
    * - Fast Application Notification (FAN)
      - No
      - Yes
      - Yes
    * - Fast Connection Failover (FCF)
      - No
      -
      -
    * - Transparent Application Failover (TAF)
      - No
      - Yes - no callback
      - Yes - no callback
    * - Transaction Guard (TG)
      - No
      - Yes
      - Yes
    * - Dataguard (DG) & ADG
      - Yes
      - Yes
      - Yes
    * - Application Continuity (AC and TAC)
      - No
      - Yes
      - Yes
    * - End-to-end monitoring and tracing attributes
      - Yes - see :ref:`tracingsql`
      - Yes
      - Yes
    * - Java Debug Wire Protocol for debugging PL/SQL
      - Yes - using the connection parameter ``debug_jdwp`` or the ORA_DEBUG_JDWP environment variable
      - Yes - using the ``ORA_DEBUG_JDWP`` environment variable
      - Yes - using the ``ORA_DEBUG_JDWP`` environment variable
    * - OCI_ATTR_COLLECT_CALL_TIME and OCI_ATTR_CALL_TIME
      - No - use PYO_DEBUG_PACKETS
      - No - use DPI tracing
      - No - use DPI tracing
    * - Feature Tracking
      - No
      - Yes
      - Yes
    * - Two-phase Commit (TPC)
      - No
      - Yes - improved support, see :ref:`tcp`
      - Yes - limited support
    * - REF CURSORS
      - Yes
      - Yes
      - Yes
    * - Nested Cursors
      - Yes
      - Yes
      - Yes
    * - Pipelined tables
      - Yes
      - Yes
      - Yes
    * - Implicit Result Sets
      - Yes
      - Yes
      - Yes
    * - Application Contexts
      - No
      - Yes
      - Yes
    * - Persistent LOBs
      - Yes
      - Yes
      - Yes
    * - Temporary LOBs
      - Yes
      - Yes
      - Yes
    * - LOB prefetching
      - No
      - No - does have LOB length prefetch
      - No - does have LOB length prefetch
    * - LOB locator operations such as trim
      - Yes
      - Yes
      - Yes
    * - INTERVAL data types
      - Y (DAY TO SECOND), N (YEAR TO MONTH)
      - Y (DAY TO SECOND), N (YEAR TO MONTH)
      - Y (DAY TO SECOND), N (YEAR TO MONTH)
    * - SODA
      - No
      - Yes
      - Yes
    * - Oracle 12c JSON
      - Yes
      - Yes
      - Yes
    * - Oracle 21c JSON data type
      - No - can fetch with an output type handler, see :ref:`Fetching JSON Differences<fetchJSON>`
      - Yes
      - Yes
    * - ROWID
      - Yes
      - Yes
      - Yes
    * - UROWID
      - Yes
      - Yes
      - Yes
    * - XMLType data type
      - No - solution is to use ``xmltype.getclobval()``
      - No - solution is to use ``xmltype.getclobval()``
      - No - solution is to use ``xmltype.getclobval()``
    * - BFILE data type
      - No
      - Yes
      - Yes
    * - TIMESTAMP WITH TIME ZONE
      - Yes
      - Yes
      - Yes
    * - NCHAR and NVARCHAR2
      - Yes
      - Yes
      - Yes
    * - NCLOB
      - Yes
      - Yes
      - Yes
    * - Bind PL/SQL Boolean
      - Yes
      - Yes
      - Yes

A complete list of supported features can be seen `here
<https://oracle.github.io/python python-oracledb/index.html#features>`_.
