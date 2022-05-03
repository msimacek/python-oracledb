.. module:: oracledb

.. _module:

****************************
API: python-oracledb Module
****************************

This section describes the various functions you can use to access the database and covers the following:

    - :ref:`modmeth`
    - :ref:`constants`
    - :ref:`exceptions`
    - :ref:`exchandling`

.. _modmeth:

Methods
=======

.. data:: __future__

    Special object which contains attributes which control the behavior of
    python-oracledb, allowing for opting in for new features. No attributes are
    currently supported so all attributes will silently ignore being set and
    will always appear to have the value None.

    .. note::

        This method is an extension to the DB API definition.


.. function:: Binary(string)

    Constructs an object holding a binary (long) string value.


.. function:: clientversion()

    Returns the version of the client library being used as a 5-tuple. The five
    values are the major version, minor version, update number, patch number,
    and port update number. 
    
    .. note::

        This function can only be called in python-oracledb Thick mode after 
        :func:`oracledb.init_oracle_client()` has been called.

    Oracle Client is not used in python-oracledb Thin mode.  
    If ``oracledb.clientversion()`` is called when in python-oracledb Thin mode, 
    that is, if :func:`oracledb.init_oracle_client()` is not called first, then 
    an exception will be thrown.

    Applications can reference ``oracledb.__version__`` to determine the version 
    of python-oracledb.

    .. note::

        This method is an extension to the DB API definition.

.. function:: connect(user=None, password=None, dsn=None, \
        mode=oracledb.DEFAULT_AUTH, handle=0, pool=None, threaded=False, \
        events=False, cclass=None, purity=oracledb.ATTR_PURITY_DEFAULT, \
        newpassword=None, encoding=None, nencoding=None, edition=None, \
        appcontext=[], tag=None, matchanytag=None, shardingkey=[], \
        supershardingkey=[], stmtcachesize=20)
    Connection(user=None, password=None, dsn=None, \
        mode=oracledb.DEFAULT_AUTH, handle=0, pool=None, threaded=False, \
        events=False, cclass=None, purity=oracledb.ATTR_PURITY_DEFAULT, \
        newpassword=None, encoding=None, nencoding=None, edition=None, \
        appcontext=[], tag=None, matchanytag=False, shardingkey=[], \
        supershardingkey=[], stmtcachesize=20)

    Constructor for creating a connection to the database. Return a
    :ref:`connection object <connobj>`. All parameters are optional and can be
    specified as keyword parameters.  See :ref:`connhandling` information about
    connections.

    The dsn (data source name) is the TNS entry (from the Oracle names server
    or tnsnames.ora file) or is a string like the one returned from
    :meth:`~oracledb.makedsn()`. If the user parameter is passed and the
    password and dsn parameters are not passed, the user parameter is assumed
    to be a connect string in the format ``user/password@dsn``, the same format
    accepted by Oracle applications such as SQL\*Plus.  See :ref:`connstr` for
    more information.

    If the mode is specified, it must be one of the
    :ref:`connection authorization modes<connection-authorization-modes>`
    which are defined at the module level.

    If the handle is specified, it must be of type OCISvcCtx\* and is only of
    use when embedding Python in an application (like PowerBuilder) which has
    already made the connection. The connection thus created should *never* be
    used after the source handle has been closed or destroyed.

    The pool parameter is expected to be a :ref:`connpool` and 
    the use of this parameter is the equivalent of calling :meth:`ConnectionPool.acquire()`. 
    Parameters not accepted by that method are ignored.

    The threaded parameter is expected to be a boolean expression which
    indicates whether or not Oracle should wrap accesses to connections with a
    mutex. This parameter is deprecated and is ignored in python-oracledb. 
    Threaded Oracle Call Interface (OCI) is now always enabled in the Thick driver
    and is not relevant to the Thin driver.

    The events parameter is expected to be a boolean expression which indicates
    whether or not to initialize Oracle in events mode. This is required for
    continuous query notification and high availability event notifications.

    The cclass parameter is expected to be a string and defines the connection
    class for database resident connection pooling (DRCP).

    The purity parameter is expected to be one of
    :data:`~oracledb.ATTR_PURITY_NEW`, :data:`~oracledb.ATTR_PURITY_SELF`, or
    :data:`~oracledb.ATTR_PURITY_DEFAULT`.

    The newpassword parameter is expected to be a string if specified and sets
    the password for the logon during the connection process.

    See the :ref:`globalization <globalization>` section for details on the
    encoding and nencoding parameters. Note that the default encoding and nencoding
    values changed to "UTF-8" in cx_Oracle 8, and any character set in NLS_LANG
    is ignored. In a future release of python-oracledb, only UTF-8 will be supported.

    The edition parameter is expected to be a string if specified and sets the
    edition to use for the session. It is only relevant if both the client and
    the database are at least Oracle Database 11.2. If this parameter is used
    with the cclass parameter the exception "DPI-1058: edition not supported
    with connection class" will be raised.

    The appcontext parameter is expected to be a list of 3-tuples, if specified,
    and sets the application context for the connection. Application context
    is available in the database by using the sys_context() PL/SQL method and
    can be used within a logon trigger as well as any other PL/SQL procedures.
    Each entry in the list is expected to contain three strings: the namespace,
    the name and the value.

    The tag parameter, if specified, is expected to be a string and will limit
    the sessions that can be returned from a session pool unless the
    matchanytag parameter is set to True. In that case sessions with the
    specified tag will be preferred over others, but if no such sessions are
    available a session with a different tag may be returned instead. In any
    case, untagged sessions will always be returned if no sessions with the
    specified tag are available. Sessions are tagged when they are
    :meth:`released <ConnectionPool.release>` back to the pool.

    The shardingkey and supershardingkey parameters, if specified, are expected
    to be a sequence of values which will be used to identify the database
    shard to connect to. The key values can be strings, numbers, bytes or dates.

    The stmtcachesize parameter, if specified, is expected to be an integer
    which specifies the initial value of :data:`~Connection.stmtcachesize`.


.. function:: ConnectionPool(dsn, pool_params, conn_params, **kwargs)

    Creates a connection pool. Connection pooling creates a pool of available 
    connections to the database, allowing applications to acquire a connection
    very quickly. It is of primary use in a server where connections are requested
    in rapid succession and used for a short period of time, for example in a web server.

    The pool_params parameter is of type PoolParams and contains pool configuration
    parameters. If not specified, a new instance will be created using the additional
    keyword arguments.

    The conn_params parameter is of type ConnectParams and contains connection parameters
    that will be used when creating connections to the database. If not specified, 
    a new instance will be created using the additional keyword arguments.

    .. note::

        This function is only available in python-oracledb Thick mode and not in 
        python-oracledb Thin mode.

    Connection pooling in python-oracledb is handled by Oracle's
    `Session pooling <https://www.oracle.com/pls/topic/lookup?
    ctx=dblatest&id=GUID-F9662FFB-EAEF-495C-96FC-49C6D1D9625C>`__
    technology.  This allows python-oracledb applications to support features
    like `Application Continuity <https://www.oracle.com/pls/topic/lookup?
    ctx=dblatest&id=GUID-A8DD9422-2F82-42A9-9555-134296416E8F>`__.

    .. note::

        This method is an extension to the DB API definition.

.. function:: ConnectParams(user, proxy_user, password, newpassword, wallet_password, \
    host, port, protocol, https_proxy, https_proxy_port, service_name, sid, server_type, \
    cclass, purity, expire_time, retry_count, retry_delay, tcp_connect_timeout, \
    ssl_server_dn_match, ssl_server_cert_dn, wallet_location, events, mode, disable_oob, \
    stmtcachesize, edition, tag, matchanytag, config_dir, appcontext, shardingkey, \
    supershardingkey, handle)

    Contains all the parameters that can be used to establish a connection to the database.
    
    Creates and returns a :ref:`connparam`. The object can be passed to :func:`oracledb.connect()`,
    :func:`oracledb.create_pool()`, or :func:`oracledb.SessionPool()`, see :ref:`syntax`.
    
    All the parameters are optional and must be specified as keyword parameters only.


.. function:: create_pool(dsn, pool_class, pool_params, conn_params, \
    min, max, increment, connectiontype, getmode, homogeneous, externalauth,timeout, \
    wait_timeout, max_lifetime_session, session_callback, max_sessions_per_shard, \
    soda_metadata_cache, ping_interval, user, proxy_user, password, newpassword, \
    wallet_password, host, port, protocol, https_proxy, https_proxy_port, service_name, \
    sid, server_type, cclass, purity, expire_time, retry_count, retry_delay, \
    tcp_connect_timeout, ssl_server_dn_match, ssl_server_cert_dn, wallet_location, \
    events, mode, disable_oob, stmtcachesize, edition, tag, matchanytag, config_dir, \
    appcontext, shardingkey, supershardingkey, handle)

    Creates a connection pool with the supplied parameters and returns it.

    The dsn parameter (data source name) can be a string in the format
    ``user/password@connect_string`` or can simply be a connect string in
    which case the user and password need to be specified separately. 
    See :ref:`connstr` for more information.

    The pool_class parameter is a ConnectionPool or a subclass of
    ConnectionPool. 

    The pool_params parameter is of type PoolParams and contains
    parameters that are used to create the pool. If not specified, a new
    PoolParams object will be created using the additional keyword arguments.
    See :ref:`poolparam` for more information.

    The conn_params parameter is of type ConnectParams and contains 
    connection parameters that will be used when creating connections
    in the pool. If not specified, a new ConnectParams object will be 
    created  using the additional keyword arguments. See :ref:`connparam` 
    for more information. If a dsn is supplied, it will modify the connection
    parameters to include the parameters supplied in the dsn.

.. function:: Cursor(connection)

    Constructor for creating a cursor.  Returns a new
    :ref:`cursor object <cursorobj>` using the connection.

    .. note::

        This method is an extension to the DB API definition.


.. function:: Date(year, month, day)

    Constructs an object holding a date value.


.. function:: DateFromTicks(ticks)

    Constructs an object holding a date value from the given ticks value 
    (number of seconds since the epoch; see the documentation of the standard 
    Python time module for details).
    
.. function:: defaults(arraysize=100, stmtcachesize=20, config_dir=os.environ.get("TNS_ADMIN"), \ 
    fetch_lobs=True, fetch_decimals=False, prefetchrows=2)

    A singleton that contains attributes that can be used to adjust the 
    default behavior of the python-oracledb driver in the application. 
    The attributes that are not supported in a specific mode (python-oracledb Thick 
    or python-oracledb Thin) will be ignored.

    The arraysize parameter is the default value for :attr:`Cursor.arraysize`. 
    This parameter is supported in both the python-oracledb Thin and Thick modes 
    and has an initial value of 100.

    The stmtcachesize parameter is the default value for :attr:`Connection.stmtcachesize`, 
    :attr:`ConnectionPool.stmtcachesize`, and :attr:`SessionPool.stmtcachesize`. This is a 
    tuning attribute. This parameter is supported in both the python-oracledb Thin and Thick 
    modes and has an initial value of 20.

    The config_dir parameter is the directory in which configuration files such as 
    tnsnames.ora are found by default. If the ``TNS_ADMIN`` environment variable is 
    not set, then the default value is None in the python-oracledb Thin mode and no 
    tnsnames.ora file will be usable until the attribute value is changed. If this 
    parameter is None in the python-oracledb Thick mode, then the usual Oracle Client 
    search path behavior for configuration files is used. This is described in the 
    cx_Oracle documentation and the Oracle Client library documentation. This parameter 
    is supported in both the python-oracledb Thick and Thin modes and has an 
    initial value of ``os.environ.get("TNS_ADMIN")``.

    When the value of the fetch_lobs parameter is True, then queries to LOB columns 
    return LOB locators. When the value of this parameter is False, then strings or 
    bytes are fetched. If LOBs are larger than 1 GB, then this parameter should be set 
    to True and the LOBs should be streamed. An output type handler such as the one 
    currently used in cx_Oracle (see `return_lobs_as_strings.py <https://github.com/
    oracle/python-cx_Oracle/blob/main/samples/return_lobs_as_strings.py>`__) can 
    alternatively be used to adjust the returned type. If a type handler exists and 
    returns a variable (that is, `cursor.var(...)`), then that return variable is used. 
    If the type handler returns None, then the value of ``oracledb.defaults.fetch_lobs`` 
    is used. This parameter is supported in both the python-oracledb Thin and Thick modes 
    and has an initial value of True.
    
    The fetch_decimals parameter identifies whether numbers should be fetched as 
    ``decimal.Decimal`` values. This can help avoid issues with converting numbers from 
    Oracle Database's decimal format to Python's binary format. An output type handler 
    such as the one currently used in cx_Oracle (see `return_numbers_as_decimals.py 
    <https://github.com/oracle/python-cx_Oracle/blob/main/samples/return_numbers_as_
    decimals.py>`__) can alternatively be used to adjust the returned type. If a type 
    handler exists and returns a variable (that is, `cursor.var(...)`), then that return 
    variable is used. If the type handler returns None, then the value of 
    ``oracledb.defaults.fetch_decimals`` is used. This parameter is supported in both 
    the python-oracledb Thin and Thick modes and has an initial value of False.

    The prefetchrows parameter is the default value for :attr:`Cursor.prefetchrow`. 
    This parameter is supported in both the python-oracledb Thin and Thick modes 
    and has an initial value of 2.


.. function:: init_oracle_client(lib_dir=None, config_dir=None, \
        error_url=None, driver_name=None)

    Initializes the Oracle client library now, rather than when
    :func:`oracledb.clientversion()`, :func:`oracledb.connect()` or
    :func:`oracledb.ConnectionPool()` is called for the first time. If
    initialization has already taken place, an exception is raised.

    If the parameter lib_dir is not None or the empty string,
    the specified directory is the only one searched for the Oracle Client
    libraries; otherwise, the standard way of locating the Oracle Client
    library is used.

    If the parameter config_dir is not None or the empty string, the
    specified directory is used to find Oracle Client library configuration
    files. This is equivalent to setting the environment variable ``TNS_ADMIN``
    and overrides any value already set in ``TNS_ADMIN``. If this parameter is not
    set, the standard way of locating Oracle Client library configuration files
    is used.

    If the parameter error_url is not None or the empty string, the
    specified value is included in the message of the exception raised when the
    Oracle Client library cannot be loaded; otherwise, the :ref:`installation`
    URL is included.

    If the parameter driver_name is not None or the empty string, the
    specified value can be found in database views that give information about
    connections. For example, it is in the ``CLIENT_DRIVER`` column of
    ``V$SESSION_CONNECT_INFO``. The standard is to set this value to
    ``"<name> : version>"``, where <name> is the name of the driver and
    <version> is its version. There should be a single space character before
    and after the colon. If this value is not specified, then the default
    value of "oracledb : <version>" is used.

    See :ref:`initialization` for more discussion.

    .. note::

        This method is an extension to the DB API definition.


.. function:: makedsn(host, port, sid=None, service_name=None, region=None, \
        sharding_key=None, super_sharding_key=None)

    Returns a string suitable for use as the dsn parameter for
    :meth:`~oracledb.connect()`. This string is identical to the strings that
    are defined by the Oracle names server or defined in the tnsnames.ora file.

    .. note::

        This method is an extension to the DB API definition.

.. function:: PoolParams(min, max, increment, connectiontype, getmode, \
    homogeneous, externalauth, timeout, wait_timeout, max_lifetime_session, \
    session_callback, max_sessions_per_shard, soda_metadata_cache, ping_interval)

    Contains all the parameters that can be used to create a connection pool.
    All the parameters are optional and must be specified as keyword parameters
    only. For detailed information on the parameters, see :ref:`PoolParams attributes 
    <poolparamsattr>`.

    All of these parameters are not applicable for both the python-oracledb Thin
    and Thick modes.


.. function:: SessionPool(user=None, password=None, dsn=None, min=1, max=2, \
        increment=1, connectiontype=oracledb.Connection, threaded=True, \
        getmode=oracledb.SPOOL_ATTRVAL_NOWAIT, events=False, \
        homogeneous=True, externalauth=False, encoding=None, nencoding=None, \
        edition=None, timeout=0, wait_timeout=0, max_lifetime_session=0, \
        session_callback=None, max_sessions_per_shard=0, \
        soda_metadata_cache=False, stmtcachesize=20, ping_interval=60)

    .. deprecated:: python-oracledb 1.0

        See :ref:`deprecations` for a complete list of deprecated features.
    
    Creates and returns a :ref:`session pool object <sesspool>`.  Session pooling
    (also known as connection pooling) creates a pool of available connections
    to the database, allowing applications to acquire a connection very quickly.
    It is of primary use in a server where connections are requested in rapid
    succession and used for a short period of time, for example in a web server.
    See :ref:`connpooling` for more information.

    Connection pooling in python-oracledb is handled by Oracle's
    `Session pooling <https://www.oracle.com/pls/topic/lookup?
    ctx=dblatest&id=GUID-F9662FFB-EAEF-495C-96FC-49C6D1D9625C>`__
    technology.  This allows python-oracledb applications to support features
    like `Application Continuity <https://www.oracle.com/pls/topic/lookup?
    ctx=dblatest&id=GUID-A8DD9422-2F82-42A9-9555-134296416E8F>`__.

    The `user`, `password`, and `dsn`` parameters are the same as for
    :meth:`oracledb.connect()`

    The `min`, `max` and `increment` parameters control pool growth behavior.  A fixed
    pool size where min equals max is recommended to help prevent connection
    storms and to help overall system stability.  The `min` parameter is the
    number of connections opened when the pool is created.  The `increment` is the
    number of connections that are opened whenever a connection request exceeds
    the number of currently open connections.  The `max` parameter is the maximum
    number of connections that can be open in the connection pool.

    Note that when using :ref:`external authentication <extauth>`,
    :ref:`heterogeneous pools <connpooltypes>`, or :ref:`drcp`, then the pool
    growth behavior is different.  In these cases the number of connections
    created at pool startup is always zero, and the increment is always one.

    If the `connectiontype` parameter is specified, all calls to
    :meth:`~SessionPool.acquire()` will create connection objects of that type,
    rather than the base type defined at the module level.

    The `getmode` parameter indicates whether or not future
    :func:`SessionPool.acquire()` calls will wait for available connections.  It
    can be one of the :ref:`Session Pool Get Modes <sesspoolmodes>` values.

    The `events` parameter is expected to be a boolean expression which indicates
    whether or not to initialize Oracle in events mode. This is required for
    continuous query notification and high availability event notifications.

    The `homogeneous` parameter is expected to be a boolean expression which
    indicates whether or not to create a homogeneous pool. A homogeneous pool
    requires that all connections in the pool use the same credentials. As such
    proxy authentication and external authentication is not possible with a
    homogeneous pool.  See :ref:`Heterogeneous and Homogeneous Connection Pools
    <connpooltypes>`.

    The `externalauth` parameter is expected to be a boolean expression which
    indicates whether or not external authentication should be used. External
    authentication implies that something other than the database is
    authenticating the user to the database. This includes the use of operating
    system authentication and Oracle wallets.  See :ref:`Connecting Using
    External Authentication <extauth>`.

    The `encoding` and `nencoding` parameters set the encodings used for string
    values transferred between python-oracledb and Oracle Database, see
    :ref:`Character Sets and Globalization <globalization>`. Note the default
    encoding and nencoding values changed to "UTF-8" in cx_Oracle 8, and any
    character set in NLS_LANG is ignored. In a future release of python-oracledb,
    only UTF-8 will be supported.

    The `edition` parameter is expected to be a string, if specified, and sets the
    edition to use for the sessions in the pool. It is only relevant if both the
    client and the server are at least Oracle Database 11.2.  See
    :ref:`Edition-Based Redefinition (EBR) <ebr>`.

    The `timeout` parameter is expected to be an integer, if specified, and sets
    the length of time (in seconds) after which idle sessions in the pool are
    terminated. Note that termination only occurs when the pool is accessed.
    The default value of 0 means that no idle sessions are terminated. The
    initial pool timeout must be non-zero if you subsequently want to change
    the timeout with :meth:`SessionPool.reconfigure()`.

    The `wait_timeout` parameter is expected to be an integer, if specified, and
    sets the length of time (in milliseconds) that the caller should wait for
    a session to become available in the pool before returning with an error.
    This value is only used if the getmode parameter is set to the value
    :data:`oracledb.SPOOL_ATTRVAL_TIMEDWAIT`.

    The `max_lifetime_session` parameter is expected to be an integer, if
    specified, and sets the maximum length of time (in seconds) a pooled
    session may exist. Sessions that are in use will not be closed. They become
    candidates for termination only when they are released back to the pool and
    have existed for longer than max_lifetime_session seconds. Note that
    termination only occurs when the pool is accessed. The default value is 0
    which means that there is no maximum length of time that a pooled session
    may exist.

    The `session_callback` parameter is expected to be either a string or a
    callable. If the session_callback parameter is a callable, it will be
    called when a newly created connection is returned from the pool, or when a
    tag is requested and that tag does not match the connection's actual tag.
    The callable will be invoked with the connection and the requested tag as
    its only parameters.  If the parameter is a string, it should be the name
    of a PL/SQL procedure that will be called when
    :func:`SessionPool.acquire()` requests a tag and that tag does not match
    the connection's actual tag. See :ref:`Session CallBacks for Setting Pooled
    Connection State <sessioncallback>`. Support for the PL/SQL procedure
    requires Oracle Client libraries 12.2 or later.  See the `OCI documentation
    <https://www.oracle.com/pls/topic/lookup?ctx=dblatest&
    id=GUID-B853A020-752F-494A-8D88-D0396EF57177>`__ for more information.

    The `max_sessions_per_shard` parameter is expected to be an integer, if
    specified. Setting this greater than zero specifies the maximum number of
    sessions in the pool that can be used for any given shard in a sharded
    database. This lets connections in the pool be balanced across the shards.
    A value of zero will not set any maximum number of sessions for each shard.
    This value is ignored if the Oracle Client library version is less than
    18.3.

    The `soda_metadata_cache` parameter is expected to be a boolean expresion
    which indicates whether or not to enable the SODA metatata cache. This
    significantly improves the performance of methods
    :meth:`SodaDatabase.createCollection()` and
    :meth:`SodaDatabase.openCollection()` but can become out of date as it does
    not track changes made externally. It is also only available in Oracle
    Client 19.11 and higher. See :ref:`Using the SODA Metadata Cache
    <sodametadatacache>`.

    The `stmtcachesize` parameter, if specified, is expected to be an integer
    which specifies the initial value of :data:`~SessionPool.stmtcachesize`.

    The `ping_interval` parameter, if specified, is expected to be an integer
    which specifies the initial value of :data:`~SessionPool.ping_interval`.

    .. note::

        This method is an extension to the DB API definition.

    For consistency and compliance with the PEP
    8 naming style, the parameter `waitTimeout` was renamed to
    `wait_timeout`, the parameter `maxLifetimeSession` was renamed to
    `max_lifetime_session`, the parameter `sessionCallback` was renamed to
    `session_callback` and the parameter `maxSessionsPerShard` was renamed
    to `max_sessions_per_shard`. The old names will continue to work as
    keyword parameters for a period of time. The `threaded` parameter value
    is ignored and threading is always enabled; in previous versions of cx_Oracle the
    default was False.


.. function:: Time(hour, minute, second)

    Constructs an object holding a time value.

    .. note::

        The time only data type is not supported by Oracle. Calling this
        function will raise a NotSupportedError exception.


.. function:: TimeFromTicks(ticks)

    Constructs an object holding a time value from the given ticks value (number
    of seconds since the epoch; see the documentation of the standard Python
    time module for details).

    .. note::

        The time only data type is not supported by Oracle. Calling this
        function will raise a NotSupportedError exception.

.. function:: Timestamp(year, month, day, hour, minute, second)

    Constructs an object holding a time stamp value.

.. function:: TimestampFromTicks(ticks)

    Constructs an object holding a time stamp value from the given ticks value
    (number of seconds since the epoch; see the documentation of the standard
    Python time module for details).


.. _connparameters:

ConnectParam Parameters
------------------------

.. attribute:: ConnectParams.appcontext

  This read-write attribute specifies the application context used by the connection. 
  It is a list of 3-tuples. Each entry in the tuple is a string and makes up the 
  namespace, the name, and the value. The value can be referenced in the database by using 
  the PL/SQL method ``sys_context()`` within logon triggers or other PL/SQL procedures.

  This attribute is only supported in the python-oracledb Thick mode.

.. attribute:: ConnectParams.cclass

  This read-only attribute is a string that returns a specifies the connection class (class) 
  to use for database resident connection pooling (DRCP).
  
  This attribute returns the cclass associated with each description in the
  connect string. If the connect string contains multiple descriptions,
  a list of cclass is returned in the order that they appear.

  This attribute is supported in both the python-oracledb Thin and Thick modes.

.. attribute:: ConnectParams.config_dir

  This read-write attribute is a string that identifies the directory in which configuration files 
  such as tnsnames.ora are found. The default value is :attr:`oracledb.defaults.config_dir`.

  This attribute is supported only in the python-oracledb Thin mode.

.. attribute:: ConnectParams.disable_oob

  This read-write attribute is a boolean that indicates whether out-of-band breaks should be disabled. 
  The default value is False. Note that out-of-band breaks are not supported on Windows. 

  This attribute is supported only in the python-oracledb Thin mode.

.. attribute:: ConnectParams.edition

  This read-write attribute is a string that specifies the edition to use for the connection. This attribute cannot be
  used simultaneously with the :attr:`ConnectParams.cclass` attribute.

  This attribute is supported in both the python-oracledb Thin and Thick modes.

.. attribute:: ConnectParams.events

  This read-write attribute is a boolean that specifies whether the events mode should be enabled. 
  
  This attribute is needed for continuous query notification (CQN) and high availability event notifications. 
  The default value is False.

  This attribute is supported only in the python-oracledb Thick mode.

.. attribute:: ConnectParams.expire_time

  This read-only attribute is an integer that returns the number of minutes between the sending of keepalive probes. 
  If this parameter is set to a value greater than zero it enables keepalive.
  The default value is 0.

  This attribute returns the expire_time associated with each description in the
  connect string. If the connect string contains multiple descriptions,
  a list of expire_times is returned in the order that they appear.

  This attribute is supported in both the python-oracledb Thin and Thick modes.

.. attribute:: ConnectParams.handle

  This read-write attribute is an integer that representsa pointer to a valid service context
  handle. This attribute must be used with extreme caution.
  The default value is 0.

  This attribute is supported only in the python-oracledb Thick mode.

.. attribute:: ConnectParams.host

  This read-only attribute is a string that returns the name or IP address of the machine
  hosting the listener, which handles the initial connection to the database.

  This attribute returns the host associated with the address in the connect string.
  If the connect string contains multiple addresses, a list of hosts
  is returned in the order that they appear.

  This attribute is supported in both the python-oracledb Thin and Thick modes.

.. attribute:: ConnectParams.https_proxy

  This read-only attribute is a string that returns the name or IP address of a proxy host 
  that is to be used for tunneling secure connections.

  This attribute returns the proxy host associated with the address in the connect
  string. If the connect string contains multiple addresses, a list of
  proxy hosts is returned in the order that they appear.

  This attribute is supported in both the python-oracledb Thin and Thick modes.

.. attribute:: ConnectParams.https_proxy_port

  This read-only attribute is an integer that returns the port to be used to communicate with the proxy host.

  This attribute returns the proxy host port associated with the address in the connect
  string. If the connect string contains multiple addresses, a list of
  proxy host ports is returned in the order that they appear.

  This attribute is supported in both the python-oracledb Thin and Thick modes.

.. attribute:: ConnectParams.matchanytag

  This read-write attribute is a boolean that specifies whether any tag can be used when acquiring a connection 
  from the pool. This attribute is only relevant when acquiring a connection from a pool.
  The default value is False.

  This attribute is supported only in the python-oracledb Thick mode.

.. attribute:: ConnectParams.mode

  This read-write attribute is an integer that specifies the authorization mode to use.
  The default value is :data:`~oracledb.AUTH_MODE_DEFAULT`.

  This attribute is supported in both the python-oracledb Thin and Thick modes.

.. attribute:: ConnectParams.newpassword

  This attribute is a string and specifies the new password for the user.
  The new password takes effect immediately upon a successful connection to
  the database.

  This attribute is supported in both the python-oracledb Thin and Thick modes.

.. attribute:: ConnectParams.password

  This attribute is a string and specifies the password for the user.

  This attribute is supported in both the python-oracledb Thin and Thick modes.

.. attribute:: ConnectParams.port

  This read-only attribute is an integer that returns the port number on which 
  the listener is listening. The default value is 1521.

  This attribute returns the port associated with the address in the connect
  string. If the connect string contains multiple addresses, a list of
  ports is returned in the order that they appear.

  This attribute is supported in both the python-oracledb Thin and Thick modes.

.. attribute:: ConnectParams.protocol

  This read-only attribute is a string that indicates whether unencrypted network traffic 
  or encrypted network traffic (TLS) is used and it can have the value tcp or tcps. 
  The default value is tcp.

  This attribute returns the protocol associated with the address in the connect
  string. If the connect string contains multiple addresses, a list of
  protocols is returned in the order that they appear.

  This attribute is supported in both the python-oracledb Thin and Thick modes.

.. attribute:: ConnectParams.proxy_user

  This read-write attribute is a string that specifies the name of the proxy user to connect to.
  If this value is not specified, then it will be parsed out of the user if the user attribute
  is in the form "user{proxy_user]".

  This attribute is supported in both the python-oracledb Thin and Thick modes.


.. attribute:: ConnectParams.purity

  This read-only attribute is an integer that returns the purity used for DRCP.
  The default value is :data:`~oracledb.PURITY_DEFAULT`.

  This attribute returns the purity associated with each description in the connect
  string. If the connect string contains multiple descriptions, a list
  of purity is returned in the order that they appear.

  This attribute is supported in both the python-oracledb Thin and Thick modes.

.. attribute:: ConnectParams.retry_count

  This read-only attribute is an integer that returns the number of times that a connection attempt
  should be made before the attempt is terminated. The default value is 0.

  This attribute returns the retry_counts associated with each description in the
  connect string. If the connect string contains multiple descriptions,
  a list of retry_counts is returned in the order that they appear.

  This attribute is supported in both the python-oracledb Thin and Thick modes.

.. attribute:: ConnectParams.retry_delay

  This read-only attribute is an integer that returns the number of seconds to wait before making a new
  connection attempt. The default value is 0.

  This attribute returns the retry_delays associated with each description in the
  connect string. If the connect string contains multiple descriptions,
  a list of retry_delays is returned in the order that they appear.

  This attribute is supported in both the python-oracledb Thin and Thick modes.

.. attribute:: ConnectParams.server_type

  This read-only attribute is a string that returns the type of server connection that should be established.
  If specified, it should be one of `dedicated`, `shared`, or `pooled`.

  This attribute returns the type of server connection that should be established. If
  the connect string contains multiple descriptions, a list of
  server_types is returned in the order that they appear.

  This attribute is supported in both the python-oracledb Thin and Thick modes.

.. attribute:: ConnectParams.service_name

  This read-only attribute is a string that returns the service name of the database.

  This attribute returns the service_names associated with each description in the
  connect string. If the connect string contains multiple descriptions,
  a list of service_names is returned in the order that they appear.

  This attribute is supported in both the python-oracledb Thin and Thick modes.

.. attribute:: ConnectParams.shardingkey

  This read-write attribute is a list that specifies a sequence of strings, numbers, bytes, or dates that
  identify the database shard to connect to. 

  This attribute is only supported in the python-oracledb Thick mode.

.. attribute:: ConnectParams.sid

  This read-only attribute is a string that returns the SID of the database. Use the service_name instead.

  This attribute returns the sid associated with each description in the connect
  string. If the connect string contains multiple descriptions, a list
  of sid is returned in the order that they appear.

  This attribute is supported in both the python-oracledb Thin and Thick modes.

.. attribute:: ConnectParams.ssl_server_cert_dn

  This read-only attribute is a string that returns the distinguished name (DN) which should be matched
  with the server. This value is ignored if the :attr:`~ConnectParams.ssl_server_dn_match`
  attribute is not set to the value True. If this value is specified, then it is used
  for any verification. Otherwise, the hostname will be used.

  This attribute returns the ssl_server_cert_dn associated with each description in
  the connect string. If the connect string contains multiple descriptions, a list 
  of ssl_server_cert_dn is returned in the order that they appear.

  This attribute is supported in both the python-oracledb Thin and Thick modes.

.. attribute:: ConnectParams.ssl_server_dn_match

  This read-only attribute is a boolean that indicates whether the server certificate
  distinguished name (DN) should be matched in addition to the regular
  certificate verification that is performed. The default value is True.

  Note that if the :attr:`~ConnectParams.ssl_server_cert_dn` attribute is not specified, 
  then no matching is done regardless of the value of this parameter.

  This attribute returns the ssl_server_dn_match associated with each description in
  the connect string. If the connect string contains multiple descriptions, a list of 
  ssl_server_dn_match is returned in the order that they appear.

  This attribute is supported in both the python-oracledb Thin and Thick modes.

.. attribute:: ConnectParams.stmtcachesize

  This read-write attribute is an integer that identifies the initial size of the statement cache. 
  The default value is :attr:`oracledb.defaults.stmtcachesize`.

  This attribute is supported in both the python-oracledb Thin and Thick modes.

.. attribute:: ConnectParams.supershardingkey

  This read-write attribute is a list that specifies a sequence of strings, numbers, bytes, or dates 
  that identify the database shard to connect to.

  This attribute is only supported in python-oracledb Thick mode.

.. attribute:: ConnectParams.tag

  This read-write attribute is a string that identifies the type of connection that should be returned 
  from a pool. Only a connection with the requested tag or a connection without
  any tag will be returned unless the :attr:`~ConnectParams.matchanytag` attribute is True. 
  If the :attr:`~ConnectParams.matchanytag` attribute is True, then a connection 
  with any tag or no tag will be returned if no connections with the requested tag
  are currently available. Connections are tagged when they are released back to the
  pool.

  This attribute is only supported in python-oracledb Thick mode.

.. attribute:: ConnectParams.tcp_connect_timeout

  This read-only attribute is a float that indicates the maximum number of seconds to wait for 
  a connection to be estbalished to the database host.
  The default value is 60.0.

  This attribute  returns the tcp_connect_timeout associated with each description in
  the connect string. If the connect string contains multiple descriptions, a list 
  of tcp_connect_timeout is returned in the order that they appear.

  This attribute is supported in both the python-oracledb Thin and Thick modes.

.. attribute:: ConnectParams.user

  This read-write attribute is a string that specifies the name of the user to connect to.

  This attribute is supported in both the python-oracledb Thin and Thick modes.


.. attribute:: ConnectParams.wallet_location

  This read-only attribute is a string that specifies the location where the PEM-encoded wallet file
  ewallet.pem can be found. If this parameter is not set, one-way TLS authentication 
  will take place instead.

  This attribute returns the wallet_location associated with each description in
  the connect string. If the connect string contains multiple descriptions, a list of
  wallet_location is returned in the order that they appear.

  This attribute is supported in both the python-oracledb Thin and Thick modes.

.. attribute:: ConnectParams.wallet_password

  This attribute is a string that specifies the password used to decrypt the contents of the 
  Privacy Enhanced Mail (PEM) encoded wallet file, if applicable.

  This attribute returns the wallet_password associated with each description in
  the connect string. If the connect string contains multiple descriptions, a list of
  wallet_password is returned in the order that they appear.

  This attribute is supported only in the python-oracledb Thin mode.

.. _constants:

Constants
=========

General
-------

.. data:: apilevel

    String constant stating the supported DB API level. Currently '2.0'.


.. data:: buildtime

    String constant stating the time when the binary was built.

    .. note::

        This constant is an extension to the DB API definition.


.. data:: paramstyle

    String constant stating the type of parameter marker formatting expected by
    the interface. Currently 'named' as in 'where name = :name'.


.. data:: threadsafety

    Integer constant stating the level of thread safety that the interface
    supports.  Currently 2, which means that threads may share the module and
    connections, but not cursors. Sharing means that a thread may use a
    resource without wrapping it using a mutex semaphore to implement resource
    locking.

    Note that in order to make use of multiple threads in a program which
    intends to connect and disconnect in different threads, the threaded
    parameter to :meth:`connect()` must be `True`.


.. data:: version
.. data:: __version__

    String constant stating the version of the module. Currently '|release|'.

    .. note::

        This attribute is an extension to the DB API definition.


Advanced Queuing: Delivery Modes
--------------------------------

These constants are extensions to the DB API definition. They are possible
values for the :attr:`~DeqOptions.deliverymode` attribute of the
:ref:`dequeue options object <deqoptions>` passed as the options parameter to
the :meth:`Connection.deq()` method as well as the
:attr:`~EnqOptions.deliverymode` attribute of the
:ref:`enqueue options object <enqoptions>` passed as the options parameter to
the :meth:`Connection.enq()` method. They are also possible values for the
:attr:`~MessageProperties.deliverymode` attribute of the
:ref:`message properties object <msgproperties>` passed as the msgproperties
parameter to the :meth:`Connection.deq()` and :meth:`Connection.enq()` methods.


.. data:: MSG_BUFFERED

    This constant is used to specify that enqueue/dequeue operations should
    enqueue or dequeue buffered messages.


.. data:: MSG_PERSISTENT

    This constant is used to specify that enqueue/dequeue operations should
    enqueue or dequeue persistent messages. This is the default value.


.. data:: MSG_PERSISTENT_OR_BUFFERED

    This constant is used to specify that dequeue operations should dequeue
    either persistent or buffered messages.


Advanced Queuing: Dequeue Modes
-------------------------------

These constants are extensions to the DB API definition. They are possible
values for the :attr:`~DeqOptions.mode` attribute of the
:ref:`dequeue options object <deqoptions>`. This object is the options
parameter for the :meth:`Connection.deq()` method.


.. data:: DEQ_BROWSE

    This constant is used to specify that dequeue should read the message
    without acquiring any lock on the message (equivalent to a select
    statement).


.. data:: DEQ_LOCKED

    This constant is used to specify that dequeue should read and obtain a
    write lock on the message for the duration of the transaction (equivalent
    to a select for update statement).


.. data:: DEQ_REMOVE

    This constant is used to specify that dequeue should read the message and
    update or delete it. This is the default value.


.. data:: DEQ_REMOVE_NODATA

    This constant is used to specify that dequeue should confirm receipt of the
    message but not deliver the actual message content.


Advanced Queuing: Dequeue Navigation Modes
------------------------------------------

These constants are extensions to the DB API definition. They are possible
values for the :attr:`~DeqOptions.navigation` attribute of the
:ref:`dequeue options object <deqoptions>`. This object is the options
parameter for the :meth:`Connection.deq()` method.


.. data:: DEQ_FIRST_MSG

    This constant is used to specify that dequeue should retrieve the first
    available message that matches the search criteria. This resets the
    position to the beginning of the queue.


.. data:: DEQ_NEXT_MSG

    This constant is used to specify that dequeue should retrieve the next
    available message that matches the search criteria. If the previous message
    belongs to a message group, AQ retrieves the next available message that
    matches the search criteria and belongs to the message group. This is the
    default.


.. data:: DEQ_NEXT_TRANSACTION

    This constant is used to specify that dequeue should skip the remainder of
    the transaction group and retrieve the first message of the next
    transaction group. This option can only be used if message grouping is
    enabled for the current queue.


Advanced Queuing: Dequeue Visibility Modes
------------------------------------------

These constants are extensions to the DB API definition. They are possible
values for the :attr:`~DeqOptions.visibility` attribute of the
:ref:`dequeue options object <deqoptions>`. This object is the options
parameter for the :meth:`Connection.deq()` method.


.. data:: DEQ_IMMEDIATE

    This constant is used to specify that dequeue should perform its work as
    part of an independent transaction.


.. data:: DEQ_ON_COMMIT

    This constant is used to specify that dequeue should be part of the current
    transaction. This is the default value.


Advanced Queuing: Dequeue Wait Modes
------------------------------------

These constants are extensions to the DB API definition. They are possible
values for the :attr:`~DeqOptions.wait` attribute of the
:ref:`dequeue options object <deqoptions>`. This object is the options
parameter for the :meth:`Connection.deq()` method.


.. data:: DEQ_NO_WAIT

    This constant is used to specify that dequeue not wait for messages to be
    available for dequeuing.


.. data:: DEQ_WAIT_FOREVER

    This constant is used to specify that dequeue should wait forever for
    messages to be available for dequeuing. This is the default value.


Advanced Queuing: Enqueue Visibility Modes
------------------------------------------

These constants are extensions to the DB API definition. They are possible
values for the :attr:`~EnqOptions.visibility` attribute of the
:ref:`enqueue options object <enqoptions>`. This object is the options
parameter for the :meth:`Connection.enq()` method.


.. data:: ENQ_IMMEDIATE

    This constant is used to specify that enqueue should perform its work as
    part of an independent transaction.


.. data:: ENQ_ON_COMMIT

    This constant is used to specify that enqueue should be part of the current
    transaction. This is the default value.


Advanced Queuing: Message States
--------------------------------

These constants are extensions to the DB API definition. They are possible
values for the :attr:`~MessageProperties.state` attribute of the
:ref:`message properties object <msgproperties>`. This object is the
msgproperties parameter for the :meth:`Connection.deq()` and
:meth:`Connection.enq()` methods.


.. data:: MSG_EXPIRED

    This constant is used to specify that the message has been moved to the
    exception queue.


.. data:: MSG_PROCESSED

    This constant is used to specify that the message has been processed and
    has been retained.


.. data:: MSG_READY

    This constant is used to specify that the message is ready to be processed.


.. data:: MSG_WAITING

    This constant is used to specify that the message delay has not yet been
    reached.


Advanced Queuing: Other
-----------------------

These constants are extensions to the DB API definition. They are special
constants used in advanced queuing.


.. data:: MSG_NO_DELAY

    This constant is a possible value for the :attr:`~MessageProperties.delay`
    attribute of the :ref:`message properties object <msgproperties>` passed
    as the msgproperties parameter to the :meth:`Connection.deq()` and
    :meth:`Connection.enq()` methods. It specifies that no delay should be
    imposed and the message should be immediately available for dequeuing. This
    is also the default value.


.. data:: MSG_NO_EXPIRATION

    This constant is a possible value for the
    :attr:`~MessageProperties.expiration` attribute of the
    :ref:`message properties object <msgproperties>` passed as the msgproperties
    parameter to the :meth:`Connection.deq()` and :meth:`Connection.enq()`
    methods. It specifies that the message never expires. This is also the
    default value.


.. _connection-authorization-modes:

Connection Authorization Modes
------------------------------

These constants are extensions to the DB API definition. They are possible
values for the mode parameter of the :meth:`connect()` method.


.. data:: AUTH_MODE_DEFAULT

    This constant is used to specify that default authentication is to take
    place. This is the default value if no mode is passed at all.


.. data:: AUTH_MODE_SYSASM

    This constant is used to specify that SYSASM access is to be acquired.

.. data:: AUTH_MODE_SYSBKP

    This constant is used to specify that SYSBACKUP access is to be acquired.

.. data:: AUTH_MODE_SYSDBA

    This constant is used to specify that SYSDBA access is to be acquired.

.. data:: AUTH_MODE_SYSDGD

    This constant is used to specify that SYSDG access is to be acquired.

.. data:: AUTH_MODE_SYSKMT

    This constant is used to specify that SYSKM access is to be acquired.

.. data:: AUTH_MODE_SYSOPER

    This constant is used to specify that SYSOPER access is to be acquired.

.. data:: AUTH_MODE_SYSRAC

    This constant is used to specify that SYSRAC access is to be acquired.

.. data:: AUTH_MODE_PRELIM

    This constant is used to specify that preliminary authentication is to be
    used. This is needed for performing database startup and shutdown.

.. data:: DEFAULT_AUTH

    This constant is used to specify that default authentication is to take
    place. This is the default value if no mode is passed at all.

    .. deprecated:: python-oracledb 1.0

        Use :data:`~oracledb.AUTH_MODE_DEFAULT` instead.

.. data:: PRELIM_AUTH

    This constant is used to specify that preliminary authentication is to be
    used. This is needed for performing database startup and shutdown.

    .. deprecated:: python-oracledb 1.0

        Use :data:`~oracledb.AUTH_MODE_PRELIM` instead.

.. data:: SYSASM

    This constant is used to specify that SYSASM access is to be acquired.

    .. deprecated:: python-oracledb 1.0

        Use :data:`~oracledb.AUTH_MODE_SYSASM` instead.

.. data:: SYSBKP

    This constant is used to specify that SYSBACKUP access is to be acquired.

    .. deprecated:: python-oracledb 1.0

        Use :data:`~oracledb.AUTH_MODE_SYSBKP` instead.

.. data:: SYSDBA

    This constant is used to specify that SYSDBA access is to be acquired.

    .. deprecated:: python-oracledb 1.0

        Use :data:`~oracledb.AUTH_MODE_SYSDBA` instead.

.. data:: SYSDGD

    This constant is used to specify that SYSDG access is to be acquired.

    .. deprecated:: python-oracledb 1.0

        Use :data:`~oracledb.AUTH_MODE_SYSDGD` instead.

.. data:: SYSKMT

    This constant is used to specify that SYSKM access is to be acquired.

    .. deprecated:: python-oracledb 1.0

        Use :data:`~oracledb.AUTH_MODE_SYSKMT` instead.

.. data:: SYSOPER

    This constant is used to specify that SYSOPER access is to be acquired.

    .. deprecated:: python-oracledb 1.0

        Use :data:`~oracledb.AUTH_MODE_SYSOPER` instead.

.. data:: SYSRAC

    This constant is used to specify that SYSRAC access is to be acquired.

    .. deprecated:: python-oracledb 1.0

        Use :data:`~oracledb.AUTH_MODE_SYSRAC` instead.

Database Shutdown Modes
-----------------------

These constants are extensions to the DB API definition. They are possible
values for the mode parameter of the :meth:`Connection.shutdown()` method.


.. data:: DBSHUTDOWN_ABORT

    This constant is used to specify that the caller should not wait for
    current processing to complete or for users to disconnect from the
    database. This should only be used in unusual circumstances since database
    recovery may be necessary upon next startup.


.. data:: DBSHUTDOWN_FINAL

    This constant is used to specify that the instance can be truly halted.
    This should only be done after the database has been shutdown with one of
    the other modes (except abort) and the database has been closed and
    dismounted using the appropriate SQL commands.


.. data:: DBSHUTDOWN_IMMEDIATE

    This constant is used to specify that all uncommitted transactions should
    be rolled back and any connected users should be disconnected.


.. data:: DBSHUTDOWN_TRANSACTIONAL

    This constant is used to specify that further connections to the database
    should be prohibited and no new transactions should be allowed. It then
    waits for all active transactions to complete.


.. data:: DBSHUTDOWN_TRANSACTIONAL_LOCAL

    This constant is used to specify that further connections to the database
    should be prohibited and no new transactions should be allowed. It then
    waits for only local active transactions to complete.


Event Types
-----------

These constants are extensions to the DB API definition. They are possible
values for the :attr:`Message.type` attribute of the messages that are sent
for subscriptions created by the :meth:`Connection.subscribe()` method.


.. data:: EVENT_AQ

    This constant is used to specify that one or more messages are available
    for dequeuing on the queue specified when the subscription was created.


.. data:: EVENT_DEREG

    This constant is used to specify that the subscription has been
    deregistered and no further notifications will be sent.


.. data:: EVENT_NONE

    This constant is used to specify no information is available about the
    event.


.. data:: EVENT_OBJCHANGE

    This constant is used to specify that a database change has taken place on
    a table registered with the :meth:`Subscription.registerquery()` method.


.. data:: EVENT_QUERYCHANGE

    This constant is used to specify that the result set of a query registered
    with the :meth:`Subscription.registerquery()` method has been changed.


.. data:: EVENT_SHUTDOWN

    This constant is used to specify that the instance is in the process of
    being shut down.


.. data:: EVENT_SHUTDOWN_ANY

    This constant is used to specify that any instance (when running RAC) is in
    the process of being shut down.


.. data:: EVENT_STARTUP

    This constant is used to specify that the instance is in the process of
    being started up.


.. _cqn-operation-codes:

Operation Codes
---------------

These constants are extensions to the DB API definition. They are possible
values for the operations parameter for the :meth:`Connection.subscribe()`
method. One or more of these values can be OR'ed together. These values are
also used by the :attr:`MessageTable.operation` or
:attr:`MessageQuery.operation` attributes of the messages that are sent.


.. data:: OPCODE_ALLOPS

    This constant is used to specify that messages should be sent for all
    operations.


.. data:: OPCODE_ALLROWS

    This constant is used to specify that the table or query has been
    completely invalidated.


.. data:: OPCODE_ALTER

    This constant is used to specify that messages should be sent when a
    registered table has been altered in some fashion by DDL, or that the
    message identifies a table that has been altered.


.. data:: OPCODE_DELETE

    This constant is used to specify that messages should be sent when data is
    deleted, or that the message identifies a row that has been deleted.


.. data:: OPCODE_DROP

    This constant is used to specify that messages should be sent when a
    registered table has been dropped, or that the message identifies a table
    that has been dropped.


.. data:: OPCODE_INSERT

    This constant is used to specify that messages should be sent when data is
    inserted, or that the message identifies a row that has been inserted.


.. data:: OPCODE_UPDATE

    This constant is used to specify that messages should be sent when data is
    updated, or that the message identifies a row that has been updated.

.. _sesspoolmodes:

Session Pool Get Modes
----------------------

These constants are extensions to the DB API definition. They are possible
values for the getmode parameter of the :meth:`ConnectionPool()` method.


.. data:: SPOOL_ATTRVAL_FORCEGET

    This constant is used to specify that a new connection will be returned if
    there are no free sessions available in the pool.

    .. deprecated:: python-oracledb 1.0

        Use :data:`~oracledb.POOL_GETMODE_FORCEGET` instead.


.. data:: SPOOL_ATTRVAL_NOWAIT

    This constant is used to specify that an exception should be raised if
    there are no free sessions available in the pool. This is the default
    value.

    .. deprecated:: python-oracledb 1.0

        Use :data:`~oracledb.POOL_GETMODE_NOWAIT` instead.


.. data:: SPOOL_ATTRVAL_WAIT

    This constant is used to specify that the caller should wait until a
    session is available if there are no free sessions available in the pool.

    .. deprecated:: python-oracledb 1.0

        Use :data:`~oracledb.POOL_GETMODE_WAIT` instead.


.. data:: SPOOL_ATTRVAL_TIMEDWAIT

    This constant is used to specify that the caller should wait for a period
    of time (defined by the wait_timeout parameter) for a session to become
    available before returning with an error.

    .. deprecated:: python-oracledb 1.0

        Use :data:`~oracledb.POOL_GETMODE_TIMEDWAIT` instead.


Session Pool Purity
-------------------

These constants are extensions to the DB API definition. They are possible
values for the purity parameter of the :meth:`connect()` method, which is used
in database resident connection pooling (DRCP).


.. data:: ATTR_PURITY_DEFAULT

    This constant is used to specify that the purity of the session is the
    default value identified by Oracle (see Oracle's documentation for more
    information). This is the default value.

    .. deprecated:: python-oracledb 1.0

        Use :data:`~oracledb.PURITY_DEFAULT` instead.


.. data:: ATTR_PURITY_NEW

    This constant is used to specify that the session acquired from the pool
    should be new and not have any prior session state.

    .. deprecated:: python-oracledb 1.0

        Use :data:`~oracledb.PURITY_NEW` instead.


.. data:: ATTR_PURITY_SELF

    This constant is used to specify that the session acquired from the pool
    need not be new and may have prior session state.

    .. deprecated:: python-oracledb 1.0

        Use :data:`~oracledb.PURITY_SELF` instead.

.. _connpoolmodes:

Connection Pool Get Modes
-------------------------

These constants are extensions to the DB API definition. They are possible
values for the getmode parameter of the :meth:`ConnectionPool()` method.

.. data:: POOL_GETMODE_FORCEGET

    This constant is used to specify that a new connection will be returned if
    there are no free sessions available in the pool.


.. data:: POOL_GETMODE_NOWAIT

    This constant is used to specify that an exception should be raised if
    there are no free sessions available in the pool. This is the default
    value.


.. data:: POOL_GETMODE_WAIT

    This constant is used to specify that the caller should wait until a
    session is available if there are no free sessions available in the pool.


.. data:: POOL_GETMODE_TIMEDWAIT

    This constant is used to specify that the caller should wait for a period
    of time (defined by the wait_timeout parameter) for a session to become
    available before returning with an error.

Connection Pool Purity
-----------------------

These constants are extensions to the DB API definition. They are possible
values for the purity parameter of the :meth:`connect()` method, which is used
in database resident connection pooling (DRCP).

.. data:: PURITY_DEFAULT

    This constant is used to specify that the purity of the session is the
    default value identified by Oracle (see Oracle's documentation for more
    information). This is the default value.

.. data:: PURITY_NEW

    This constant is used to specify that the session acquired from the pool
    should be new and not have any prior session state.


.. data:: PURITY_SELF

    This constant is used to specify that the session acquired from the pool
    need not be new and may have prior session state.

Subscription Grouping Classes
-----------------------------

These constants are extensions to the DB API definition. They are possible
values for the groupingClass parameter of the :meth:`Connection.subscribe()`
method.

.. data:: SUBSCR_GROUPING_CLASS_TIME

    This constant is used to specify that events are to be grouped by the
    period of time in which they are received.


Subscription Grouping Types
---------------------------

These constants are extensions to the DB API definition. They are possible
values for the groupingType parameter of the :meth:`Connection.subscribe()`
method.

.. data:: SUBSCR_GROUPING_TYPE_SUMMARY

    This constant is used to specify that when events are grouped a summary of
    the events should be sent instead of the individual events. This is the
    default value.

.. data:: SUBSCR_GROUPING_TYPE_LAST

    This constant is used to specify that when events are grouped the last
    event that makes up the group should be sent instead of the individual
    events.


.. _subscr-namespaces:

Subscription Namespaces
-----------------------

These constants are extensions to the DB API definition. They are possible
values for the namespace parameter of the :meth:`Connection.subscribe()`
method.

.. data:: SUBSCR_NAMESPACE_AQ

    This constant is used to specify that notifications should be sent when a
    queue has messages available to dequeue.

.. data:: SUBSCR_NAMESPACE_DBCHANGE

    This constant is used to specify that database change notification or query
    change notification messages are to be sent. This is the default value.


.. _subscr-protocols:

Subscription Protocols
----------------------

These constants are extensions to the DB API definition. They are possible
values for the protocol parameter of the :meth:`Connection.subscribe()` method.

.. data:: SUBSCR_PROTO_CALLBACK

    This constant is used to specify that notifications will be sent to the
    callback routine identified when the subscription was created. It is the
    default value and the only value currently supported.


.. data:: SUBSCR_PROTO_HTTP

    This constant is used to specify that notifications will be sent to an
    HTTP URL when a message is generated. This value is currently not
    supported.


.. data:: SUBSCR_PROTO_MAIL

    This constant is used to specify that notifications will be sent to an
    e-mail address when a message is generated. This value is currently not
    supported.


.. data:: SUBSCR_PROTO_OCI

    This constant is used to specify that notifications will be sent to the
    callback routine identified when the subscription was created. It is the
    default value and the only value currently supported.

    .. deprecated:: python-oracledb 1.0

        Use :data:`~oracledb.SUBSCR_PROTO_CALLBACK` instead.


.. data:: SUBSCR_PROTO_SERVER

    This constant is used to specify that notifications will be sent to a
    PL/SQL procedure when a message is generated. This value is currently not
    supported.


.. _subscr-qos:

Subscription Quality of Service
-------------------------------

These constants are extensions to the DB API definition. They are possible
values for the qos parameter of the :meth:`Connection.subscribe()` method. One
or more of these values can be OR'ed together.

.. data:: SUBSCR_QOS_BEST_EFFORT

    This constant is used to specify that best effort filtering for query
    result set changes is acceptable. False positive notifications may be
    received.  This behaviour may be suitable for caching applications.


.. data:: SUBSCR_QOS_DEREG_NFY

    This constant is used to specify that the subscription should be
    automatically unregistered after the first notification is received.


.. data:: SUBSCR_QOS_QUERY

    This constant is used to specify that notifications should be sent if the
    result set of the registered query changes. By default no false positive
    notifications will be generated.


.. data:: SUBSCR_QOS_RELIABLE

    This constant is used to specify that notifications should not be lost in
    the event of database failure.


.. data:: SUBSCR_QOS_ROWIDS

    This constant is used to specify that the rowids of the inserted, updated
    or deleted rows should be included in the message objects that are sent.


.. _types:

DB API Types
------------

.. data:: BINARY

    This type object is used to describe columns in a database that contain
    binary data. The database types :data:`DB_TYPE_RAW` and
    :data:`DB_TYPE_LONG_RAW` will compare equal to this value. If a variable is
    created with this type, the database type :data:`DB_TYPE_RAW` will be used.


.. data:: DATETIME

    This type object is used to describe columns in a database that are dates.
    The database types :data:`DB_TYPE_DATE`, :data:`DB_TYPE_TIMESTAMP`,
    :data:`DB_TYPE_TIMESTAMP_LTZ` and :data:`DB_TYPE_TIMESTAMP_TZ` will all
    compare equal to this value. If a variable is created with this
    type, the database type :data:`DB_TYPE_DATE` will be used.


.. data:: NUMBER

    This type object is used to describe columns in a database that are
    numbers. The database types :data:`DB_TYPE_BINARY_DOUBLE`,
    :data:`DB_TYPE_BINARY_FLOAT`, :data:`DB_TYPE_BINARY_INTEGER` and
    :data:`DB_TYPE_NUMBER` will all compare equal to this value. If a variable
    is created with this type, the database type :data:`DB_TYPE_NUMBER` will be
    used.


.. data:: ROWID

    This type object is used to describe the pseudo column "rowid". The
    database type :data:`DB_TYPE_ROWID` will compare equal to this value. If a
    variable is created with this type, the database type
    :data:`DB_TYPE_VARCHAR` will be used.


.. data:: STRING

    This type object is used to describe columns in a database that are
    strings. The database types :data:`DB_TYPE_CHAR`, :data:`DB_TYPE_LONG`,
    :data:`DB_TYPE_NCHAR`, :data:`DB_TYPE_NVARCHAR` and :data:`DB_TYPE_VARCHAR`
    will all compare equal to this value. If a variable is created with this
    type, the database type :data:`DB_TYPE_VARCHAR` will be used.


.. _dbtypes:

Database Types
--------------

All of these types are extensions to the DB API definition. They are found in
query and object metadata. They can also be used to specify the database type
when binding data.

.. data:: DB_TYPE_BFILE

    Describes columns, attributes or array elements in a database that are of
    type BFILE. It will compare equal to the DB API type :data:`BINARY`.

    .. note::

        This type is not supported in the python-oracledb Thin mode.

.. data:: DB_TYPE_BINARY_DOUBLE

    Describes columns, attributes or array elements in a database that are of
    type BINARY_DOUBLE. It will compare equal to the DB API type
    :data:`NUMBER`.


.. data:: DB_TYPE_BINARY_FLOAT

    Describes columns, attributes or array elements in a database that are
    of type BINARY_FLOAT. It will compare equal to the DB API type
    :data:`NUMBER`.


.. data:: DB_TYPE_BINARY_INTEGER

    Describes attributes or array elements in a database that are of type
    BINARY_INTEGER. It will compare equal to the DB API type :data:`NUMBER`.


.. data:: DB_TYPE_BLOB

    Describes columns, attributes or array elements in a database that are of
    type BLOB. It will compare equal to the DB API type :data:`BINARY`.


.. data:: DB_TYPE_BOOLEAN

    Describes attributes or array elements in a database that are of type
    BOOLEAN. It is only available in Oracle 12.1 and higher and only within
    PL/SQL.


.. data:: DB_TYPE_CHAR

    Describes columns, attributes or array elements in a database that are of
    type CHAR. It will compare equal to the DB API type :data:`STRING`.

    Note that these are fixed length string values and behave differently from
    VARCHAR2.


.. data:: DB_TYPE_CLOB

    Describes columns, attributes or array elements in a database that are of
    type CLOB. It will compare equal to the DB API type :data:`STRING`.


.. data:: DB_TYPE_CURSOR

    Describes columns in a database that are of type CURSOR. In PL/SQL these
    are knoown as REF CURSOR.


.. data:: DB_TYPE_DATE

    Describes columns, attributes or array elements in a database that are of
    type DATE. It will compare equal to the DB API type :data:`DATETIME`.


.. data:: DB_TYPE_INTERVAL_DS

    Describes columns, attributes or array elements in a database that are of
    type INTERVAL DAY TO SECOND.


.. data:: DB_TYPE_INTERVAL_YM

    Describes columns, attributes or array elements in a database that are of
    type INTERVAL YEAR TO MONTH. This database type is not currently supported
    by python-oracledb.


.. data:: DB_TYPE_JSON

    Describes columns in a database that are of type JSON (with Oracle Database
    21 or later).


.. data:: DB_TYPE_LONG

    Describes columns, attributes or array elements in a database that are of
    type LONG. It will compare equal to the DB API type :data:`STRING`.


.. data:: DB_TYPE_LONG_RAW

    Describes columns, attributes or array elements in a database that are of
    type LONG RAW. It will compare equal to the DB API type :data:`BINARY`.


.. data:: DB_TYPE_LONG_NVARCHAR

    Describes columns, attributes, or array elements in a database that are of
    type LONG NVARCHAR. It will compare equal to the DB API type :data:`STRING`.

.. data:: DB_TYPE_NCHAR

    Describes columns, attributes or array elements in a database that are of
    type NCHAR. It will compare equal to the DB API type :data:`STRING`.

    Note that these are fixed length string values and behave differently from
    NVARCHAR2.


.. data:: DB_TYPE_NCLOB

    Describes columns, attributes or array elements in a database that are of
    type NCLOB. It will compare equal to the DB API type :data:`STRING`.


.. data:: DB_TYPE_NUMBER

    Describes columns, attributes or array elements in a database that are of
    type NUMBER. It will compare equal to the DB API type :data:`NUMBER`.


.. data:: DB_TYPE_NVARCHAR

    Describes columns, attributes or array elements in a database that are of
    type NVARCHAR2. It will compare equal to the DB API type :data:`STRING`.


.. data:: DB_TYPE_OBJECT

    Describes columns, attributes or array elements in a database that are an
    instance of a named SQL or PL/SQL type.

    .. note::

        This type is not supported in python-oracledb Thin mode.


.. data:: DB_TYPE_RAW

    Describes columns, attributes or array elements in a database that are of
    type RAW. It will compare equal to the DB API type :data:`BINARY`.


.. data:: DB_TYPE_ROWID

    Describes columns, attributes or array elements in a database that are of
    type ROWID or UROWID. It will compare equal to the DB API type
    :data:`ROWID`.


.. data:: DB_TYPE_TIMESTAMP

    Describes columns, attributes or array elements in a database that are of
    type TIMESTAMP. It will compare equal to the DB API type :data:`DATETIME`.


.. data:: DB_TYPE_TIMESTAMP_LTZ

    Describes columns, attributes or array elements in a database that are of
    type TIMESTAMP WITH LOCAL TIME ZONE. It will compare equal to the DB API
    type :data:`DATETIME`.


.. data:: DB_TYPE_TIMESTAMP_TZ

    Describes columns, attributes or array elements in a database that are of
    type TIMESTAMP WITH TIME ZONE. It will compare equal to the DB API type
    :data:`DATETIME`.


.. data:: DB_TYPE_VARCHAR

    Describes columns, attributes or array elements in a database that are of
    type VARCHAR2. It will compare equal to the DB API type :data:`STRING`.


.. _dbtypesynonyms:

Database Type Synonyms
----------------------

All of the following constants are deprecated and will be removed in a future
version of python-oracledb.

.. data:: BFILE

    A synonym for :data:`DB_TYPE_BFILE`.

    .. deprecated:: cx_Oracle 8.0


.. data:: BLOB

    A synonym for :data:`DB_TYPE_BLOB`.

    .. deprecated:: cx_Oracle 8.0


.. data:: BOOLEAN

    A synonym for :data:`DB_TYPE_BOOLEAN`.

    .. deprecated:: cx_Oracle 8.0


.. data:: CLOB

    A synonym for :data:`DB_TYPE_CLOB`.

    .. deprecated:: cx_Oracle 8.0

.. data:: CURSOR

    A synonym for :data:`DB_TYPE_CURSOR`.

    .. deprecated:: cx_Oracle 8.0


.. data:: FIXED_CHAR

    A synonym for :data:`DB_TYPE_CHAR`.

    .. deprecated:: cx_Oracle 8.0


.. data:: FIXED_NCHAR

    A synonym for :data:`DB_TYPE_NCHAR`.

    .. deprecated:: cx_Oracle 8.0


.. data:: INTERVAL

    A synonym for :data:`DB_TYPE_INTERVAL_DS`.

    .. deprecated:: cx_Oracle 8.0


.. data:: LONG_BINARY

    A synonym for :data:`DB_TYPE_LONG_RAW`.

    .. deprecated:: cx_Oracle 8.0


.. data:: LONG_STRING

    A synonym for :data:`DB_TYPE_LONG`.

    .. deprecated:: cx_Oracle 8.0


.. data:: NATIVE_FLOAT

    A synonym for :data:`DB_TYPE_BINARY_DOUBLE`.

    .. deprecated:: cx_Oracle 8.0


.. data:: NATIVE_INT

    A synonym for :data:`DB_TYPE_BINARY_INTEGER`.

    .. deprecated:: cx_Oracle 8.0


.. data:: NCHAR

    A synonym for :data:`DB_TYPE_NVARCHAR`.

    .. deprecated:: cx_Oracle 8.0


.. data:: NCLOB

    A synonym for :data:`DB_TYPE_NCLOB`.

    .. deprecated:: cx_Oracle 8.0


.. data:: OBJECT

    A synonym for :data:`DB_TYPE_OBJECT`.

    .. deprecated:: cx_Oracle 8.0


.. data:: TIMESTAMP

    A synonym for :data:`DB_TYPE_TIMESTAMP`.

    .. deprecated:: cx_Oracle 8.0


Other Types
-----------

All of these types are extensions to the DB API definition.

.. data:: ApiType

    This type object is the Python type of the database API type constants
    :data:`BINARY`, :data:`DATETIME`, :data:`NUMBER`, :data:`ROWID` and
    :data:`STRING`.


.. data:: DbType

    This type object is the Python type of the
    :ref:`database type constants <dbtypes>`.


.. data:: LOB

    This type object is the Python type of :data:`DB_TYPE_BLOB`,
    :data:`DB_TYPE_BFILE`, :data:`DB_TYPE_CLOB` and :data:`DB_TYPE_NCLOB` data
    that is returned from cursors.

.. _tpcconstants:

Two-Phase Commit (TPC) Constants
---------------------------------

The constants for the two-phase commit (TPC) functions :meth:`~Connection.tpc_begin()` and :meth:`~Connection.tpc_end()` are listed below.

.. data:: TPC_BEGIN_JOIN

    Joins an existing TPC transaction.

.. data:: TPC_BEGIN_NEW

    Creates a new TPC transaction.

.. data:: TPC_BEGIN_PROMOTE

    Promotes a local transaction to a TPC transaction.

.. data:: TPC_BEGIN_RESUME

    Resumes an existing TPC transaction.

.. data:: TPC_END_NORMAL

    Ends the TPC transaction participation normally.

.. data:: TPC_END_SUSPEND

    Suspends the TPC transaction.

.. _exceptions:

Exceptions
==========

.. exception:: Warning

    Exception raised for important warnings and defined by the DB API but not
    actually used by python-oracledb.


.. exception:: Error

    Exception that is the base class of all other exceptions defined by
    python-oracledb and is a subclass of the Python StandardError exception (defined
    in the module exceptions).


.. exception:: InterfaceError

    Exception raised for errors that are related to the database interface
    rather than the database itself. It is a subclass of Error.


.. exception:: DatabaseError

    Exception raised for errors that are related to the database. It is a
    subclass of Error.


.. exception:: DataError

    Exception raised for errors that are due to problems with the processed
    data. It is a subclass of DatabaseError.


.. exception:: OperationalError

    Exception raised for errors that are related to the operation of the
    database but are not necessarily under the control of the programmer. It is
    a subclass of DatabaseError.


.. exception:: IntegrityError

    Exception raised when the relational integrity of the database is affected.
    It is a subclass of DatabaseError.


.. exception:: InternalError

    Exception raised when the database encounters an internal error. It is a
    subclass of DatabaseError.


.. exception:: ProgrammingError

    Exception raised for programming errors. It is a subclass of DatabaseError.


.. exception:: NotSupportedError

    Exception raised when a method or database API was used which is not
    supported by the database. It is a subclass of DatabaseError.


.. _exchandling:

Exception handling
==================

.. note::

    PEP 249 (Python Database API Specification v2.0) says the following about
    exception values:

        [...] The values of these exceptions are not defined. They should
        give the user a fairly good idea of what went wrong, though. [...]

    With python-oracledb every exception object has exactly one argument in the
    ``args`` tuple. This argument is a ``oracledb._Error`` object which has
    the following five read-only attributes.

.. attribute:: _Error.code

    Integer attribute representing the Oracle error number (ORA-XXXXX).

.. attribute:: _Error.offset

    Integer attribute representing the error offset when applicable.

.. attribute:: _Error.full_code

    String attribute representing the top-level error prefix and the
    code that is shown in the :attr:`_Error.message`.

.. attribute:: _Error.message

    String attribute representing the Oracle message of the error. This
    message is localized by the environment of the Oracle connection.

.. attribute:: _Error.context

    String attribute representing the context in which the exception was
    raised.

.. attribute:: _Error.isrecoverable

    Boolean attribute representing whether the error is recoverable or not.
    This is False in all cases unless both Oracle Database 12.1 (or later) and
    Oracle Client 12.1 (or later) are being used.

This allows you to use the exceptions for example in the following way:

::

    import oracledb

    connection = oracledb.connect("oracledb/dev@localhost/orclpdb1")
    cursor = connection.cursor()

    try:
        cursor.execute("select 1 / 0 from dual")
    except oracledb.DatabaseError as exc:
        error, = exc.args
        print("Oracle-Error-Code:", error.code)
        print("Oracle-Error-Full-Code:", error.full_code)
        print("Oracle-Error-Message:", error.message)

This will print::

    Oracle-Error-Code: 1476
    Oracle-Error-Full-Code: ORA-01476
    Oracle-Error-Message: ORA-01476: divisor is equal to zero
