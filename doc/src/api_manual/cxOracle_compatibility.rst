.. _compatibility:

***************************
cx_Oracle 8.3 Compatibility
***************************

The changes between cx_Oracle 8.3 and the python-oracledb Thin and Thick drivers are listed here.

Oracle Client Library Loading
=============================

To use the python-oracledb Thick driver, a call must be made to :func:`oracledb.init_oracle_client()` before any connection is established. This function immediately loads Oracle Client libraries. If :func:`oracledb.init_oracle_client()` is not called first, then python-oracledb Thin will be used.

Putting this call in application initialization code can mean that Oracle Client library loading is no longer deferred until the driver is first used, such as at the time the first connection is opened. This may be an issue for some multi-database vendor frameworks and ORMS that don't want to fail for non-Oracle users when python-oracledb is never going to be used. The obvious solution is to call :func:`oracledb.init_oracle_client()` just prior to the first point of use in python-oracledb. Since the function can only be called once per process, the application will need logic to avoid calling it multiple times.

Oracledb.connect()
==================

The :func:`oracledb.connect()` function in python-oracledb differs from cx_Oracle in the following ways:

    - Parameters are keyword, not positional. See :ref:`connmig`.
    - Parameters ``encoding`` and ``nencoding`` are deprecated and ignored. The encodings in use are always UTF-8.
    - New optional parameter params. See the :ref:`ConnectParams Class section<connparam>`.
    - New keyword arguments that match the new ConnectParams Class ConnectParams() arguments. These will be used internally to create a ConnectParams Class object before creating the connection.
    - Deprecated parameter ``threaded``. This parameter was used to allow the Oracle Client libraries to support threaded applications. The parameter value is ignored in python-oracledb: threaded OCI is now always enabled in Thick, and the option is not relevant to Thin.

Connection object
=================

The differences between the Connection object in the python-oracledb driver and cx_Oracle driver are listed below:
    -   Deprecated attribute :attr:`Connection.maxBytesPerCharacter`. This will return a constant value of 4 since encodings are always UTF-8.
    -   New boolean attribute :attr:`Connection.thin`. This attribute is True if the connection was established with the thin driver. Otherwise it is False.

Oracledb.clientversion()
========================

The :func:`oracledb.clientversion()` shows the version of the Oracle Client libraries being used. This function can only be called in the Thick mode. It can be called only after oracledb.init_oracle_client() has been called. There is no Oracle client used by python-oracledb Thin. If oracledb.clientversion() is called when in Thin mode, that is if oracledb.init_oracle_client() was not called first, then an exception will be thrown.

Applications can reference oracledb.__version__ to determine the version of python-oracledb.

Cursor.fetchraw()
=================

:meth:`Cursor.fetchraw()` was previously deprecated in cx_Oracle 8.2 and has been removed in python-oracledb. Instead, use one of the other fetch methods such as :meth:`Cursor.fetchmany()`.

Cursor.executemanyprepared()
============================

:meth:`Cursor.executemanyprepared()` was previously deprecated in cx_Oracle 6.4 and has been removed in python-oracledb. Instead, use :meth:`Cursor.executemany()`, by passing None for the statement argument and an integer for the parameters argument.

Cursor.rowcount
===============

After execute() or executemany() with PL/SQL statements, :attr:`Cursor.rowcount` will return 0.

Advanced Queueing (AQ)
======================

The old Advanced Queuing (AQ) API is not available in python-oracledb. This was deprecated in cx_Oracle 7.2. Replace with the new Advanced Queuing (AQ) shown in the python-oracledb user documentation. Note AQ is only available in the Thick driver. Replace:

    - :meth:`Connection.deq()` with :meth:`Queue.deqone()` or :meth:`Queue.deqmany()`
    - :meth:`Connection.deqoptions()` with attribute :attr:`Queue.deqoptions`
    - :meth:`Connection.enq()` with :meth:`Queue.enqone()` or :meth:`Queue.enqmany()`
    - :meth:`Connection.deqoptions()` with attribute :attr:`Queue.deqoptions`

Pooling
=======

Using the new ConnectionPool Class is now recommended instead of the equivalent SessionPool. The SessionPool class and function 
Oracledb.SessionPool() are deprecated in python-oracledb.

Oracledb.ConnectionPool()
-------------------------

Oracledb.ConnectionPool() in python-oracledb differs from Oracledb.SessionPool() in cx_Oracle as follows:
    - Parameters are keyword, not positional. See :ref:`connmig`.
    - Passing a value to the dsn parameter that contains the user name and password is now supported in the same way as oracledb.connect(). For example dsn="un/pw@cs" can be used.
    - Parameters encoding and nencoding are deprecrated and ignored. The encodings in use are always UTF-8.
    - The default mode is POOL_GETMODE_WAIT instead of POOL_GETMODE_NOWAIT. If the mode POOL_GETMODE_NOWAIT is truly desired, modify any pool creation code to specify this value instead.
    - New optional parameter params. See the :ref:`ConnectParams Class section<connparam>`.
    - New keyword arguments that match the new ConnectParams Class ConnectParams() arguments. These will be used internally to create a ConnectParams Class object before creating the pool.
    - a Python type() will show the class as oracledb.ConnectionPool instead of cx_Oracle.SessionPool.

ConnectionPool Object
---------------------

The ConnectionPool Object in python-oracledb has a new boolean attribute :attr:`ConnectionPool.thin`. This attribute is True if the connection was established with the python-oracledb Thin driver. If the connection was established with the python-oracledb Thick driver, then this attribute is false.
