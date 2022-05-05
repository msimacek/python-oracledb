.. _connconfig:

*********************************************************************************
Connection and Connection Configuration Differences between Thick and Thin Modes
*********************************************************************************

Each python-oracledb process can create connections in either the Thick mode or the Thin mode. However, only one mode can be used. You can establish the mode to be used as described below:

  - If :func:`~oracledb.init_oracle_client()` is called in the application before any standalone connection or pool is created, then the mode becomes Thick.
  - If an application creates a standalone connection or pool before calling :func:`~oracledb.init_oracle_client()`, then the mode becomes Thin.
  - If an application opens a connection or creates a pool and then calls :func:`~oracledb.init_oracle_client()`, an error will occur.

Once a mode has been established, either by calling :func:`oracledb.init_oracle_client()` or opening connections, then the mode cannot be changed at that time.

If you want to change the mode you are currently using to take advantage of the features offered in the other mode, you can :ref:`change from one mode to another <changingmodes>`.

.. _syntax:

Connection Syntax
=================

The :func:`oracledb.connect()`, :func:`oracledb.ConnectionPool()`, and :func:`oracledb.create_pool()` functions support several ways of passing parameters which are listed below.

* Using the ConnectParams Class object:

  .. code-block:: python

    params = oracledb.ConnectParams(host="my_host", port=my_port, service_name="my_service_name")
    conn = oracledb.connect(user="my_user", password="my_password", params=params)

  Although cx_Oracle.makedsn() can still be used, and a dsn can be passed for connection, the Thin mode can alternatively make use of the ConnectParams Class. For example, optionally change:

  .. code-block:: python

    dsn = cx_Oracle.makedsn('my_host', my_port, service_name='my_service_name')
    c = cx_Oracle.connect(user='my_user', password='my_password', dsn=dsn)

  to:

  .. code-block:: python
    
    params = oracledb.ConnectParams(host="my_host", port=my_port, service_name="my_service_name")
    c = oracledb.connect(user='my_user', password='my_password', params=params)

* Using the keyword parameter approach mandated by the Python Database API and generally used by frameworks (which depend on the Python Database API):

  .. code-block:: python

    conn = oracledb.connect(user="my_user", password="my_password", host="my_host", port=my_port, service_name="my_service_name")

  Any of the parameters to :func:`oracledb.ConnectParams()` may be also be passed to :func:`oracledb.connect()`, :func:`oracledb.ConnectionPool()`, and :func:`oracledb.create_pool()`. Note that some parameters may be ignored at connection time, based on whether python-oracledb is in Thin or Thick mode.

* Using the the dsn parameter which contains a string representation of the connection parameters which is an alternative method suggested by the Python Database API:

  .. code-block:: python

    conn = oracledb.connect(user="my_user", password="my_password", dsn="my_host:my_port/my_service_name")

  Alternatively, the user and password can also be encoded in the dsn parameter.

  .. code-block:: python

    conn = oracledb.connect("my_user/my_password@my_host:my_port/my_service_name")

  .. note::
    * If the params parameter is specified and keyword parameters are also specified, then the params parameter is updated with the values from the keyword parameters before being used to create the connection.
    * If the dsn parameter is specified and the params parameter is specified, then the params parameter is updated with the contents of the dsn parameter before being used to create the connection.

Local Connections
==================

In Thin mode, there is no concept of a local database. The Thin mode does not de-reference environment variables such as ``ORACLE_SID``, ``TWO_TASK``, or ``LOCAL`` (the latter is specific to Windows). There is no concept of Bequeath connections in Thin mode since no Oracle Client libraries are used.

In Thick mode, all of the above have similar behavior to cx_Oracle and other Oracle Client programs.

.. _connmig:

Connection Migration
====================

The parameters of the :func:`oracledb.connect()` and :func:`oracledb.create_pool()` are now keyword and not positional. This change makes the python-oracledb driver compliant with the Python Database API spec PEP 249.

.. _sqlnetclientconfig:

Oracle Net Services and Client Configuration Files
===================================================

* The python-oracledb Thin mode reads ``tnsnames.ora`` files. The directory can be set:
  - Through the ``TNS_ADMIN`` environment variable
  - Through the :attr:`oracledb.default.config_dir` property which defaults to ``$TNS_ADMIN``
  - By passing ``config_dir`` when creating the connection or pool, or by passing ``config_dir`` to ConnectParams().
 
 The Thin mode does not automatically use the default file locations such as the Instant Client ``network/admin/`` subdirectory, ``$ORACLE_HOME/network/admin/``, or ``$ORACLE_BASE/homes/XYZ/network/admin/`` in a read-only Oracle Database home. Also, the JDBC-thin driver does not use these default file locations.

* The python-oracledb Thin mode does not read ``sqlnet.ora`` files. Instead, use :func:`oracledb.defaults()` or :func:`oracledb.ConnectParams()`.
* The python-oracledb Thin mode does not support ``oraaccess.xml``.

Connection Strings
==================

The python-oracledb Thin mode accepts connection strings in the same formats as the Thick mode, but not all Oracle Net keywords will be supported. The accepted formats are:

 * Easy Connect Strings
 * Full Connect Descriptor Strings
 * Oracle Net Service names

See :ref:`connstr` for more information on connection strings.

The following table lists the parameters that are recognized in Thin mode either as Easy Connect Strings or Full Connect Descriptor Strings that are explicitly passed or referred to by a ``tnsnames.ora`` alias. All unrecognized parameters are ignored.

.. list-table-with-summary::  Oracle Net Keywords Supported in the python-oracledb Thin Mode
    :header-rows: 1
    :align: center
    :summary: The first column displays the keyword. The second column displays the equivalent oracledb.ConnectParams() attribute. The third column displays the notes.

    * - Keyword
      - Equivalent oracledb.ConnectParams() Attribute
      - Notes
    * - SSL_SERVER_CERT_DN
      - ssl_server_cert_dn
      -   
    * - SSL_SERVER_DN_MATCH
      - ssl_server_dn_match
      - Parsing the parameter supports case insensitive on/yes/true values (similar to the Thick mode and cx_Oracle). Any other value is treated as disabling it.
    * - WALLET_LOCATION
      - wallet_location
      - Used in Easy Connect Strings. It is same as MY_WALLET_DIRECTORY in a connect descriptor.
    * - MY_WALLET_DIRECTORY
      - wallet_location
      - Used by connect descriptors. The ``ConnectParams()`` attribute follows the Easy Connect name.
    * - EXPIRE_TIME
      - expire_time
      - 
    * - HTTPS_PROXY
      - https_proxy
      - 
    * - HTTPS_PROXY_PORT
      - https_proxy_port 
      - 
    * - RETRY_COUNT
      - retry_count
      - 
    * - RETRY_DELAY
      - retry_delay
      - 
    * - TRANSPORT_CONNECT_TIMEOUT
      - tcp_connect_timeout
      - 
    * - POOL_CONNECTION_CLASS
      - cclass
      - New in 21c
    * - POOL_PURITY
      - purity
      - New in 21c
    * - SERVICE_NAME
      - service_name
      - 
    * - SID
      - sid
      - 
    * - PORT
      - port
      - 
    * - PROTOCOL
      - protocol
      - 
  
Note that the :ref:`ConnectParams class <connparam>` allows other values to be set for the python-oracledb Thin mode.

In python-oracledb Thin mode, using the ``POOL_CONNECTION_CLASS`` or ``POOL_PURITY`` parameters in a connect descriptor or Easy Connect string is similar to setting the attributes in the :func:`oracledb.Connection()` or :meth:`ConnectionPool.acquire()`.
In python-oracledb Thick mode, the ``POOL_CONNECTION_CLASS`` or ``POOL_PURITY`` values will only work when connected to Oracle Database 21c. If ``POOL_PURITY=SELF`` is used in a connect string, then the python-oracledb Thick mode applications will ignore the action to drop the session which removes unusable connections from a pool in some error cases. It is recommended to avoid using ``POOL_PURITY=SELF`` in a connect string with python-oracledb Thick mode. Instead, code the python-oracledb Thick mode or cx_Oracle application to explicitly specify the purity and connection class as attributes.

The ``ENABLE=BROKEN`` connect descriptor option is not supported in python-oracledb Thin mode. Instead, use ``expire_time``.

The ``Session Data Unit (SDU)`` connect descriptor option that is used to tune network transfers is not supported in python-oracledb Thin mode. The value is hard-coded as 8 KB. In python-oracledb Thick mode, the SDU connect descriptor option and equivalent ``sqlnet.ora`` setting are used.

If a name is given as a connect string, then the python-oracledb Thin mode will consider it as a Net Service Name and not as the minimal Easy Connect string of a hostname. The given connect string will be looked up in a ``tnsnames.ora`` file. This is different from the python-oracledb Thick mode. The workaround in the python-oracledb Thin mode includes using the port number such as ``hostname:1521`` or a protocol such as ``tcp://hostname``.

To identify which Oracle Net connect descriptor parameters are used or ignored by the python-oracledb Thin mode, create a ``ConnectParams Class`` object with the desired connect string. If attributes are not shown in the object, then they have been ignored. Note that even if they are shown, the values may not be used at connection, depending whether python-oracledb is in Thin or Thick mode.

Transport Layer Security (TLS) Support
======================================

Python applications can connect to Oracle Autonomous Database (ADB) in Oracle Cloud either through one-way TLS or mutual TLS.

    - **One-way TLS**: Both the python-oracledb modes support one-way TLS. The python-oracledb Thick mode, cx_Oracle, and any Oracle Call Interface (OCI) based app) support one-way TLS when using Oracle Client libraries from 19.14 and 21.5.
    - **Mutual TLS or Two-way TLS**: For the python-oracledb Thick mode, two-way TLS can be used similarly to cx_Oracle. For the python-oracledb Thin mode, the user must create a Privacy Enhanced Mail (PEM) file.

For detailed information on the TLS support in python-oracledb Thin and Thick modes, see :ref:`autonomousdb`.

Native Network Encryption
=========================

The python-oracledb Thin mode does not support Oracle Native Network Encryption in python-oracledb 1.0 release.

Password Verifiers
==================

The python-oracledb Thin mode supports multi-round hashing algorithms for the 11g (SHA1) and 12c (SHA512) verifiers.

``SQLNET.ALLOWED_LOGON_VERSION`` is not be supported in python-oracledb 1.0 release.