.. _poolparam:

***********************
API: PoolParams Object
***********************

A new PoolParams class is introduced in python-oracledb, which is a subclass of
:ref:`ConnectParams Class <connparam>`. In addition to the parameters and
attributes of the ConnectParams class, the PoolParams class also contains new 
parameters and attributes.

For example:

.. code-block:: python

  pp = oracledb.PoolParams(min=1, max=2, increment=1)
  p = oracledb.create_pool(user=un, password=pw, dsn=cs, params=pp)

All arguments are gettable as properties. These arguments can be set individually 
using :meth:`ConnectParams.set()`.

.. code-block:: python

    pp = oracledb.PoolParams()
    pp.set(min=5)
    print(pp.min) # 5

.. _poolparamsattr:

Attributes
===========

.. attribute:: PoolParams.connectiontype

  This read-only attribute specifies the class of the connection that should
  be returned during calls to :meth:`ConnectionPool.acquire()`. It must be Connection
  or a subclass of Connection. This attribute is of type Type["oracledb.connection"].
  The default value is ``oracledb.Connection``.

  This attribute is supported in the python-oracledb Thin and Thick modes.

.. attribute:: PoolParams.externalauth

  This read-only attribute is a boolean that indicates whether the pool
  uses external authentication to connect to the database. The default value 
  is False.

  This attribute is only supported in the python-oracledb Thick mode.

.. attribute:: PoolParams.getmode

  This read-write attribute is an integer that determines the behavior of 
  :meth:`ConnectionPool.acquire()`. The value of this attribute can be one of the 
  constants :data:`oracledb.POOL_GETMODE_WAIT`, :data:`oracledb.POOL_GETMODE_NOWAIT`,
  :data:`oracledb.POOL_GETMODE_FORCEGET`, or :data:`oracledb.POOL_GETMODE_TIMEDWAIT`.
  The default value is :data:`oracledb.POOL_GETMODE_WAIT`.

  This attribute is supported in the python-oracledb Thin and Thick modes.

.. attribute:: PoolParams.homogeneous

  This read-only attribute is a boolean which indicates whether the connections are 
  homogeneous (same user) or heterogeneous (multiple users). The default value 
  is True.

  This attribute is only supported in the python-oracledb Thick mode. The python-oracledb 
  Thin mode supports only homogeneous modes.

.. attribute:: PoolParams.increment

  This read-only attribute specifies the number of connections that should
  be added to the pool whenever a new connection needs to be created. The 
  default value is 1.

  This attribute is supported in the python-oracledb Thin and Thick modes.

.. attribute:: PoolParams.min

  This read-only attribute is an integer that specifies the mininum number of 
  connections that the pool should contain. The default value is 1.

  This attribute is supported in the python-oracledb Thin and Thick modes.

.. attribute:: PoolParams.max

  This read-only attribute specifies the maxinum number of connections that 
  the pool should contain. The default value is 2.

  This attribute is supported in the python-oracledb Thin and Thick modes.

.. attribute:: PoolParams.max_lifetime_session

  This read-only attribute is an integer that determines the length of time 
  (in seconds) that connections can remain in the pool. If the value of this 
  attribute is 0, then the connections may remain in the pool indefinitely.
  The default value is 0 seconds.

  This attribute is only supported in the python-oracledb Thick mode.

.. attribute:: PoolParams.max_sessions_per_shard

  This read-only attribute is an integer that determines the maximum number of 
  connections that may be associated with a particular shard. The default value
  is 0.

  This attribute is only supported in the python-oracledb Thick mode.

.. attribute:: PoolParams.ping_interval

  This read-only attribute is an integer that specifies the length of time 
  (in seconds) after which an unused connection in the pool will be a 
  candidate for pinging when :meth:`ConnectionPool.acquire()` is called. 
  If the ping to the database indicates that the connection is not alive,
  then a replacement connection will be returned by :meth:`ConnectionPool.acquire()`. 
  If the ``ping_interval`` is a negative value, then the ping functionality
  will be disabled. The default value is 60 seconds.

  This attribute is supported in the python-oracledb Thin and Thick modes.

.. attribute:: PoolParams.session_callback

  This read-only attribute specifies a callback that is invoked when 
  a connection is returned from the pool for the first time, or when the 
  connection tag differs from the one requested.

  This attribute is supported in the python-oracledb Thin and Thick modes.

.. attribute:: PoolParams.soda_metadata_cache

  This read-only attribute is a boolean that indicates whether 
  SODA metadata cache should be enabled or not. The default value is False.

  This attribute is only supported in the python-oracledb Thick mode.

.. attribute:: PoolParams.timeout

  This read-only attribute is an integer that specifies the length of time 
  (in seconds) that a connection may remain idle in the pool before it is 
  terminated. If the value of this attribute is 0, then the connections are 
  never terminated. The default value is 0 seconds.

  This attribute is only supported in the python-oracledb Thick mode.
  
.. attribute:: PoolParams.wait_timeout

  This read-only attribute is an integer that specifies the length of time 
  (in milliseconds) that a caller should wait when acquiring a connection 
  from the pool with :attr:`~PoolParams.getmode` set to 
  :data:`~oracledb.POOLGETMODE_TIMEDWAIT`. The default value is 0 milliseconds.

  This attribute is supported in the python-oracledb Thin and Thick modes.
