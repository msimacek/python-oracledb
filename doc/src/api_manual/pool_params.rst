.. _poolparam:

******************
PoolParams Object
******************

.. _poolparamsattr:

Attributes
===========

.. attribute:: PoolParams.connectiontype

  This read-write attribute specifies the class of the connection that should
  be returned during calls to ``pool.acquire``. It must be Connection or a 
  subclass of Connection.
  
  The default value is ``oracledb.Connection``.

.. attribute:: PoolParams.externalauth

  This read-write attribute is a boolean that indicates whether the pool
  uses external authentication to connect to the database.

  The default value is False.

.. attribute:: PoolParams.getmode

  This read-write attribute determines the behavior of ``pool.acquire``.
  These :ref:`modes <connpoolmodes>` can be used when getting connections
  from the pool.
  
  The default value is :data:`oracledb.POOL_GETMODE_WAIT`.

.. attribute:: PoolParams.homogeneous

  This read-write attribute indicates whether the connections are 
  homogeneous (same user) or heterogeneous (multiple users).

  The default value is True.

.. attribute:: PoolParams.increment

  This read-write attribute specifies the number of connections that should
  be added to the pool whenever a new connection needs to be created.

  The default value is 1.

.. attribute:: PoolParams.min

  This read-write attribute specifies the mininum number of connections that 
  the pool should contain.

  The default value is 1.

.. attribute:: PoolParams.max

  This read-write attribute specifies the maxinum number of connections that 
  the pool should contain.

  The default value is 2.

.. attribute:: PoolParams.max_lifetime_session

  This read-write attribute determines the length of time (in seconds) that 
  connections can remain in the pool. If the value of this attribute is 0, 
  then the connections may remain in the pool indefinitely.

  The default value is 0 seconds.

.. attribute:: PoolParams.max_sessions_per_shard

  This read-write attribute determines the maximum number of connections that
  may be associated with a particular shard.

  The default value is 0.

.. attribute:: PoolParams.ping_interval

  This read-write attribute specifies the length of time (in seconds) after 
  which an unused connection in the pool will be a candidate for pinging 
  when ``pool.acquire()`` is called. 
  
  If the ping to the database indicates that the connection is not alive,
  then a replacement connection will be returned by ``pool.acquire()``. 
  If the ``ping_interval`` is a negative value, then the ping functionality
  will be disabled.

  The default value is 60 seconds.

.. attribute:: PoolParams.session_callback

  This read-write attribute specifies a callback that is invoked when 
  a connection is returned from the pool for the first time, or when the 
  connection tag differs from the one requested.

.. attribute:: PoolParams.soda_metadata_cache

  This read-write attribute is a boolean that indicates whether 
  SODA metadata cache should be enabled or not.

  The default value is False.

.. attribute:: PoolParams.timeout

  This read-write attribute specifies the length of time (in seconds) that a
  connection may remain idle in the pool before it is terminated. If the value of
  this attribute is 0, then the connections are never terminated.

  The default value is 0 seconds.
  
.. attribute:: PoolParams.wait_timeout

  This read-write attribute specifies the length of time (in milliseconds) that a
  caller should wait when acquiring a connection from the pool with
  :attr:`~PoolParams.getmode` set to :data:`~oracledb.POOLGETMODE_TIMEDWAIT`.

  The default value is 0 milliseconds.