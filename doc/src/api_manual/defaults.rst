.. _defaults:

*********************
API: Defaults Object
*********************

The defaults object contains attributes that can be used to adjust the 
default behavior of the python-oracledb driver.

The attributes that are not supported in the Thin or Thick mode, will be 
ignored in that particular mode.


Attributes
----------

.. attribute:: arraysize

    The default value for :attr:`Cursor.arraysize`. This is a query tuning 
    attribute.

    This attribute is supported in the python-oracledb Thin and Thick modes 
    and has an initial value of 100.

.. attribute:: config_dir

    The directory in which configuration files such as tnsnames.ora are found 
    by default. 
    
    If the ``TNS_ADMIN`` environment variable is not set, then the default value 
    is None in the python-oracledb Thin mode and no tnsnames.ora file will be usable 
    until the attribute value is changed. If this attribute is None in the 
    python-oracledb Thick mode, then the usual Oracle Client search path behavior 
    for configuration files is used. This is described in the cx_Oracle documentation 
    and the Oracle Client library documentation.

    This attribute is supported in the python-oracledb Thick and Thin modes and has an 
    initial value of ``os.environ.get("TNS_ADMIN")``.

.. attribute:: fetch_decimals

    Identifies whether numbers should be fetched as ``decimal.Decimal`` values. 
    This can help avoid issues with converting numbers from Oracle Database's 
    decimal format to Python's binary format. 
    
    An output type handler such as the one currently used in cx_Oracle 
    (see `return_numbers_as_decimals.py <https://github.com/oracle/python-cx_Oracle/
    blob/main/samples/return_numbers_as_decimals.py>`__) can alternatively be used 
    to adjust the returned type. If a type handler exists and returns a variable 
    (that is, `cursor.var(...)`), then that return variable is used. If the type 
    handler returns None, then the value of ``oracledb.defaults.fetch_decimals`` 
    is used.

    This attribute is supported in the python-oracledb Thin and Thick modes and 
    has an initial value of False.

.. attribute:: fetch_lobs

    When the value of this attribute is True, then queries to LOB columns return 
    LOB locators. When the value of this attribute is False, then strings or bytes 
    are fetched. If LOBs are larger than 1 GB, then this attribute should be set to 
    True and the LOBs should be streamed. 
    
    An output type handler such as the one currently used in cx_Oracle (see 
    `return_lobs_as_strings.py <https://github.com/oracle/python-cx_Oracle/blob/main/samples/
    return_lobs_as_strings.py>`__) can alternatively be used to adjust the returned type. 
    If a type handler exists and returns a variable (that is, `cursor.var(...)`), then 
    that return variable is used. If the type handler returns None, then the value of 
    ``oracledb.defaults.fetch_lobs`` is used.

    This attribute is supported in the python-oracledb Thin and Thick modes and 
    has an initial value of True.

.. attribute:: prefetchrows

    The default value for :attr:`Cursor.prefetchrow`. This is a query tuning attribute.

    This attribute is supported in the python-oracledb Thin and Thick modes and 
    has an initial value of 2.

.. attribute:: stmtcachesize

    The default value for :attr:`Connection.stmtcachesize`, 
    :attr:`ConnectionPool.stmtcachesize`, and :attr:`SessionPool.stmtcachesize`. This is a 
    tuning attribute.

    This attribute is supported in the python-oracledb Thin and Thick modes and has 
    an initial value of 20.