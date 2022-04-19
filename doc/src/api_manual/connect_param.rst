.. _connparam:

**************************
API: ConnectParams Object
**************************

.. note::

    This object is an extension to the DB API.


The function :func:`oracledb.ConnectParams()` is a connection property builder function 
that returns a `ConnectParams` object. The object can be passed to :func:`oracledb.connect()`, 
:func:`oracledb.create_pool()`, or :func:`oracledb.SessionPool()`, see :ref:`syntax`.

The ``ConnectParams()`` adds support for connection parameters by facilitating:

- The setting of network parameters in python-oracledb Thin mode

- A single documentation place for the description of all of these parameters

- A single place for users to define connection parameters

The use of ``ConnectParams()`` is optional. You can continue to use the previous
approaches, see :ref:`syntax`. In some cases, ``ConnectParams()`` is required since
it replaces the use of sqlnet.ora in python-oracledb Thin mode.

The following examples show how to use the :func:`oracledb.ConnectParams()` function:

.. code-block:: python

    # Example 1

    params = oracledb.ConnectParams(user="my_user", password="my_password",
                                    host="my_host", port=my_port,
                                    service_name="my_service_name")
    conn = oracledb.connect(params=params)

    # Example 2

    params = oracledb.ConnectParams(host="my_host", port=my_port,
                                    service_name="my_service_name")
    dsn = cp.get_connect_string()
    conn = oracledb.connect(user="my_user", password="my_password", dsn=dsn)

Some of the values are settable or gettable as attributes.  The following example shows 
how to set the user as an attribute:

.. code-block:: python

    p = oracledb.ConnectParams(password="my_password", host="localhost",
                               service_name="orclpdb1", port=1521)
    p.user = "my_user"
    connection = oracledb.connect(params=p)

.. _connparamsmeth:

Methods
=======

.. method:: ConnectParams.copy()

  Creates a copy of the parameters and returns it.

.. method:: ConnectParams.get_connect_string()

  Returns the connection string associated with the ConnectParams instance.
  
  The connection string that is returned can either be the connect string passed to the
  :meth:`ConnectParams.parse_dsn()` method or :meth:`ConnectParams.parse_connect_string()`, or
  it can be a connect string that was generated from the individual components that
  were passed when the parameters object was created.

.. method:: ConnectParams.parse_connect_string(connect_string=None)

  Parses a connect string into its components and stores the parameters in the
  ConnectParams instance.  
  
  The connect string can be an Easy Connect string, name-value pairs, or a simple alias 
  which is looked up in tnsnames.ora. Any parameters found in the connect string override 
  any currently stored values. The connect string itself will also be retained.

.. _connparamsattr:

Attributes
===========

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