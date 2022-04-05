.. _compatibility:

***************************
cx_Oracle 8.3 Compatibility
***************************

The differences from cx_Oracle 8.3 to the python-oracledb drivers are listed here.

Oracle Client Library Loading
=============================

To use the python-oracledb in Thick mode, a call must be made to :func:`oracledb.init_oracle_client()` before any connection is established. This function immediately loads Oracle Client libraries. If this function is not called first, then python-oracledb Thin mode will be used.

Putting this call in application initialization code can mean that Oracle Client library loading is no longer deferred until the driver is first used, such as at the time the first connection is opened. This may be an issue for some multi-database vendor frameworks and ORMS that don't want to fail for non-Oracle users when python-oracledb is never going to be used. The obvious solution is to call :func:`oracledb.init_oracle_client()` just prior to the first point of use in python-oracledb. Since the function can only be called once per process, the application will need logic to avoid calling it multiple times.

Oracledb.connect()
==================

The :func:`oracledb.connect()` function in python-oracledb differs from cx_Oracle in the following ways:

    - Parameters are keyword, not positional. See :ref:`connmig`.
    - Parameters encoding and nencoding are deprecated and ignored. The encodings in use are always UTF-8.
    - New optional parameter params. See the :ref:`ConnectParams Class section <connparam>`.
    - New keyword arguments that match the new :ref:`ConnectParams Class <connparam>` ConnectParams() arguments. These will be used internally to create a ConnectParams Class object before creating the connection.
    - The parameter threaded is deprecated. This parameter was used to allow the Oracle Client libraries to support threaded applications. This parameter value is ignored in python-oracledb: threaded Oracle Call Interface (OCI) is now always enabled in Thick, and the option is not relevant to Thin.

Connection object
=================

The differences between the Connection object in the python-oracledb driver and cx_Oracle driver are listed below:
    -   The attribute :attr:`Connection.maxBytesPerCharacter` is deprecated. This will return a constant value of 4 since encodings are always UTF-8.
    -   Added a new boolean attribute, :attr:`Connection.thin`. This attribute is True if the connection was established in the Thin mode. In Thick mode, the value of this attribute is False.

Oracledb.clientversion()
========================

The :func:`oracledb.clientversion()` shows the version of the Oracle Client libraries being used. This function can only be called in the Thick mode. It can be called only after oracledb.init_oracle_client() has been called. There is no Oracle client used in the python-oracledb Thin mode. If oracledb.clientversion() is called when in Thin mode, that is if oracledb.init_oracle_client() was not called first, then an exception will be thrown.

Applications can reference oracledb.__version__ to determine the version of python-oracledb.

Cursor.fetchmany()
==================

The name of the size argument of :meth:`Cursor.fetchmany()` is ``size``. This change was done to comply with `PEP 249 <https://peps.python.org/pep-0249/>`_. The previous keyword argument name, ``numRows`` is deprecated.

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

The old Advanced Queuing (AQ) API is not available in python-oracledb. This was deprecated in cx_Oracle 7.2. Replace with the new Advanced Queuing (AQ) shown in the python-oracledb user documentation. Note AQ is only available in the Thick mode. Replace:

    - :meth:`Connection.deq()` with :meth:`Queue.deqone()` or :meth:`Queue.deqmany()`
    - :meth:`Connection.deqoptions()` with attribute :attr:`Queue.deqoptions`
    - :meth:`Connection.enq()` with :meth:`Queue.enqone()` or :meth:`Queue.enqmany()`
    - :meth:`Connection.deqoptions()` with attribute :attr:`Queue.deqoptions`

Pooling
=======

Using the new :ref:`ConnectionPool Class <connpool>` is now recommended instead of the equivalent SessionPool. The SessionPool class and function ``Oracledb.SessionPool()`` are deprecated in python-oracledb.

Oracledb.SessionPool()
-------------------------

Oracledb.ConnectionPool() in python-oracledb differs from Oracledb.SessionPool() in cx_Oracle as follows:
    - Parameters are keyword, not positional. See :ref:`connmig`.
    - Passing a value to the dsn parameter that contains the user name and password is now supported in the same way as :func:`oracledb.connect()`. For example ``dsn="un/pw@cs"`` can be used.
    - Parameters encoding and nencoding are deprecrated and ignored. The encodings in use are always UTF-8.
    - The default mode is :data:`~oracledb.POOL_GETMODE_WAIT` instead of :data:`~oracledb.POOL_GETMODE_NOWAIT`. If the mode :data:`~oracledb.POOL_GETMODE_NOWAIT` is truly desired, modify any pool creation code to specify this value instead.
    - New optional parameter ``params``. See the :ref:`ConnectParams Class section <connparam>`.
    - New keyword arguments that match the new :ref:`ConnectParams Class <connparam>` ``ConnectParams()`` arguments. These will be used internally to create a ConnectParams Class object before creating the pool.
    - A Python type() will show the class as ``oracledb.ConnectionPool`` instead of ``cx_Oracle.SessionPool``.

SessionPool Object
---------------------

The SessionPool object (an alias for ConnectionPool) in python-oracledb has a new boolean attribute :attr:`SessionPool.thin`. This attribute is True if the connections within it use the python-oracledb Thin mode. Otherwise, this attribute is false.
