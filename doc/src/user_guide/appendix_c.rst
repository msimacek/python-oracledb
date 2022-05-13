.. _compatibility:

*****************************************************************************
Appendix C: Differences between the cx_Oracle 8.3 and python-oracledb Drivers
*****************************************************************************

The python-oracledb driver is the renamed, major version successor to
`cx_Oracle 8.3 <https://oracle.github.io/python-cx_Oracle/>`__. As a major
release, the python-oracledb driver has new features and some changes.

By default, python-oracledb runs in a 'Thin' mode which connects directly to
Oracle Database.  This mode does not need Oracle Client libraries.  However,
some :ref:`additional functionality <featuresummary>` is available when
python-oracledb uses them.  Python-oracledb connections are said to be in
'Thick' mode when Oracle Client libraries are used.  See :ref:`enablingthick`.
Both modes have comprehensive functionality supporting the Python Database API
v2.0 Specification.

The differences between cx_Oracle 8.3 and the python-oracledb drivers are
listed here.  Also, see :ref:`deprecations` and :ref:`Upgrading from cx_Oracle
to python-oracledb <upgrading>`.

Oracle Client Library Loading differences from cx_Oracle
========================================================

Oracle Client libraries are now only loaded if
:func:`oracledb.init_oracle_client()` is called in your application.  This
changes python-oracledb to Thick mode. The ``init_oracle_client()`` method must
be called before any :ref:`standalone connection <standaloneconnection>` or
:ref:`connection pool <connpooling>` is created. If a connection or pool is
created first in the default Thin mode, then Thick mode cannot be enabled.

See :ref:`enablingthick` for more information.

Calling the ``init_oracle_client()`` method immediately loads Oracle Client
libraries.  To emulate the the cx_Oracle behavior of deferring library loading
until the creation of the first connection (in the case when
``init_oracle_client()`` is not called), your application will need to defer
calling ``init_oracle_client()`` as appropriate.

In python-oracledb, ``init_oracle_client()`` can now be called multiple times
in the one Python process as long as its arguments are the same in each time.

oracledb.clientversion()
------------------------

The :func:`oracledb.clientversion()` method shows the version of the Oracle
Client libraries being used.  There is no Oracle Client used in the
python-oracledb Thin mode so this function can only be called in
python-oracledb Thick mode.  If this function is called before
:func:`oracledb.init_oracle_client()`, an exception is thrown.

Connection differences from cx_Oracle
=====================================

oracledb.connect() differences
------------------------------

The :func:`oracledb.connect()` function in the python-oracledb driver differs
from cx_Oracle:

- Keyword parameters must be used in calls to :func:`oracledb.connect()`. This
  change makes the driver compliant with the Python Database API specification
  PEP 249.  See :ref:`Standalone Connections <standaloneconnection>` and
  :ref:`connerrors`.

- New keyword arguments can be passed to :func:`~oracledb.connect()`.  For
  example you can pass the hostname, port and servicename as separate
  parameters instead of using an Easy Connect connection string.  In
  python-oracledb Thin mode, some of the new arguments replace ``sqlnet.ora``
  settings.

- A new optional parameter ``params`` of type :ref:`ConnectParams <connparam>`
  can be used to encapsulate connection properties. See :ref:`usingconnparams`
  for more information.

- The following parameters are deprecated and ignored:

  - ``encoding`` and ``decoding``: The encodings in use are always UTF-8.

  - ``threaded``: Threaded Oracle Call Interface (OCI) is now always enabled in
    Thick mode.  This option is not relevant to the Thin mode.

  See :ref:`deprecations` for more information.

The use of the class constructor method ``oracledb.Connection()`` to create
connections is no longer recommended for creating connections.  Use
:func:`~oracledb.connect()` instead.

Connection Object Differences
-----------------------------

The :ref:`Connection object <connobj>` differences between the python-oracledb
and cx_Oracle drivers are:

- The attribute :attr:`Connection.maxBytesPerCharacter` is deprecated. This will
  return a constant value of 4 since encodings are always UTF-8.

- A new boolean attribute, :attr:`Connection.thin` is is available. This
  attribute is True if the connection was established in the Thin mode. In
  Thick mode, the value of this attribute is False.

See :ref:`connattrs` for more information.

Pooling differences from cx_Oracle
==================================

It is recommended to use the new equivalent :ref:`ConnectionPool Object
<connpool>` instead of the SessionPool object, which is deprecated.  To create
a connection pool, use :meth:`oracledb.create_pool()`, which is equivalent to
calling `cx_Oracle.SessionPool
<https://cx-oracle.readthedocs.io/en/latest/api_manual/module.html#cx_Oracle.SessionPool>`__.

For more information see :ref:`connpooling`.

oracledb.SessionPool() differences
----------------------------------

The python-oracledb ``oracledb.SessionPool()`` method (which is an alias of
:func:`oracledb.create_pool()`) differs from `cx_Oracle.SessionPool()
<https://cx-oracle.readthedocs.io/en/latest/api_manual/module.html#cx_Oracle.SessionPool>`_
as follows:

- Keyword parameters must be used in calls. This change makes the driver
  compliant with the Python Database API specification PEP 249.  See
  :ref:`Connection pooling <connpooling>` and :ref:`connerrors`.

- Passing a value to the ``dsn`` parameter that contains the user name and
  password is now supported in the same way as :func:`oracledb.connect()`. For
  example ``dsn="un/pw@cs"`` can be used.

- The default mode is :data:`~oracledb.POOL_GETMODE_WAIT` instead of
  :data:`~oracledb.POOL_GETMODE_NOWAIT`. If the mode
  :data:`~oracledb.POOL_GETMODE_NOWAIT` is truly desired, modify any pool
  creation code to specify this value instead.  Note the namespace of constant
  has been improved.  Old names like ``SPOOL_ATTRVAL_NOWAIT`` can be used but are
  now deprecated.

- A new optional parameter ``params`` of type :ref:`PoolParams <poolparam>`
  can be used to encapsulate connection properties. See :ref:`usingconnparams`
  for more information.

- The following parameters are deprecated and ignored:

  - ``encoding`` and ``decoding``: The encodings in use are always UTF-8.

- New keyword arguments that are used internally to create a :ref:`PoolParams
  object <connparam>` before creating the connection.

SessionPool Object Differences
------------------------------

The SessionPool object (which is an alias for the :ref:`ConnectionPool object
<connpool>`) differences between the python-oracledb and cx_Oracle drivers are:

- A Python type() will show the class as ``oracledb.ConnectionPool`` instead of
  ``cx_Oracle.SessionPool``.

- A new boolean attribute, ``SessionPool.thin`` (see
  :attr:`ConnectionPool.thin`) is available. This attribute is True if the
  connection was established in the Thin mode. In Thick mode, the value of this
  attribute is False.

Cursor Object differences from cx_Oracle
========================================

The differences between the :ref:`Cursor object <cursorobj>` in python-oracledb and
cx_Oracle drivers are:

- :meth:`Cursor.fetchmany()`: The name of the size argument of ``fetchmany()``
  is ``size``. This change was done to comply with `PEP 249
  <https://peps.python.org/pep- 0249/>`_. The previous keyword argument name,
  ``numRows`` is deprecated.

- ``Cursor.fetchraw()``: This method was previously deprecated in cx_Oracle 8.2 and has
  been removed in python-oracledb. Instead, use one of the other fetch methods such as
  :meth:`Cursor.fetchmany()`.

- ``Cursor.executemanyprepared()``: This method was previously deprecated in cx_Oracle 6.4
  and has been removed in python-oracledb. Instead, use :meth:`Cursor.executemany()`,
  by passing None for the statement argument and an integer for the parameters argument.

- ``Cursor.bindarraysize``: This attribute is deprecated and removed in python-oracledb. It is
  not needed in the application code.

- :attr:`Cursor.rowcount`: After :meth:`Cursor.execute()` or
  :meth:`Cursor.executemany()` with PL/SQL statements, ``Cursor.rowcount`` will
  return 0. If the cursor or connection are not open, then the value -1 will be
  returned as required by the Python Database API.

Advanced Queuing (AQ) differences from cx_Oracle
================================================

The old Advanced Queuing (AQ) API is not available in python-oracledb since it was
deprecated in cx_Oracle 7.2. Use the :ref:`new Advanced Queuing (AQ) <aqusermanual>`.
Note that AQ is only available in the Thick mode.

Replace:

- :meth:`Connection.deq()` with :meth:`Queue.deqone()` or :meth:`Queue.deqmany()`
- :meth:`Connection.deqoptions()` with attribute :attr:`Queue.deqoptions`
- :meth:`Connection.enq()` with :meth:`Queue.enqone()` or :meth:`Queue.enqmany()`
- :meth:`Connection.deqoptions()` with attribute :attr:`Queue.deqoptions`
