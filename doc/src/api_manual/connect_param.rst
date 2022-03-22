.. _connparam:

********************
ConnectParams Object
********************

.. note::

    This object is an extension to the DB API.


:func:`oracledb.ConnectParams()` is a connection property builder function that returns a `ConnectParams` object. The object can be passed to :func:`oracledb.connect()`, :func:`oracledb.ConnectionPool()`, or :func:`oracledb.SessionPool()`, see :ref:`syntax`.

The ``ConnectParams()`` adds support for connection parameters, facilitating:

- Documentation: A single documentation place for the description of all of these parameters.

- Ease of use: Users can define connection parameters in one place.

The use of ``ConnectParams()`` is optional. You can continue to use previous
approaches, see :ref:`syntax`.

Example:

.. code-block:: python

    params = oracledb.ConnectParams(host="my_host", port=1521,
                                    service_name="my_service_name")
    conn = oracledb.connect(user="my_user", password="my_password",
                            params=params)


.. note::

  - If the ``params`` parameter is specified and keyword parameters are specified, then the ``params`` parameter is updated with the values from the keyword parameters before being used to create the connection.

  - If the ``dsn`` parameter is specified and the ``params`` parameter is specified, then the ``params`` parameter is updated with the contents of the ``dsn`` parameter before being used to create the connection.


Parameters Supported by ``ConnectParams()``
--------------------------------------------

The following values can be set by :func:`oracledb.ConnectParams()` (see
``src/oracledb/connect_params.py`` for descriptions). These can also be passed
to :func:`oracledb.connect()`, :func:`oracledb.ConnectionPool()`, and :func:`oracledb.SessionPool()`.

.. list-table-with-summary:: ConnectParams() parameters
    :header-rows: 1
    :widths: 20 10 10 40
    :name: ConnectParams
    :summary: The first column is the Parameter name. The second column is the data type. The third column indicates the driver supported. The fourth column is the default value. 

    * - Name
      - Type
      - Supported By
      - Default
    * - host
      - str
      - Thin
      - None
    * - port
      - int
      - Thin
      - oracledb.defaults.port
    * - service_name
      - str
      - Thin
      - None
    * - sid
      - str
      - Thin
      - None
    * - events
      - bool
      - Thick
      - oracledb.defaults.events
    * - protocol
      - str
      - Thin
      - "tcp"
    * - server_type
      - str
      - Thin
      - None
    * - config_dir
      - str
      - Thin and Thick
      - oracledb.defaults.config_dir
    * - cclass
      - str
      - Thin and Thick
      - None
    * - purity
      - int
      - Thin and Thick
      - constants.PURITY_DEFAULT
    * - mode
      - int
      - Thin and Thick
      - constants.AUTH_MODE_DEFAULT
    * - edition
      - str
      - Thin and Thick
      - None
    * - appcontext
      - list
      - Thick
      - None
    * - tag
      - str
      - Thick
      - None
    * - matchanytag
      - bool
      - Thick
      - False
    * - shardingkey
      - list
      - Thick
      - None
    * - supershardingkey
      - list
      - Thick
      - None
    * - stmtcachesize
      - int
      - Thin and Thick
      - oracledb.defaults.stmtcachesize
    * - disable_oob
      - bool
      - Thin
      - oracledb.defaults.disable_oob
    * - ssl_server_dn_match
      - bool
      - Thin
      - oracledb.defaults.ssl_server_dn_match
    * - ssl_server_cert_dn
      - str
      - Thin
      - None (If specified, this value is used for any verification. Otherwise, the hostname will be used.)
    * - retry_count
      - int
      - Thin
      - 0
    * - retry_delay
      - int
      - Thin
      - 0
    * - expire_time
      - int
      - Thin
      - 0
    * - tcp_connect_timeout
      - float
      - Thin
      - oracledb.defaults.tcp_connect_timeout
    * - wallet_location
      - str
      - Thin
      - None
    * - wallet_password
      - str
      - Thin
      - None
    * - https_proxy
      - str
      - Thin
      - None
    * - https_proxy_port
      - int
      - Thin
      - None


.. method:: ConnectParams._get_tnsnames_file()

    Returns a tnsnames file, if one is present, or None if one is not. If
    the file was previously loaded, the modification time is checked and,
    if unchanged, the previous file is returned.

.. method:: ConnectParams._parse_time_value(value)
    
    Parses a value that contains time with an optional unit of 
    milliseconds (ms), seconds (sec), or minutes (min).

.. method:: ConnectParams._set_by_keyword_args(keyword_args):
    
    Sets parameters provided as keyword arguments. If a keyword parameter is
    supplied that is not a valid connection parameter, a TypeError
    exception is raised.

.. method:: ConnectParams._set_protocol(protocol):
    
    Sets the specified protocol. Only tcp and tcps protocols are supported
    at this time.

.. method:: ConnectParams._supports_oob():
  
    Returns a boolean indicating if the platform supports out-of-band urgent
    data (all platforms besides Windows) and a configuration parameter
    has not explicitly disabled it.

.. method:: ConnectParams.copy()

    Creates a copy of the parameters and returns it.

.. method:: ConnectParams.parse_connect_string(connect_string)
    
    Parses the connect string into its components and store the parameters.
    The connect string could be an EZConnect string, name-value pairs or a
    simple alias which is looked up in tnsnames.ora. Any connect parameters
    found in the connect string override any currently stored values.

.. method:: ConnectParams.parse_dsn(dsn)

    Parses a dsn (data source name) string supplied by the user. This can be
    in the form user/password@connect_string or it can be the connect
    string by itself. A 3-tuple is returned containing the user, password,
    and connect string.