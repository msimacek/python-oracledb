.. _appendixa:

***********************************************************************************************************
Appendix A: Feature Support Differences between python-oracledb Thin, python-oracledb Thick, and cx_Oracle
***********************************************************************************************************

The following table describes the differences in the way Oracle features are supported by the three drivers.

.. list-table-with-summary::  Feature Support between python-oracledb Thin, python-oracledb Thick, and cx_Oracle drivers
    :header-rows: 1
    :align: center
    :summary: The first column displays the Oracle feature. The second column indicated whether the feature is supported by the python-oracledb Thin driver. The third column indicates the difference between python-oracledb Thick and cx_Oracle. The fourth column indicates if the feature is supported in cx_Oracle.

    * - Oracle Feature
      - Support for Thin Driver
      - Differences between Thick and cx_Oracle
      - Support for cx_Oracle
    * - Oracle Client version
      - n/a
      -
      - 11.2+
    * - Oracle Database version
      - Release 12.1 and later.
      -
      - Release 9.2 and later depending on Oracle Client library version
    * - Client/Server version interoperability
      - Yes 
      -
      - Yes 
    * - Thin driver
      - Yes 
      -
      - No - Uses libclntsh
    * - Standalone connections
      - Yes 
      - Must use named arguments, see :ref:`syntax`
      - Yes 
    * - Connection pooling
      - Yes - new implementation in Thin.   Review ``getmode`` default change, see :ref:`connpooling`.
      - Must use named arguments, see :ref:`syntax`
      - Yes - through the Oracle Call Interface (OCI) Connection Pool
    * - Homogeneous connection pools
      - Yes 
      -
      - Yes 
    * - Heterogeneous connection pools
      - No
      -
      - Yes 
    * - Pool draining
      - Yes 
      -
      - Yes 
    * - Session tagging in session pool
      - No
      -
      - Yes 
    * - Proxy connection
      - No
      -
      - Yes 
    * - OCI_ATTR_CURRENT_SCHEMA
      - Yes 
      -
      - Yes 
    * - External authentication
      - No
      -
      - Yes 
    * - SYSDBA, SYSOPER, SYSASM, SYSBKP, SYSDGD, SYSKMT, SYSRAC
      - Yes 
      -
      - Yes 
    * - Prelim connections
      - No
      -
      - Yes 
    * - Cloud connectivity
      - Yes 
      -
      - Yes 
    * - RAC
      - Yes 
      -
      - Yes 
    * - Sharding
      - No
      -
      - Yes No TIMESTAMP support (e.g Bug 30570712 or NJS Bug 31574904)
    * - Connection & Runtime Load Balancing - CLB & RLB
      - Yes for CLB
      -
      - Yes 
    * - IAM Tokens
      - No
      -
      - Yes in connection string with appropriate Oracle Client
    * - Kerberos, Radius etc authentication
      - No
      -
      - Yes 
    * - Native Network Encryption (NNE)
      - No
      -
      - Yes 
    * - Connection pinging
      - Yes 
      -
      - Yes 
    * - ``tnsnames.ora``, ``sqlnet.ora``
      - Yes (``sqlnet.ora`` ignored, ``tnsnames.ora`` supported - see :ref:`sqlnetclientconfig`)
      -
      - Yes 
    * - Client Configuration
      - No
      -
      - Yes (``oraaccess.xml``)
    * - Easy Connect
      - Yes 
      -
      - Yes 
    * - TLS aka SSL connections
      - Yes (with manual conversion from PKCS#12 to PEM format)
      -
      - Yes 
    * - Dedicated Servers
      - Yes 
      -
      - Yes 
    * - Shared Servers
      - Yes 
      -
      - Yes 
    * - DRCP
      - Yes 
      -
      - Yes 
    * - Multitenant Databases
      - Yes 
      -
      - Yes 
    * - CMAN, CMAN-TDM
      - Yes 
      -
      - Yes 
    * - Password changing
      - Yes 
      -
      - Yes 
    * - Break/reset (``connection.cancel()``)
      - Yes 
      -
      - Yes 
    * - Edition Based Redefinition (EBR)
      - No
      -
      - Yes 
    * - Python DATABASE API Support
      - Yes (mostly) - Some features not feasible.  Many extensions.
      -
      - Yes (mostly) - Some features not feasible.  Many extensions.
    * - SQL execution
      - Yes - bind and fetch all types except BFILE, OBJECT and JSON
      -
      - Yes 
    * - PL/SQL execution
      - Y scalar types. Y collection types using array interface
      -
      - Yes 
    * - Data binding
      - Yes 
      -
      - Yes 
    * - Array DML binding for bulk DML & PL/SQL (aka ``executemany()``)
      - Yes 
      -
      - Yes 
    * - SQL and PL/SQL type & collections
      - No
      -
      - Yes 
    * - Column metadata
      - Yes 
      -
      - Yes 
    * - Client character set support
      - UTF-8 (N* - types UTF-16BE)
      -
      - Yes Can use Python encodings.  Default in 8.0 is UTF-8
    * - Globalization
      - No
      -
      - Yes NLS_* - environment variables respected (except character set in NLS_LANG in 8.0)
    * - Statement caching
      - Yes 
      - New driver supports dropping from the cache, see :ref:`stmtcaching`.
      - Yes 
    * - Row prefetching
      - Yes 
      -
      - Yes Configurable in 8.0
    * - Array fetching (with prefetch on execute)
      - Yes 
      -
      - Yes 
    * - Client Result Caching (CRC)
      - No
      -
      - Yes 
    * - In-band  notifications
      - Yes 
      -
      - Yes 
    * - Continuous Query Notification (CQN)
      - No
      -
      - Yes 
    * - Advanced Queuing (AQ)
      - No
      - Must use "new" cx_Oracle 7.2+ API, see the cx_Oracle `Advanced Queuing
        (AQ) <https://cx-oracle.readthedocs.io/en/latest/api_manual/aq.html>`__
        documentation.
      - Yes 
    * - AQ: Transactional Event Queue (TEQ)
      - No
      -
      - Yes 
    * - Call timeouts (via Oracle Call Interface (OCI) attribute for Thick) :attr:`Connection.call_timeout`
      - Yes
      -
      - Yes 
    * - Scrollable cursors
      - No
      -
      - Yes 
    * - DATABASE startup & shutdown
      - No
      -
      - Yes 
    * - Transaction management
      - Yes 
      -
      - Yes 
    * - Automatic Diagnostic Repository (ADR)
      - No
      -
      - Yes 
    * - Fast Application Notification (FAN)
      - No
      -
      - Yes 
    * - Transparent Application Failover (TAF)
      - No
      -
      - Yes 
    * - Transaction Guard (TG)
      - No
      -
      - Yes 
    * - Dataguard (DG) & ADG
      - No
      -
      - Yes 
    * - Application Continuity (AC and TAC)
      - No
      -
      - Yes 
    * - End-to-end monitoring and tracing attributes
      - Yes , see :ref:`tracingsql`.
      -
      - Yes 
    * - OCI_ATTR_COLLECT_CALL_TIME and OCI_ATTR_CALL_TIME
      - No (use PYO_DEBUG_PACKETS)
      -
      - No (use DPI tracing)
    * - Feature Tracking
      - No
      -
      - Y
    * - Two-phase Commit (TPC)
      - No
      - New Thick driver has improved TPC support, see :ref:`tcp`.
      - Yes (limited support)
    * - REF CURSORS
      - Yes 
      -
      - Yes 
    * - Nested Cursors
      - Yes 
      -
      - Yes 
    * - Pipelined tables
      - Yes 
      -
      - Yes 
    * - Implicit Result Sets
      - Yes 
      -
      - Yes 
    * - Application Contexts
      - No
      -
      - Yes 
    * - Persistent LOBs
      - Yes 
      -
      - Yes 
    * - Temporary LOBs
      - Yes 
      -
      - Yes 
    * - LOB prefetching
      - No
      -
      - No (does have LOB length prefetch)
    * - LOB locator operations e.g trim
      - Yes 
      -
      - Yes 
    * - INTERVAL data types
      - Y (DAY TO SECOND), N (YEAR TO MONTH)
      -
      - Y (DAY TO SECOND), N (YEAR TO MONTH)
    * - SODA
      - No
      -
      - Yes 
    * - Oracle 12c JSON
      - Yes 
      -
      - Yes 
    * - Oracle 21c JSON data type
      - No (Can fetch with an output type handler, see :ref:`Fetching JSON Differences<fetchJSON>`)
      -
      - Yes 
    * - ROWID
      - Yes 
      -
      - Yes 
    * - UROWID
      - Yes 
      -
      - Yes 
    * - XMLType data type
      - No
      -
      - No (solution is to use ``xmltype.getclobval()``)
    * - BFILE data type
      - No
      -
      - Yes 
    * - TIMESTAMP WITH TIME ZONE
      - Yes 
      -
      - Yes 
    * - NCHAR and NVARCHAR2
      - Yes 
      -
      - Yes 
    * - NCLOB
      - Yes 
      -
      - Yes 
    * - Bind PL/SQL Boolean
      - Yes 
      -
      - Yes 

A complete list of supported features can be seen `here
<https://oracle.github.io/python python-oracledb/index.html#features>`_.
