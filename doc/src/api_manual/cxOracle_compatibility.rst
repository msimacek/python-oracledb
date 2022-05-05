.. _compatibility:

**************************************************************
Differences between cx_Oracle 8.3 and python-oracledb Drivers
**************************************************************

The python-oracledb driver has new features and a few small changes.
See :ref:`additionalfeatures` for the list of new features introduced
in the python-oracledb release.

The differences between cx_Oracle 8.3 and the python-oracledb drivers 
are listed here.

Oracle Client Library Loading
=============================

To use the python-oracledb in Thick mode, a call must be made to 
:func:`oracledb.init_oracle_client()` before any connection is established. 
This function immediately loads Oracle Client libraries. If this function is 
not called first, then python-oracledb Thin mode will be used.

Putting this call in application initialization code can mean that Oracle Client 
library loading is no longer deferred until the driver is first used, such as at 
the time the first connection is opened. This may be an issue for some 
multi-database vendor frameworks and ORMS that don't want to fail for non-Oracle 
users when python-oracledb is never going to be used. The obvious solution is to 
call :func:`oracledb.init_oracle_client()` just prior to the first point of use 
in python-oracledb. Since the function can only be called once per process, the 
application will need logic to avoid calling it multiple times.

Oracledb.connect()
==================

The :func:`oracledb.connect()` function in python-oracledb differs from cx_Oracle 
in the following ways:

    - Parameters are keyword, not positional. See :ref:`connmig`.
    - Parameters encoding and nencoding are deprecated and ignored. The encodings in 
      use are always UTF-8.
    - New optional parameter params. See the :ref:`ConnectParams Class section <connparam>`.
    - New keyword arguments that match the new :ref:`ConnectParams Class <connparam>` 
      ConnectParams() arguments. These will be used internally to create a ConnectParams 
      Class object before creating the connection.
    - The parameter threaded is deprecated. This parameter was used to allow the Oracle 
      Client libraries to support threaded applications. This parameter value is ignored 
      in python-oracledb: threaded Oracle Call Interface (OCI) is now always enabled in 
      Thick, and the option is not relevant to Thin.

The use of the class constructor method ``Oracledb.Connection()`` is no longer
recommended for creating connections.

Connection object
=================

The differences between the Connection object in the python-oracledb driver and cx_Oracle driver are listed below:

    -   The attribute :attr:`Connection.maxBytesPerCharacter` is deprecated. This will return a constant value of 4 since encodings are always UTF-8.
    -   Added a new boolean attribute, :attr:`Connection.thin`. This attribute is True if the connection was established in the Thin mode. In Thick mode, the value of this attribute is False.

Oracledb.clientversion()
========================

The :func:`oracledb.clientversion()` shows the version of the Oracle Client libraries 
being used. This function can only be called in the Thick mode. It can be called only 
after oracledb.init_oracle_client() has been called. There is no Oracle client used in 
the python-oracledb Thin mode. If oracledb.clientversion() is called when in Thin mode, 
that is if oracledb.init_oracle_client() was not called first, then an exception will 
be thrown.

Applications can reference oracledb.__version__ to determine the version of python-oracledb.

Cursor.fetchmany()
==================

The name of the size argument of :meth:`Cursor.fetchmany()` is ``size``. This change 
was done to comply with `PEP 249 <https://peps.python.org/pep-0249/>`_. The previous keyword 
argument name, ``numRows`` is deprecated.

Cursor.fetchraw()
=================

:meth:`Cursor.fetchraw()` was previously deprecated in cx_Oracle 8.2 and has been 
removed in python-oracledb. Instead, use one of the other fetch methods such as 
:meth:`Cursor.fetchmany()`.

Cursor.executemanyprepared()
============================

:meth:`Cursor.executemanyprepared()` was previously deprecated in cx_Oracle 6.4 
and has been removed in python-oracledb. Instead, use :meth:`Cursor.executemany()`, 
by passing None for the statement argument and an integer for the parameters argument.

Cursor.bindarraysize
====================

The Cursor.bindarraysize attribute is deprecated and removed in python-oracledb. It is
not needed in the application code.

Cursor.rowcount
===============

After :meth:`Cursor.execute()` or :meth:`Cursor.executemany()` with PL/SQL statements, 
:attr:`Cursor.rowcount` will return 0.

If the cursor or connection are not open, then the value -1 will be returned as required
by the Python Database API.

Advanced Queueing (AQ)
======================

The old Advanced Queuing (AQ) API is not available in python-oracledb. This was 
deprecated in cx_Oracle 7.2. Replace with the new Advanced Queuing (AQ) shown in 
the python-oracledb user documentation. Note AQ is only available in the Thick mode. 
Replace:

    - :meth:`Connection.deq()` with :meth:`Queue.deqone()` or :meth:`Queue.deqmany()`
    - :meth:`Connection.deqoptions()` with attribute :attr:`Queue.deqoptions`
    - :meth:`Connection.enq()` with :meth:`Queue.enqone()` or :meth:`Queue.enqmany()`
    - :meth:`Connection.deqoptions()` with attribute :attr:`Queue.deqoptions`

Pooling
=======

It is recommended to use the new equivalent :ref:`ConnectionPool Class <connpool>` 
instead of the SessionPool class, which is deprecated. To create a connection pool,
use :meth:`oracledb.create_pool()`, which is equivalent to calling `cx_Oracle.SessionPool 
<https://cx-oracle.readthedocs.io/en/latest/api_manual/module.html#cx_Oracle.SessionPool>`__.

oracledb.SessionPool()
----------------------

The ``oracledb.SessionPool`` method which is an alias of the :func:`oracledb.create_pool()`
method in python-oracledb differs from `cx_Oracle.SessionPool() 
<https://cx-oracle.readthedocs.io/en/latest/api_manual/module.html#cx_Oracle.SessionPool>`_ 
as follows:

    - Parameters are keyword, not positional. See :ref:`connmig`.
    - Passing a value to the dsn parameter that contains the user name and password is now supported in the same way as :func:`oracledb.connect()`. For example ``dsn="un/pw@cs"`` can be used.
    - Parameters ``encoding`` and ``nencoding`` are deprecrated and ignored. The encodings in use are always UTF-8.
    - The default mode is :data:`~oracledb.POOL_GETMODE_WAIT` instead of :data:`~oracledb.POOL_GETMODE_NOWAIT`. If the mode :data:`~oracledb.POOL_GETMODE_NOWAIT` is truly desired, modify any pool creation code to specify this value instead.
    - New optional parameter ``params``. See the :ref:`PoolParams Class <poolparam>` section.
    - New keyword arguments that match the new :ref:`PoolParams Class <poolparam>` ``PoolParams()`` arguments. These will be used internally to create a PoolParams Class object before creating the pool.
    - A Python type() will show the class as ``oracledb.ConnectionPool`` instead of ``cx_Oracle.SessionPool``.

SessionPool Object
------------------

The SessionPool object which is an alias of the ConnectionPool 
object in python-oracledb has a new boolean attribute ``SessionPool.thin``. 
If the connections within it use the python-oracledb Thin mode, then the
value of this attribute is True. Otherwise, the value of this attribute is False.

Dead Connection Detection Messages
===================================

The application code which detects dead connections will need to check for new error 
numbers. The scenarios detailed below show the various dead connection detection messages 
that are displayed for the python-oracledb Thin and Thick modes and the cx_Oracle 8.3 driver.

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

.. _supporteddbtypes:

Supported Database Types
========================

See `Oracle Database Types <https://docs.oracle.com/en/database/oracle/oracle-database/21/sqlrf/Data-Types.html#GUID-A3C0D836-BADB-44E5-A5D4-265BA5968483>`__ and `PL/SQL Types <https://docs.oracle.com/en/database/oracle/oracle-database/21/lnpls/plsql-data-types.html#GUID-391C58FD-16AF-486C-AF28-173E309CDBA5>`__.

The following table lists the Oracle database types that are supported in the python-oracledb driver (both Thin and Thick modes) and the cx_Oracle 8.3 driver.

.. list-table-with-summary::  Oracle Database Types Supported in the python-oracledb Thin Mode, python-oracle-db Thick Mode, and cx_Oracle Driver
    :header-rows: 1
    :align: center
    :summary: The first column displays the database type. The second column displays the python-oracledb Constant Name. The third column indicates if the datatype is supported in the python-oracledb Thin mode, python-oracledb Thick mode, and cx_Oracle.

    * - Database Type
      - python-oracledb Constant Name
      - Supported in python-oracledb (Thin and Thick modes) and cx_Oracle 8.3
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
      - DB_TYPE_ROWID (May show DB_TYPE_UROWID in metadata. See :ref:`Query Metadata Differences <querymetadatadiff>`.)
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
      - Not supported in python-oracledb Thin mode
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
      - Not supported in python-oracledb Thin mode
    * - ANYDATA
      - DB_TYPE_OBJECT
      - Not supported in python-oracledb Thin mode
    * - ANYDATASET
      - DB_TYPE_OBJECT
      - Not supported in python-oracledb Thin mode
    * - XMLType
      - DB_TYPE_OBJECT
      - Not supported in python-oracledb Thin mode
    * - HTTPURIType
      - DB_TYPE_OBJECT
      - Not supported in python-oracledb Thin mode
    * - XDBURIType
      - DB_TYPE_OBJECT
      - Not supported in python-oracledb Thin mode
    * - DBURIType
      - DB_TYPE_OBJECT
      - Not supported in python-oracledb Thin mode
    * - User-defined types (object type, VARRAY, records, collections, SDO_*types)
      - DB_TYPE_OBJECT
      - Not supported in python-oracledb Thin mode

Binding of contiguous PL/SQL Index-by BINARY_INTEGER arrays of string, number, and date are 
supported in python-oracledb Thin and Thick modes. Use :meth:`Cursor.arrayvar()` to build 
these arrays.
