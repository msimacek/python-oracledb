.. _upgrading:

*******************************************************
Appendix D: Upgrading from cx_Oracle to python-oracledb
*******************************************************

The python-oracledb driver is the renamed, major version successor to
`cx_Oracle 8.3 <https://oracle.github.io/python-cx_Oracle/>`__.

By default, the driver now runs in a 'Thin' mode which connects directly to
Oracle Database.  This mode does not need Oracle Client libraries.  However,
some :ref:`additional functionality <featuresummary>` is available when
python-oracledb uses them.  The python-oracledb connections are said to be in
'Thick' mode when Oracle Client libraries are used.  See :ref:`enablingthick`.
Both modes have comprehensive functionality supporting the Python Database API
v2.0 Specification.

Things to Know Before Upgrading from cx_Oracle
==============================================

Below is a list of the important things to know before upgrading from cx_Oracle
to python-oracledb:

- If you only want to use the python-oracledb driver in Thin mode, then you do
  not need Oracle Client libraries such as from Oracle Instant Client.  You
  only need to install the driver itself::

      python -m pip install oracledb

- The python-oracledb Thin and Thick modes have the same level of support for
  the `Python Database API specification <https://peps.python.org/pep-0249/>`_
  and can be used to connect to on-premises databases and Oracle Cloud
  databases. However, the python-oracledb Thin mode does not support some of
  the advanced Oracle Database features such as Application Continuity (AC),
  Advanced Queuing (AQ), Continuous Query Notification (CQN), and Sharding.
  See :ref:`Features Supported <featuresummary>` for details.

- python-oracledb can be used in SQLAlchemy, Django, Pandas, and other frameworks
  and Object-relational Mappers (ORMs). Until they add native support, you need to
  override the use of cx_Oracle with a few lines of code. See :ref:`frameworks`.

- python-oracledb connection and pool creation calls require keyword arguments
  to conform with the Python Database API specification.  For example you must
  use:

  .. code-block:: python

       oracledb.connect(user="scott", password=pw, dsn="localhost/orclpdb1")

  This no longer works:

  .. code-block:: python

       oracledb.connect("scott", pw, "localhost/orclpdb1")

- The python-oracledb Thin mode ignores all NLS environment variables.  It also
  ignores ORA_SDTZ and ORA_TZFILE environment variables.  Thick mode does use
  these variables.  See :ref:`globalization` for alternatives.

- To use a ``tnsnames.ora`` file in the python-oracledb Thin mode, you must
  explicitly set :attr:`defaults.config_dir` to the directory containing the
  file, or set the ``config_dir`` parameter when connecting.

  A file in a "default" location such as from the Instant Client
  ``network/admin/`` subdirectory, from ``$ORACLE_HOME/network/admin/``, or
  from ``$ORACLE_BASE/homes/XYZ/network/admin/`` (in a read-only Oracle
  Database home) is not automatically loaded in Thin mode.  Default locations
  are automatically searched by Thick mode.

- To use the python-oracledb Thin mode in an ORACLE_HOME database installation
  environment, you use an explicit connection string since the ``ORACLE_SID``,
  ``TWO_TASK`` and ``LOCAL`` environment variables are not used.  They are used
  in Thick mode.

- This is a major release so some previously deprecated features are no longer
  available, see :ref:`deprecations`.

.. _commonupgrade:

Common Upgrade Tasks
====================

If you are creating new applications, follow :ref:`installation` and refer to
other sections of the documentation for usage information.

To upgrade existing code from cx_Oracle to python-oracledb, perform the
following steps:

1. Install the new python-oracledb module::

        python -m pip install oracledb

   See :ref:`installation` for more details.

2. Import the new interface module. This can be done in two ways. You can change:

   .. code-block:: python

        import cx_Oracle

   to:

   .. code-block:: python

        import oracledb as cx_Oracle

   Alternatively, you can replace all references to the module cx_Oracle with oracledb.
   For example, change:

   .. code-block:: python

        import cx_Oracle
        c = cx_Oracle.connect(...)

   to:

   .. code-block:: python

        import oracledb
        c = oracledb.connect(...)

   Any new code being introduced during the upgrade should aim to use the
   latter syntax.

3. Use keyword parameters in calls to :func:`oracledb.connect()`,
   ``oracledb.Connection()``, and ``oracledb.SessionPool()``.

   You must replace positional parameters with keyword parameters, unless only
   one parameter is being passed. Python-oracledb uses keyword parameters
   exclusively unless a DSN containing the user, password, and connect string
   combined (``un/pw@cs``) is used. This change makes the driver compliant with
   the Python Database API specification `PEP 249
   <https://peps.python.org/pep-0249/>`_.

   For example, the following code will fail:

   .. code-block:: python

       c = oracledb.connect("un", "pw", "cs")

   and needs to be changed to:

   .. code-block:: python

       c = oracledb.connect(user="un", password="pw", dsn="cs")

   The following example will continue to work without change:

   .. code-block:: python

       c = oracledb.connect("un/pw@cs")

4. Review obsolete encoding parameters in calls to :func:`oracledb.connect()`,
   ``oracledb.Connection()``, and ``oracledb.SessionPool()``:

   The parameters encoding and nencoding are ignored by python-oracledb. The
   python-oracledb driver uses UTF-8 exclusively.

   The parameter threaded is ignored in :func:`oracledb.connect()` and
   ``oracledb.Connection()`` by python-oracledb. This parameter was already
   ignored in ``oracledb.SessionPool()`` from cx_Oracle 8.2.

   In cx_Oracle 8.0, the default encodings were changed to UTF-8.

5. Remove all references to :meth:`Cursor.fetchraw()` as this method was
   deprecated in cx_Oracle 8.2 and has been removed in python-oracledb.
   Instead, use one of the other fetch methods such as
   :meth:`Cursor.fetchmany()`.

6. The default value of the ``oracledb.SessionPool()`` parameter
   :attr:`~Connection.getmode` now waits for an available connection, that is it
   is now :data:`~oracledb.SPOOL_ATTRVAL_WAIT` instead of
   :data:`~oracledb.SPOOL_ATTRVAL_NOWAIT`.  The new default value improves the
   behavior for most applications.  If the pool is in the middle of growing, the
   new value prevents transient connection creation errors from occurring when
   using the Thick mode with recent Oracle Client libraries.

   If the old default value is required, modify any pool creation code to
   explicitly specify ``getmode=oracledb.POOL_SPOOL_ATTRVAL_NOWAIT`` or
   preferably the new equivalent constant
   :data:`~oracledb.POOL_GETMODE_NOWAIT`.

7. When upgrading from cx_Oracle 8.3 to the python-oracledb, review the
   following sections to see if your application requirements are satisfied by
   the python-oracledb Thin mode:

   - :ref:`featuresummary`
   - :ref:`driverdiff`

   If your application requirements are not supported by the Thin mode, then
   use the python-oracledb Thick mode.

8. Review :ref:`compatibility`.

   If your code base uses an older cx_Oracle version, review the previous
   :ref:`releasenotes`.  for additional changes to modernize the code.

9. Consider modernizing code.  See :ref:`deprecations` for the list of
   deprecations in the python-oracledb release 1.0.

Additional Upgrade Tasks for python-oracledb Thin Mode
======================================================

The following changes need to be made in addition to the :ref:`commonupgrade`:

1. Remove calls to :func:`~oracledb.init_oracle_client` since this turns on the
   python-oracledb Thick mode.

2. If the ``config_dir`` parameter of :func:`~oracledb.init_oracle_client` had
   been used, then set the new :attr:`defaults.config_dir` attribute to the
   desired value or set the ``config_dir`` parameter when connecting.  For
   example:

   .. code-block:: python

       oracledb.defaults.config_dir = "/opt/oracle/config"

   Also see :ref:`sqlnetclientconfig`.

3. If the application is connecting using an :ref:`Oracle Net service name
   <netservice>` from a ``tnsnames.ora`` file located in a "default" location
   such as the Instant Client ``network/admin/`` subdirectory, in
   ``$ORACLE_HOME/network/admin/``, or in
   ``$ORACLE_BASE/homes/XYZ/network/admin/`` (in a read-only Oracle Database
   home), then the configuration file directory must now explicitly be set as
   shown above.

4. Remove calls to :func:`oracledb.clientversion()` which is only available in
   the python-oracledb Thick mode.  Oracle Client libraries are not available
   in Thin mode.

5. Ensure that any assumptions about when connections are created in the
   connection pool are eliminated.  The python-oracledb Thin mode creates
   connections in a daemon thread and so the attribute
   :attr:`ConnectionPool.opened` will change over time and will not be equal to
   :attr:`ConnectionPool.min` immediately after the pool is created.

   Unless the :func:`oracledb.ConnectionPool()` function's parameter
   ``getmode`` is the new default value, :data:`oracledb.POOL_GETMODE_WAIT`,
   then applications should not call :meth:`ConnectionPool.acquire()` until
   sufficient time has passed for connections in the pool to be created.

   Note that this behavior is also similar in recent versions of the Oracle
   Call Interface (OCI) Session Pool used by the Thick mode.

6. Review error handling improvements. See :ref:`errorhandling`.

7. Review locale and globalization usage. See :ref:`globalization`.

Additional Upgrade Tasks for python-oracledb Thick Mode
=======================================================

The following changes need to be made in addition to the :ref:`commonupgrade`:

1. The function :func:`~oracledb.init_oracle_client()` *must* be called.  It
   can be called anywhere before the first call to :func:`~oracledb.connect()`,
   :func:`oracledb.Connection()`, and :func:`~oracledb.SessionPool()`.  This
   enables the Thick mode. See :ref:`enablingthick` for more details.

   The requirement to call ``init_oracle_client()`` means that Oracle Client
   library loading is not automatically deferred until the driver is first
   used, such as when a connection is opened. The application must explicitly
   manage this, if deferral is required.

   Note that on Linux and related operating systems, the ``lib_dir`` parameter
   should not be passed. Instead, set the system library search path with
   ``ldconfig`` or ``LD_LIBRARY_PATH`` prior to running Python.

2. Replace all usage of the deprecated Advanced Queuing API with the new
   :ref:`AQ API <aqusermanual>` originally introduced in cx_Oracle 7.2, see the
   `cx_Oracle Advanced Queuing (AQ) <https://cx-oracle.readthedocs.io
   /en/latest/api_manual/aq.html>`_ documentation.

3. Review error handling improvements. See :ref:`errorhandling`.

Code to Aid Upgrading to python-oracledb
========================================

.. _toggling:

Toggling between Drivers
-------------------------

The sample `oracledb_upgrade.py
<https://github.com/oracle/python-oracledb/tree/main/samples/oracledb_upgrade.py>`__
shows a way to allow toggling between cx_Oracle and the two python-oracledb
modes:

An example application showing this module in use is:

.. code-block:: python

    # test.py

    import oracledb_upgrade as cx_Oracle
    import os

    un = os.environ.get("PYTHON_USERNAME")
    pw = os.environ.get("PYTHON_PASSWORD")
    cs = os.environ.get("PYTHON_CONNECTSTRING")

    connection = cx_Oracle.connect(user=un, password=pw, dsn=cs)
    with connection.cursor() as cursor:
        sql = """SELECT UNIQUE CLIENT_DRIVER
                 FROM V$SESSION_CONNECT_INFO
                 WHERE SID = SYS_CONTEXT('USERENV', 'SID')"""
        for r, in cursor.execute(sql):
            print(r)

You can then choose what mode is in use by setting the environment variable
ORA_PYTHON_DRIVER_TYPE to one of "cx", "thin", or "thick"::

    export ORA_PYTHON_DRIVER_TYPE=thin
    python test.py

Output shows the python-oracledb Thin mode was used::

    python-oracledb thn : 1.0.0

You can customize ``oracledb_upgrade.py`` to your needs.  For example, if your
connection and pool creation calls always use keyword parameters, you can
remove the shims that map from positional arguments to keyword arguments.

The simplest form is shown in :ref:`frameworks`.

Testing Which Driver is in Use
------------------------------

To know whether the driver is cx_Oracle or python-oracledb, you can use code
similar to:

.. code-block:: python

    import oracledb as cx_Oracle
    # or:
    # import cx_Oracle

    if cx_Oracle.__name__ == 'cx_Oracle':
           print('cx_Oracle')
    else:
           print('oracledb')

Another method that can be used to check which driver is in use is to query::

     SELECT UNIQUE CLIENT_DRIVER
     FROM V$SESSION_CONNECT_INFO
     WHERE SID = SYS_CONTEXT('USERENV', 'SID')"""

However, this method has the overhead of a round-trip to the database.

See :ref:`dbviews` for more information.

.. _frameworks:

Python Frameworks, SQL Generators, and ORMs
===========================================

The python-oracledb Thin mode features in the python-oracledb cover the needs
of frameworks that depend upon the Python Database API.

Until SQLAlchemy, Django, and other third-party frameworks and
Object-relational Mappers (ORMs) add native support for python-oracledb, you
can add temporary code like this:

.. code-block:: python

    import sys
    import oracledb
    oracledb.version = "8.3.0"
    sys.modules["cx_Oracle"] = oracledb
    import cx_Oracle

.. note::

    The import of cx_Oracle occurs last.
