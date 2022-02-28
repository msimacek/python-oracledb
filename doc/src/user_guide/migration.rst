.. _migration:

********************************************
Migrating from cx_Oracle to python-oracledb
********************************************

python-oracledb Thick has a few small changes in comparison to cx_Oracle and also has additional new features. python-oracledb Thin does not support all the features of python-oracledb Thick. Also, the python-oracledb Thin driver does not support all the features that the Oracle Client libraries provide to cx_Oracle and the python-oracledb Thick driver. See :ref:`appendixa` and :ref:`additionalfeatures`.

You can perform a migration from cx_Oracle to python-oracledb Thick or Thin. The steps for the migration process are detailed in the subsequent sections.

Code Migration Preparation
============================

Many of the preparatory code migration tasks can be done while still using the latest versions of cx_Oracle. To sum it up, you can:

1. Adjust calls to :func:`~oracledb.connect()` and :func:`~oracledb.ConnectionPool()`.
2. Review the ``ConnectionPool()`` parameter :attr:`ConnectionPool.getmode`.
3. Replace all usage of the deprecated Advanced Queuing (AQ) API with the API introduced in cx_Oracle 7.2.
4. Replace all uses of :meth:`Cursor.fetchraw()` with another fetch method such as :meth:`Cursor.fetchmany()`.
5. If you intend to use python-oracledb Thick, then add a single call to :func:`~oracledb.init_oracle_client`.

Starting with python-oracledb 1, :ref:`SessionPool()<sesspool>` is deprecated and replaced by :ref:`ConnectionPool()<connpool>`.

Common Code Migration Tasks
============================

When migrating from cx_Oracle to python-oracledb Thin or Thick, make the following code changes:

1. Import the the new interface module. This can be done in two ways. Change::

        import cx_Oracle
        
 to::

        import oracledb as cx_Oracle

 Alternatively, replace all references to the module cx_Oracle with oracledb. For example, change::

        import cx_Oracle
        c = cx_Oracle.connect(...)

 to::

        import oracledb
        c = oracledb.connect(...)

 Any new code being introduced during migration should aim to use the latter syntax.

2. Use named parameters in calls to :func:`~oracledb.connect()` and :func:`~oracledb.SessionPool()`:

 Replace positional parameters with keyword parameters unless only one parameter is being passed.
 python-oracledb uses keyword parameters exclusively unless a DSN containing the user, password, and 
 connect string combined ("un/pw@cs") is used. This change makes the driver compliant with the 
 Python Database API spec PEP 249.

 For example, the following code will fail::

        c = oracledb.connect("un", "pw", "cs")

 and needs to be changed to::

        c = oracledb.connect(user="un", password="pw", dsn="cs")

 The following example will continue to work without change::

        c = oracledb.connect("un/pw@cs")

3.  Review obsolete encoding parameters in calls to :func:`~oracledb.connect()` and :func:`~oracledb.SessionPool()`:

 Parameters ``encoding`` and ``nencoding`` are ignored by python-oracledb. The python-oracledb driver uses UTF-8 exclusively.

 The parameter ``threaded`` is ignored in :func:`~oracledb.connect()` by python-oracledb. In cx_Oracle 8.0, this parameter was ignored in :func:`~oracledb.SessionPool()`.

 In cx_Oracle 8.0, the default encodings were changed to UTF-8.

4.  Remove all references to :meth:`Cursor.fetchraw()` as this method was deprecated in cx_Oracle 8.2 and has 
    been removed in python-oracledb. Instead, use one of the other fetch methods such as :meth:`Cursor.fetchmany()`.

5.  The default ``SessionPool()`` parameter getmode value is now ``POOL_GETMODE_WAIT`` instead of ``POOL_GETMODE_NOWAIT``. 
    
    If the old default value is required, modify any pool creation code to explicitly specify ``getmode=POOL_GETMODE_NOWAIT``. 
    
    This new default value gives better behavior for most applications. It prevents transient errors from occurring when using the Thick driver with recent Oracle Client libraries if the pool is in the middle of growing. It also helps when using the Thin 
    driver, see below.

Additional Thin Code Migration Tasks
=====================================

When migrating from cx_Oracle to the python-oracledb Thin driver, review the available functionality to see if everything
required by your application is supported. If it is not supported, then use the python-oracledb Thick driver. See :ref:`appendixa`, :ref:`driverdiff`, and :ref:`compatibility`.

The following changes need to be made at a minimum:

 1. Remove calls to :func:`~oracledb.init_oracle_client` since this turns on the Thick mode.

 2. If the ``config_dir`` parameter of :func:`~oracledb.init_oracle_client` had been used, then set the new ``oracledb.defaults.config_dir`` attribute to the desired value.

 3. Remove calls to :func:`oracledb.clientversion()` which is only available in the python-oracledb Thick driver.

 4. Ensure that any assumptions about when connections are created in the pool are eliminated. The python-oracledb Thin driver creates connections in a daemon thread and so the attribute :attr:`ConnectionPool.opened` will change over time and will not be equal to :attr:`ConnectionPool.min` immediately after the pool is created. Unless the :func:`oracledb.SessionPool()` parameter getmode is the new default ``POOL_GETMODE_WAIT``, then applications should not call :meth:`ConnectionPool.aquire()`` until sufficient time has passed for connections in the pool to be opened.

 5. If the application is connecting using a net service alias and Python cx_Oracle is looking up that alias in a ``tnsnames.ora`` file from a default location such as from the Instant Client ``network/admin/`` subdirectory, from ``$ORACLE_HOME/network/admin/``, or from ``$ORACLE_BASE/homes/XYZ/network/admin/`` (in a read-only Oracle Database home), then the Oracle Confidential directory containing the file must now explicitly be set as shown in SQL*Net and Client configuration files.

 6. Review error handling. See :ref:`errorhandling`.

 7. Review locale and globalization usage. See :ref:`globalization`.

Additional Thick Code Migration Tasks
======================================

When migrating from cx_Oracle to the python-oracledb Thick driver, review the Feature Matrix and cx_Oracle 8.3
Compatibility sections. If your code base uses an older cx_Oracle version, review the previous `cx\_Oracle release
notes <https://cx-oracle.readthedocs.io/en/latest/release_notes.html>`_ for additional changes to modernize the code.

The following changes need to be made at a minimum:

1. Call :func:`~oracledb.init_oracle_client()` anywhere before the first call to :func:`~oracledb.connect()` and :func:`~oracledb.SessionPool()`.

 ``init_oracle_client()`` must be called at most once per process. Requiring ``init_oracle_client()`` means that the Oracle Client library loading is not automatically deferred until the driver is first used, such as when a connection is opened. The application must explicitly manage this, if deferral is required.
 
 .. note::

   • On Linux and related operating systems, the ``lib_dir`` parameter should not be passed. Instead, set the system library search path with ``ldconfig`` or ``LD_LIBRARY_PATH`` prior to running Python.
 

2. Replace all usage of the deprecated AQ API with the new API originally introduced in cx_Oracle 7.2, see the cx_Oracle 'Advanced Queuing (AQ) <https://cx-oracle.readthedocs.io/en/latest/api_manual/aq.html>'_ documentation:

       • create a queue with a call to :meth:`Connection.queue()`
       • replace calls to :meth:`Connection.enq()` with a call to :meth:`Queue.enqone()` or :meth:`Queue.enqmany()`
       • replace calls to :meth:`Connection.deq()` with a call to :meth:`Queue.deqone()` or :meth:`Queue.deqmany()`
       • replace calls to :meth:`Connection.enqoptions()` with a reference to :attr:`Queue.enqoptions`
       • replace calls to :meth:`Connection.deqoptions()` with a reference to :attr:`Queue.deqoptions`

3. Review error handling. See :ref:`errorhandling`.

Migration Tips
===============

Testing Which Driver is in Use
-------------------------------

Code that needs to know whether the driver is cx_Oracle or python-oracledb can use code similar to:

.. code-block:: python

       import oracledb as cx_Oracle

       if cx_Oracle.__name__ == 'cx_Oracle':
              print('cx_Oracle')
       else:
              print('oracledb')

Migrating to the Thick Driver Without Changing Connect Calls
------------------------------------------------------------

The following shim can be added to your code in order to facilitate migration to the new Thick driver without
needing to change calls to ``connect()``.

.. code-block:: python

       import oracledb

       class ShimConnection(oracledb.Connection):

              def __init__(self, user=None, password=None, dsn=None,
                     mode=oracledb.DEFAULT_AUTH, handle=0, pool=None,
                     threaded=False, events=False, cclass=None,
                     purity=oracledb.ATTR_PURITY_DEFAULT,
                     newpassword=None, encoding=None, nencoding=None,
                     edition=None, appcontext=[], tag=None,
                     matchanytag=None, shardingkey=[],
                     supershardingkey=[], stmtcachesize=20):
              if dsn is None and password is None:
                     dsn = user
                     user = None
              super().__init__(dsn=dsn, user=user, password=password,
                     mode=mode, handle=handle, pool=pool,
                     threaded=threaded, events=events, cclass=cclass,
                     purity=purity, newpassword=newpassword,
                     edition=edition, appcontext=appcontext, tag=tag,
                     matchanytag=matchanytag, shardingkey=shardingkey,
                     supershardingkey=supershardingkey,
                     stmtcachesize=stmtcachesize)
       oracledb.connect = ShimConnection

Testing with SQLAlchemy and Django
-----------------------------------

Until SQLAlchemy and Django add native support for python-oracledb, bootstrap code similar to the following can be used for testing:

.. code-block:: python

       import sys
       import oracledb

       oracledb.version = "8.3.0"
       sys.modules["cx_Oracle"] = oracledb
