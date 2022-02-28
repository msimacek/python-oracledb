.. _statementcache:

******************
Statement Caching
******************

Statement caching lets cursors be used without re-parsing the statement. Each cached statement will retain its cursor. Statement caching also reduces meta data transfer costs between python-oracledb and the database. Performance and scalability are improved.

Each non-pooled connection and each session in the connection pool has its own cache of statements with a default size of 30. The cache key is the statement string. This means a single cache entry can be reused when a statement is re-executed with different bind variable values.

The statement cache removes the need for the separate ``prepare`` or ``parse`` methods which are sometimes seen in other Oracle APIs: there is no separate method in python-oracledb.

Setting the Statement Cache
============================

The statement cache size can be set globally with oracledb.stmtCacheSize:

.. code-block:: python

    oracledb.stmtCacheSize = 40;

The value can be overridden in an oracledb.getConnection() call, or when creating a pool with oracledb.createPool(). For example:


.. code-block:: python

    <example to be added>

When using Oracle Client 21 (or later), changing the cache size with pool.reconfigure() does not immediately affect connections previously acquired and currently in use. When those connections are subsequently released to the pool and re-acquired, they will then use the new value. When using Oracle Client prior to version 21, changing the pool’s statement cache size has no effect on connections that already exist in the pool but will affect new connections that are subsequently created, for example when the pool grows.

Tuning the Statement Cache
===========================

In general, set the statement cache to the size of the working set of statements being executed by the application. SODA internally makes SQL calls, so tuning the cache is also beneficial for SODA applications.

With Oracle Client Libraries 12c, or later, the statement cache size can be automatically tuned with the Oracle Client Configuration oraaccess.xml file.

For manual tuning use views like V$SYSSTAT:

.. code-block:: sql

    SELECT value FROM V$SYSSTAT WHERE name = 'parse count (total)'

Find the value before and after running application load to give the number of statement parses during the load test. Alter the statement cache size and repeat the test until you find a minimal number of parses.

If you have Automatic Workload Repository (AWR) reports you can monitor general application load and the “bytes sent via SQL*Net to client” values. The latter statistic should benefit from not shipping statement metadata to python-oracledb. Adjust the statement cache size and re-run the test to find the best cache size.

Disabling the Statement Cache
==============================

Individual statements can be excluded from the statement cache by setting the attribute keepInStmtCache to false. This will prevent a rarely executed statement from flushing a potential more frequently executed one from a full cache. For example, if a statement will only ever be executed once:

.. code-block:: python

    <example here>

Statement caching can be disabled completely by setting the cache size to 0:

.. code-block:: python

    oracledb.stmtCacheSize = 0;

Disabling the cache may be beneficial when the quantity or order of statements causes cache entries to be flushed before they get a chance to be reused. For example, if there are more distinct statements than cache slots and the order of statement execution causes older statements to be flushed from the cache before they are re-executed.

Disabling the statement cache may also be helpful in test and development environments. The statement cache can become invalid if connections remain open and database schema objects are recreated. This can also happen when a connection uses identical query text with different ``fetchAsString`` or ``fetchInfo`` data types. Applications can receive errors such as ORA-3106. After a statement execution error is returned once to the application, python-oracledb automatically drops that statement from the cache. This lets subsequent re-executions of the statement on that connection to succeed.


