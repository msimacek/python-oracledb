.. _connconfig:

*************************************************************************
Connection and Connection Configuration in python-oracledb Thick and Thin
*************************************************************************

Each python-oracledb process can create connections in Thick or Thin mode, however only one mode can be used.

* If :func:`oracledb.init_oracle_client()` is called in the application before any standalone connection or pool is created, then the mode becomes Thick.
* If an application creates a standalone connection or pool before calling :func:`oracledb.init_oracle_client()`, then the mode becomes Thin.
* If an application opens a connection or creates a pool and then calls :func:`oracledb.init_oracle_client()`, an error will occur.

Once a mode has been established, either by calling :func:`oracledb.init_oracle_client()` or opening connections, then the mode cannot be changed.

.. _syntax:

Connection Syntax
=================

The :func:`oracledb.connect()`, :func:`oracledb.ConnectionPool()`, and :func:`oracledb.SessionPool()` functions support several ways of passing parameters which are listed below.

* Using the ConnectParams Class object:

  .. code-block:: python

     params = oracledb.ConnectParams(host="my_host", port=my_port, service_name="my_service_name")
     conn = oracledb.connect(user="my_user", password="my_password", params=params)

  Although cx_Oracle.makedsn() can still be used, and a dsn can be passed for connection, the Thin driver can alternatively make use of the ConnectParams Class. For example, optionally change:

  .. code-block:: python

    dsn = cx_Oracle.makedsn('my_host', my_port, service_name='my_service_name')
    c = cx_Oracle.connect(user='my_user', password='my_password', dsn=dsn)

  to:

  .. code-block:: python
    
    params = oracledb.ConnectParams(host="my_host", port=my_port, service_name="my_service_name")
    c = oracledb.connect(user='my_user', password='my_password', params=params)

* Using the `keyword` parameter approach mandated by the Python Database API and generally used by frameworks (which depend on the Python Database API):

  .. code-block:: python

    conn = oracledb.connect(user="my_user", password="my_password", host="my_host", port=my_port, service_name="my_service_name")

  Any of the parameters to oracledb.ConnectParams() may be also be passed to oracledb.connect(), oracledb.ConnectionPool() and oracledb.SessionPool(). Note that some parameters may be ignored at connection time, based on whether python-oracledb is in Thin or Thick mode.

* Using the the `dsn` parameter which contains a string representation of the connection parameters which is an alternative method suggested by the Python Database API:

  .. code-block:: python

    conn = oracledb.connect(user="my_user", password="my_password", dsn="my_host:my_port/my_service_name")

  Alternatively, the user and password can also be encoded in the dsn parameter.

  .. code-block:: python

    conn = oracledb.connect("my_user/my_password@my_host:my_port/my_service_name")

  .. note::
    * If the `params` parameter is specified and `keyword` parameters are also specified, then the `params` parameter is updated with the values from the `keyword` parameters before being used to create the connection.
    * If the `dsn` parameter is specified and the `params` parameter is specified, then the `params` parameter is updated with the contents of the `dsn` parameter before being used to create the connection.

.. _connmig:

Connection Migration
====================

The parameters of the :func:`oracledb.connect()` and :func:`oracledb.SessionPool()` are now keyword and not positional. This change makes the driver compliant with the Python Database API spec PEP 249.

.. _sqlnetclientconfig:

SQL*Net and Client Configuration Files
======================================

python-oracledb Thin:

* Will read tnsnames.ora files. The directory can be set through:
  - The TNS_ADMIN environment variable.
  - The oracledb.default.config_dir property (which defaults to $TNS_ADMIN)
  - By passing config_dir when creating the connection or pool, or by passing config_dir to ConnectParams().
 
 Traditional default file locations such as the Instant Client network/admin/ subdirectory, $ORACLE_HOME/network/admin/, or $ORACLE_BASE/homes/XYZ/network/admin/ (in a read-only Oracle Database home) will not be automatically used by the Thin driver. (JDBC-thin also doesn't use these locations).

* Will not read sqlnet.ora files. Instead, use Oracledb.defaults and/or oracledb.ConnectParams().
* Will not support oraaccess.xml

Connection Strings
==================

python-oracledb Thin mode accepts connection strings in the same formats as the Thick mode, but not all Oracle Net keywords will be supported. The accepted formats are:

 * Easy Connect Strings
 * Full Connect Descriptor Strings
 * Oracle Net Service names

See :ref:`connstr` for more information on connection strings.

The following table lists the parameters that are recognized in Thin mode either as Easy Connect Strings or Full Connect Descriptor Strings that are explicitly passed or referred to by a ``tnsnames.ora`` alias. All unrecognized parameters are ignored.

.. list-table-with-summary::  Oracle Net Keywords Supported by python-oracledb Thin Driver
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
      - Parsing the parameter supports case insensitive on/yes/true values (similar to the Thick driver and cx_Oracle). Anything else is treated as disabling it.
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
  
The ConnectParams class allows other values to be set for the python-oracledb Thin driver.

If a name is given as a connect string, then the python-oracledb Thin driver will consider it as a Net Service Name and not as the minimal Easy Connect string of a hostname. The given connect string will be looked up in a tnsnames.ora file. This is different from the python-oracledb Thick driver. The workaround in the python-oracledb Thin driver include using the port number such as hostname:1521 or a protocol such as tcp://hostname.

To identify which Oracle Net connect descriptor parameters are used or ignored by the python-oracledb Thin driver, create a ConnectParams Class object with the desired connect string. If attributes are not shown in the object, then they have been ignored. Note that even if they are shown, the values may not be used at connection, depending whether python-oracledb is in Thin or Thick mode.

Transport Layer Security (TLS) Support
======================================

Users have to use OS level controls to limit Transport Layer Security (TLS) versions. For example, see `Hardening TLS Configuration <https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/security_guide/sec-hardening_tls_configuration>`__.

One-way TLS
-----------

The python-oracledb Thin driver supports one-way TLS. Note that Oracle Cloud Autonomous Database (ADB) now supports one-way TLS so wallets are no longer mandatory.

The python-oracledb Thick driver, cx_Oracle, and any Oracle Call Interface (OCI) based app) support one-way TLS when using Oracle Client libraries from 19.14 and 21.5.

Two-way TLS/Mutual TLS
----------------------

For the python-oracledb Thick driver, two-way TLS such as for Oracle Cloud wallets can be used similarly to cx_Oracle.

For the python-oracledb Thin driver, the user must create a Privacy Enhanced Mail (PEM) file. Oracle Cloud users who do not wish to move to using one-way TLS need to convert the Wallet PKCS12 ewallet.p12 file to PEM format using third party tools or the script below. A password is optional, depending on whether the wallet is encrypted or not.

The thin driver functions :func:`oracledb.connect()`, :func:`oracledb.ConnectionPool()`, and :func:`oracledb.SessionPool()` take wallet_location and wallet_password parameters, see :ref:`connparam`.

The following is a sample script that converts a PKCS#12 encoded file found in Oracle Cloud wallet zip files to the PEM encoded file that the python-oracledb Thin driver expects.

.. code-block:: python

    import argparse
    import getpass
    import os

    from cryptography.hazmat.primitives.serialization \
            import pkcs12, Encoding, PrivateFormat, BestAvailableEncryption, \
                   NoEncryption

    # parse command line
    parser = argparse.ArgumentParser(description="convert PKCS#12 to PEM")
    parser.add_argument("wallet_location",
                        help="the directory in which the PKCS#12 encoded "
                             "wallet file ewallet.p12 is found")
    parser.add_argument("--wallet-password",
                        help="the password for the wallet which is used to "
                             "decrypt the PKCS#12 encoded wallet file; if not "
                             "specified, it will be requested securely")
    parser.add_argument("--no-encrypt",
                        dest="encrypt", action="store_false", default=True,
                        help="do not encrypt the converted PEM file with the "
                             "wallet password")
    args = parser.parse_args()

    # validate arguments and acquire password if one was not specified
    pkcs12_file_name = os.path.join(args.wallet_location, "ewallet.p12")
    if not os.path.exists(pkcs12_file_name):
        msg = f"wallet location {args.wallet_location} does not contain " \
               "ewallet.p12"
        raise Exception(msg)
    if args.wallet_password is None:
        args.wallet_password = getpass.getpass()

    pem_file_name = os.path.join(args.wallet_location, "ewallet.pem")
    pkcs12_data = open(pkcs12_file_name, "rb").read()
    result = pkcs12.load_key_and_certificates(pkcs12_data,
                                              args.wallet_password.encode())
    private_key, certificate, additional_certificates = result
    if args.encrypt:
        encryptor = BestAvailableEncryption(args.wallet_password.encode())
    else:
        encryptor = NoEncryption()
    with open(pem_file_name, "wb") as f:
        f.write(private_key.private_bytes(Encoding.PEM, PrivateFormat.PKCS8,
                                          encryptor))
        f.write(certificate.public_bytes(Encoding.PEM))
        for cert in additional_certificates:
            f.write(cert.public_bytes(Encoding.PEM))
    print("PEM file", pem_file_name, "written.")

Native Network Encryption
=========================

The python-oracledb Thin driver does not support Oracle Native Network Encryption in python-oracledb 1.0 release.

Password Verifiers
==================

The python-oracledb Thin driver supports multi-round hashing algorithms for the 11g (SHA1) and 12c (SHA512) verifiers.

SQLNET.ALLOWED_LOGON_VERSION is not be supported in python-oracledb 1.0 release.