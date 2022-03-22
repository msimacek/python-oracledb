.. _migration:

********************************************
Migrating from cx_Oracle to python-oracledb
********************************************

The python-oracledb driver enables access to Oracle Database using either one of the two modes: Thin or Thick.

The python-oracledb Thin mode connects directly to the Oracle database. This mode does not support all the features of the Thick mode. The Thin mode does not require Oracle Client libraries and hence does not support some of the advanced Oracle Database technologies which are listed below. The python-oracledb Thick mode dynamically loads ODPI-C and Oracle Client libraries to connect to Oracle Database using the Oracle Call Interface (OCI) API. In comparison to cx_Oracle, python-oracledb Thick mode has a few changes and additional features. The Thick mode requires Oracle Client libraries and hence supports the advanced Oracle Database technologies that rely on the functionality provided by Oracle Client libraries. These technologies are:

 - Continuous Availability features including Application Continuity, Transparent Application Continuity, and Transparent Application Failover (TAF)
 - Advanced Queuing
 - Database Change Notification (DCN)
 - Simple Oracle Document Access (SODA)

If the above-mentioned features are important to your application, then use the Thick mode. For detailed information on the differences between the two modes, see :ref:`driverdiff`. For the feature differences between cx_Oracle and python-oracledb, see :ref:`Features <appendixa>` and :ref:`additionalfeatures`.

The tasks to be performed for the migration from cx_Oracle to python-oracledb are detailed in the subsequent sections.

Things to Know Before Migrating
===============================

Below is a list of things you must know before migrating from cx_Oracle to python-oracledb:

 - If you only want to use python-oracledb driver in the Thin mode, then you do not need to install Oracle Instant Client.
 - The Thin and Thick mode have the same level of support for the Python Database API and can be used to connect to on-premise databases and Oracle Cloud databases. However, the Thin mode does not support some of the advanced Oracle Database features such as Application Continuity (AC), Advanced Queueing (AQ), Continuous Query Notification (CQN), and Sharding.
 - python-oracledb can be used in SQLAlchemy, Django, Pandas, and other frameworks and Object-relational Mappers (ORMs). Until they add native support, you need to override the use of cx_Oraclea with a few lines of code. See :ref:`alchemyanddjango`.
 - python-oracledb connection calls require keyword arguments such as::

        oracledb.connect(user="scott", password=pw, dsn="localhost/orclpdb1")

 - The Thin mode ignores all NLS environment variables.
 - To use a tnsnames.ora file from a previous default location such ``$ORACLE_HOME/network/admin/`` in Thin mode, you will need to set ``oracledb.defaults.config_dir`` to the directory containing the file.
 - To use Thin mode in an ORACLE_HOME database installation environment, you will need to connect using an explicit connection string since ``ORACLE_SID`` is not used in Thin mode.

Once you have migrated to python-oracledb, you can also change from Thick mode to Thin mode and vice-versa. See :ref:`changingmodes` to understand the steps that need to be performed.

Code Migration Preparation
============================

Many of the preparatory code migration tasks can be done while still using the latest versions of cx_Oracle. To sum it up, you can:

1. Adjust calls to :func:`~oracledb.connect()`, :func:`oracledb.Connection()`, and :func:`~oracledb.SessionPool()`.
2. Review the ``SessionPool()`` value of parameter :attr:`SessionPool.getmode`.
3. Replace all usage of the deprecated Advanced Queuing (AQ) API with the API introduced in cx_Oracle 7.2.
4. Replace all uses of :meth:`Cursor.fetchraw()` with another fetch method such as :meth:`Cursor.fetchmany()`.
5. If you intend to use python-oracledb in Thick mode, then add a single call to :func:`~oracledb.init_oracle_client`.

Common Migration Tasks
=======================

To migrate from cx_Oracle to python-oracledb, perform the following steps:

1. Install the new python-oracledb module::      

              python -m pip install oracledb

2. Import the the new interface module. This can be done in two ways. You can change::

        import cx_Oracle
        
 to::

        import oracledb as cx_Oracle

 Alternatively, you can replace all references to the module cx_Oracle with oracledb. For example, change::

        import cx_Oracle
        c = cx_Oracle.connect(...)

 to::

        import oracledb
        c = oracledb.connect(...)

 Any new code being introduced during migration should aim to use the latter syntax.

3. Use named parameters in calls to :func:`~oracledb.connect()`, :func:`oracledb.Connection()`, and :func:`~oracledb.SessionPool()`.

 You must replace positional parameters with keyword parameters, unless only one parameter is being passed.
 python-oracledb uses keyword parameters exclusively unless a DSN containing the user, password, and 
 connect string combined (``un/pw@cs``) is used. This change makes the driver compliant with the 
 Python Database API spec PEP 249.

 For example, the following code will fail::

        c = oracledb.connect("un", "pw", "cs")

 and needs to be changed to::

        c = oracledb.connect(user="un", password="pw", dsn="cs")

 The following example will continue to work without change::

        c = oracledb.connect("un/pw@cs")

4.  Review obsolete encoding parameters in calls to :func:`~oracledb.connect()`, :func:`oracledb.Connection()`, and :func:`~oracledb.SessionPool()`:

 The parameters ``encoding`` and ``nencoding`` are ignored by python-oracledb. The python-oracledb driver uses UTF-8 exclusively.

 The parameter ``threaded`` is ignored in :func:`~oracledb.connect()` and :func:`oracledb.Connection()` by python-oracledb. In cx_Oracle 8.0, this parameter was ignored in :func:`~oracledb.SessionPool()`.

 In cx_Oracle 8.0, the default encodings were changed to UTF-8.

5.  Remove all references to :meth:`Cursor.fetchraw()` as this method was deprecated in cx_Oracle 8.2 and has 
    been removed in python-oracledb. Instead, use one of the other fetch methods such as :meth:`Cursor.fetchmany()`.

6.  The default value of the ``SessionPool()`` parameter :attr:`Connection.getmode` is now ``SPOOL_ATTRVAL_WAIT`` instead of ``SPOOL_ATTRVAL_NOWAIT``. 
    
    If the old default value is required, modify any pool creation code to explicitly specify ``getmode=oracledb.POOL_SPOOL_ATTRVAL_NOWAIT`` or the new equivalent value ``oracledb.POOL_GETMODE_NOWAIT``. 
    
    The new default value improves the behavior for most applications. It prevents transient errors from occurring when using the Thick mode with recent Oracle Client libraries, if the pool is in the middle of growing. It also helps when using the Thin 
    mode, see the subsequent sections.

Thin Mode Migration Tasks
==========================

When migrating from cx_Oracle to the python-oracledb Thin mode, you must review the :ref:`Features <appendixa>`, :ref:`driverdiff`, and :ref:`compatibility` to ensure that the requirements of your application are supported. If your application requirements are not supported, then use the python-oracledb Thick mode.

The following changes need to be made at a minimum:

 1. Remove calls to :func:`~oracledb.init_oracle_client` since this turns on the Thick mode.

 2. If the ``config_dir`` parameter of :func:`~oracledb.init_oracle_client` had been used, then set the new ``oracledb.defaults.config_dir`` attribute to the desired value.

 3. Remove calls to :func:`oracledb.clientversion()` which is only available in the python-oracledb Thick mode. Applications can reference ``oracledb.__version__`` to determine the version of python-oracledb.

 4. Ensure that any assumptions about when connections are created in the pool are eliminated. The python-oracledb Thin mode creates connections in a daemon thread and so the attribute :attr:`ConnectionPool.opened` will change over time and will not be equal to :attr:`ConnectionPool.min` immediately after the pool is created. Unless the :func:`oracledb.SessionPool()` parameter getmode is the new default ``POOL_GETMODE_WAIT``, then applications should not call :meth:`ConnectionPool.acquire()` until sufficient time has passed for connections in the pool to be opened.

 5. If the application is connecting using a net service alias and Python cx_Oracle is looking up that alias in a ``tnsnames.ora`` file from a default location such as from the Instant Client ``network/admin/`` subdirectory, from ``$ORACLE_HOME/network/admin/``, or from ``$ORACLE_BASE/homes/XYZ/network/admin/`` (in a read-only Oracle Database home), then the Oracle Configuration directory containing the file must now explicitly be set as shown in :ref:`sqlnetclientconfig`.

 6. Review error handling. See :ref:`errorhandling`.

 7. Review locale and globalization usage. See :ref:`globalization`.

Thick Mode Migration Tasks
===========================

When migrating from cx_Oracle to the python-oracledb Thick mode, review the :ref:`Features <appendixa>` and :ref:`compatibility` sections. If your code base uses an older cx_Oracle version, review the previous `cx\_Oracle release
notes <https://cx-oracle.readthedocs.io/en/latest/release_notes.html>`_ for additional changes to modernize the code.

The following changes need to be made at a minimum:

1. Call :func:`~oracledb.init_oracle_client()` anywhere before the first call to :func:`~oracledb.connect()`, :func:`oracledb.Connection()`, and :func:`~oracledb.SessionPool()`.

 ``init_oracle_client()`` must be called atleast once per process. Requiring ``init_oracle_client()`` means that the Oracle Client library loading is not automatically deferred until the driver is first used, such as when a connection is opened. The application must explicitly manage this, if deferral is required.
 
 .. note::

        On Linux and related operating systems, the ``lib_dir`` parameter should not be passed. Instead, set the system library search path with ``ldconfig`` or ``LD_LIBRARY_PATH`` prior to running Python.
 

2. Replace all usage of the deprecated AQ API with the new API originally introduced in cx_Oracle 7.2, see the `cx_Oracle Advanced Queuing (AQ) <https://cx-oracle.readthedocs.io/en/latest/api_manual/aq.html>`_ documentation:

       - create a queue with a call to :meth:`Connection.queue()`
       - replace calls to :meth:`Connection.enq()` with a call to :meth:`Queue.enqone()` or :meth:`Queue.enqmany()`
       - replace calls to :meth:`Connection.deq()` with a call to :meth:`Queue.deqone()` or :meth:`Queue.deqmany()`
       - replace calls to :meth:`Connection.enqoptions()` with a reference to :attr:`Queue.enqoptions`
       - replace calls to :meth:`Connection.deqoptions()` with a reference to :attr:`Queue.deqoptions`

3. Review error handling. See :ref:`errorhandling`.

Migration Tips
===============

Runtime Toggling between Drivers 
--------------------------------

If your code is fully portable between cx_Oracle and python-oracledb, you can use one of the following code snippets to minimize the code changes required.

.. code-block:: python

       import sys
       import oracledb
       oracledb.version = "8.3.0"
       sys.modules["cx_Oracle"] = oracledb
       import cx_Oracle

.. note::

       The import of cx_Oracle occurs last.

Alternatively, to allow toggling between drivers, use the following code:

.. code-block:: python

       import os
       import platform
       import sys
       driver_type = os.environ.get("DRIVER_TYPE", "thin")
       if driver_type != "cx":
              import oracledb
              oracledb.version = "8.3.0"
              sys.modules["cx_Oracle"] = oracledb

       # This import must appear after 'sys.modules["cx_Oracle"] = oracledb'
       import cx_Oracle

       if (driver_type == "thick" or driver_type == "cx"):
              # Calling init_oracle_client(), with or without the lib_dir parameter, is
              # required for Thick, but cx_Oracle can use the system library search path
              # or appropriate file system library link on macOS.
              if platform.system() == "Darwin": # macOS
                     cx_Oracle.init_oracle_client(lib_dir=os.environ.get("HOME")+"/Downloads/instantclient_19_8")
              elif platform.system() == "Windows":
                     cx_Oracle.init_oracle_client(lib_dir=r"C:\oracle\instantclient_19_14")
              else:
                     cx_Oracle.init_oracle_client()
       if driver_type == "cx":
              print("Using cx_Oracle")
       elif driver_type == "thick":
              print("Using python-oracledb thick")
       else:
              print("Using python-oracledb thin")

Before running the application, set the environment variable ``DRIVER_TYPE`` to ``cx``, ``thick``, or ``thin``. If you do not set the environment variable, the python-oracledb Thin mode is used.

.. _alchemyanddjango:

SQLAlchemy and Django
----------------------

Until SQLAlchemy, Django, or other third-party frameworks and Object-relational Mappers (ORMs) add native support for python-oracledb, you can use one of the solutions detailed in the Runtime Toggling Between Drivers section.

Testing Which Driver is in Use
-------------------------------

To know whether the driver is cx_Oracle or python-oracledb, you can use code similar to:

.. code-block:: python

       import oracledb as cx_Oracle
       # or:
       # import cx_Oracle

       if cx_Oracle.__name__ == 'cx_Oracle':
              print('cx_Oracle')
       else:
              print('oracledb')

Another method that can be used to check which driver is in use is to query the ``CLIENT_DRIVER`` column of ``V$SESSION_CONNECT_INFO``. See :ref:`dbviews`. This method has the overhead of a round-trip to the database.

Migrating to the Thick Driver Without Changing Connect Calls
------------------------------------------------------------

If your connection calls do not use keyword arguments, then the following shim can be added to your code in order to facilitate migration to the Thick mode without needing to change calls to :func:`~oracledb.connect()` or :func:`~oracledb.SessionPool()`.

.. code-block:: python

       import oracledb as cx_Oracle

       class ShimConnection(oracledb.Connection):

              def __init__(self, user=None, password=None, dsn=None,
                     mode=cx_Oracle.DEFAULT_AUTH, handle=0, pool=None,
                     threaded=False, events=False, cclass=None,
                     purity=cx_Oracle.ATTR_PURITY_DEFAULT,
                     newpassword=None, encoding=None, nencoding=None,
                     edition=None, appcontext=[], tag=None,
                     matchanytag=False, shardingkey=[],
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
       cx_Oracle.connect = ShimConnection
       cx_Oracle.Connection = ShimConnection
       # With the shim, connecting doesn't need named arguments
       connection = cx_Oracle.connect(username, password, connect_string)
       # or
       connection = cx_Oracle.Connection(username, password, connect_string)

For SessionPool(), a similar shim can be used:

.. code-block:: python

       class ShimPool(cx_Oracle.SessionPool):
              def __init__(self, user=None, password=None, dsn=None, min=1, max=2,
                           increment=1, connectiontype=cx_Oracle.Connection,
                           threaded=True, getmode=cx_Oracle.SPOOL_ATTRVAL_NOWAIT,
                           events=False, homogeneous=True, externalauth=False,
                           encoding=None, nencoding=None, edition=None, timeout=0,
                           wait_timeout=0, max_lifetime_session=0, session_callback=None,
                           max_sessions_per_shard=0, soda_metadata_cache=False,
                           stmtcachesize=20, ping_interval=60):

                 super().__init__(dsn=dsn, user=user, password=password,
                                  min=min, max=max, increment=increment,
                                  connectiontype=connectiontype, threaded=threaded,
                                  getmode=getmode, events=events, homogeneous=homogeneous,
                                  externalauth=externalauth, encoding=encoding,
                                  nencoding=nencoding, edition=edition, timeout=timeout,
                                  wait_timeout=wait_timeout,
                                  max_lifetime_session=max_lifetime_session,
                                  session_callback=session_callback,
                                  max_sessions_per_shard=max_sessions_per_shard,
                                  soda_metadata_cache=soda_metadata_cache,
                                  stmtcachesize=stmtcachesize, ping_interval=ping_interval)

       cx_Oracle.SessionPool = ShimPool
       
       # With the shim, creating a pool doesn't need named arguments
       pool = cx_Oracle.SessionPool(username, password, connect_string, min=1, max=1, increment=0)