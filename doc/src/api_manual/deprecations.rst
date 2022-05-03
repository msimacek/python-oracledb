.. _deprecations:

************
Deprecations
************

The following tables contains all of the deprecations in the python-oracledb API,
when they were first deprecated and a comment on what should be used instead,
if applicable. The most recent deprecations are listed first.


.. list-table-with-summary:: Deprecated in python-oracledb 1
    :header-rows: 1
    :widths: 25 75
    :width: 100%
    :summary: The first column, Name, displays the deprecated API name. The second column, Comments, includes information about when the API was deprecated and what API to use, if applicable.
    :name: _deprecations_1

    * - Name
      - Comments
    * - The :ref:`sesspool` and function :meth:`~oracledb.SessionPool()`
      - Replace by :ref:`connpool` and function  :meth:`~oracledb.ConnectionPool()`
    * - :meth:`Connection.begin()`
      - Replace by the new :ref:`tcp` functionality
    * - :meth:`Connection.prepare()`
      - Replace by the new :ref:`tcp` functionality
    * - The ``Oracledb.connect()`` and ``Oracledb.SessionPool()`` parameters ``encoding`` and ``nencoding``
      - The encodings in use are always UTF-8.
    * - ``Oracledb.connect()`` parameter ``threaded``
      -  This was  used to allow the Oracle Client libraries to support threaded applications. The value is ignored in python-oracledb: threaded OCI is now always enabled  in Thick, and the option is not relevant to Thin. The equivalent parameter was already deprecated for ``Oracledb.SessionPool()`` in cx_Oracle 8.2
    * - The attribute ``connection.maxBytesPerCharacter`` of the Connection object
      - This will return a constant value of 4 since encodings are always UTF-8.
    * - The size argument, ``numRows`` of the :meth:`Cursor.fetchmany()` method
      - Renamed ``size``
    * - :meth:`cx_Oracle.makedsn`
      - Use :ref:`ConnectParams Class <connparam>`
    * - Constant :data:`~oracledb.ATTR_PURITY_DEFAULT`
      - Replace by :data:`~oracledb.PURITY_DEFAULT`
    * - Constant :data:`~oracledb.ATTR_PURITY_NEW`
      - Replace by :data:`~oracledb.PURITY_NEW`
    * - Constant :data:`~oracledb.ATTR_PURITY_SELF`
      - Replace by :data:`~oracledb.PURITY_SELF`
    * - Constant :data:`~oracledb.SPOOL_ATTRVAL_WAIT`
      - Replace by :data:`~oracledb.POOL_GETMODE_WAIT`
    * - Constant :data:`~oracledb.SPOOL_ATTRVAL_NOWAIT`
      - Replace by :data:`~oracledb.POOL_GETMODE_NOWAIT`
    * - Constant :data:`~oracledb.SPOOL_ATTRVAL_FORCEGET`
      - Replace by :data:`~oracledb.POOL_GETMODE_FORCEGET`
    * - Constant :data:`~oracledb.SPOOL_ATTRVAL_TIMEDWAIT`
      - Replace by :data:`~oracledb.POOL_GETMODE_TIMEDWAIT`
    * - Constant :data:`~oracledb.DEFAULT_AUTH`
      - Replace by :data:`~oracledb.AUTH_MODE_DEFAULT`
    * - Constant :data:`~oracledb.SYSASM`
      - Replace by :data:`~oracledb.AUTH_MODE_SYSASM`
    * - Constant :data:`~oracledb.SYSBKP`
      - Replace by :data:`~oracledb.AUTH_MODE_SYSBKP`
    * - Constant :data:`~oracledb.SYSDBA`
      - Replace by :data:`~oracledb.AUTH_MODE_SYSDBA`
    * - Constant :data:`~oracledb.SYSDGD`
      - Replace by :data:`~oracledb.AUTH_MODE_SYSDGD`
    * - Constant :data:`~oracledb.SYSKMT`
      - Replace by :data:`~oracledb.AUTH_MODE_SYSKMT`
    * - Constant :data:`~oracledb.SYSOPER`
      - Replace by :data:`~oracledb.AUTH_MODE_SYSOPER`
    * - Constant :data:`~oracledb.SYSRAC`
      - Replace by :data:`~oracledb.AUTH_MODE_SYSRAC`
    * - Constant :data:`~oracledb.PRELIM_AUTH`
      - Replace by :data:`~oracledb.AUTH_MODE_PRELIM`
    * - Constant :data:`~oracledb.SUBSCR_PROTO_OCI`
      - Replace by :data:`~oracledb.SUBSCR_PROTO_CALLBACK`
    * - Class name :ref:`objecttype`
      - Replace by :ref:`dbobjecttype`
    * - Class name :ref:`object`
      - Replace by :ref:`dbobject`

Many of the `usages deprecated in cx_Oracle
<https://cx-oracle.readthedocs.io/en/latest/api_manual/deprecations.html#deprecations>`__
are still supported by python-oracledb to ease migration.  However these
previous cx_Oracle deprecation announcements remain in force for
python-oracledb, that is the relevant functionality may be removed in a future
version of python-oracledb.

Some previous deprecations have been removed:

- The previously deprecated function ``Cursor.fetchraw()`` has been removed in
  python-oracledb.  Use one of the other fetch methods such as
  `Cursor.fetchmany()` instead.

- The previously deprecated AQ API has been removed in python-oracledb.  Use
  the new `Advanced Queuing (AQ)
  <https://cx-oracle.readthedocs.io/en/latest/api_manual/aq.html>`__ shown in
  the cx_Oracle documentation.  AQ is only available in the Thick driver.


.. list-table-with-summary:: Deprecated in cx_Oracle 8.2
    :header-rows: 1
    :widths: 25 75
    :width: 100%
    :summary: The first column, Name, displays the deprecated API name. The second column, Comments, includes information about when the API was deprecated and what API to use, if applicable.
    :name: _deprecations_8_2

    * - Name
      - Comments
    * - `encoding` parameter to :meth:`oracledb.connect()`
      - No longer needed as the use of encodings other than UTF-8 is
        deprecated. Encoding is handled internally between python-oracledb and Oracle
        Database.
    * - `nencoding` parameter to :meth:`oracledb.connect()`
      - No longer needed as the use of encodings other than UTF-8 is
        deprecated.
    * - `encoding` parameter to :meth:`oracledb.SessionPool()`
      - No longer needed as the use of encodings other than UTF-8 is
        deprecated.
    * - `nencoding` parameter to :meth:`oracledb.SessionPool()`
      - No longer needed as the use of encodings other than UTF-8 is
        deprecated.
    * - Connection.maxBytesPerCharacter
      - No longer needed as the use of encodings other than UTF-8 is
        deprecated. The constant value 4 can be used instead.
    * - Positional parameters to :meth:`oracledb.connect()`
      - Replace with keyword parameters in order to comply with the Python
        database API.
    * - Positional parameters to :meth:`oracledb.SessionPool()`
      - Replace with keyword parameters in order to comply with the Python
        database API.
    * - `threaded` parameter to :meth:`oracledb.SessionPool()`
      - The value of this parameter is ignored. Threading is now always used.
    * - `waitTimeout` parameter to :meth:`oracledb.SessionPool()`
      - Replace with parameter name `wait_timeout`
    * - `maxLifetimeSession` parameter to :meth:`oracledb.SessionPool()`
      - Replace with parameter name `max_lifetime_session`
    * - `sessionCallback` parameter to :meth:`oracledb.SessionPool()`
      - Replace with parameter name `session_callback`
    * - `maxSessionsPerShard` parameter to :meth:`oracledb.SessionPool()`
      - Replace with parameter name `max_sessions_per_shard`
    * - `SessionPool.tnsentry`
      - Replace with :data:`SessionPool.dsn`
    * - `payloadType` parameter to :meth:`Connection.queue()`
      - Replace with parameter name `payload_type` if using keyword parameters.
    * - `ipAddress` parameter to :meth:`Connection.subscribe()`
      - Replace with parameter name `ip_address`
    * - `groupingClass` parameter to :meth:`Connection.subscribe()`
      - Replace with parameter name `grouping_class`
    * - `groupingValue` parameter to :meth:`Connection.subscribe()`
      - Replace with parameter name `grouping_value`
    * - `groupingType` parameter to :meth:`Connection.subscribe()`
      - Replace with parameter name `grouping_type`
    * - `clientInitiated` parameter to :meth:`Connection.subscribe()`
      - Replace with parameter name `client_initiated`
    * - `Connection.callTimeout`
      - Replace with :data:`Connection.call_timeout`
    * - `Connection.tnsentry`
      - Replace with :data:`Connection.dsn`
    * - `keywordParameters` parameter to :meth:`Cursor.callfunc()`
      - Replace with parameter name `keyword_parameters`
    * - `keywordParameters` parameter to :meth:`Cursor.callproc()`
      - Replace with parameter name `keyword_parameters`
    * - `encodingErrors` parameter to :meth:`Cursor.var()`
      - Replace with parameter name `encoding_errors`
    * - `Cursor.fetchraw()`
      - Replace with :meth:`Cursor.fetchmany()`
    * - `newSize` parameter to :meth:`LOB.trim()`
      - Replace with parameter name `new_size`
    * - `Queue.deqMany`
      - Replace with :meth:`Queue.deqmany()`
    * - `Queue.deqOne`
      - Replace with :meth:`Queue.deqone()`
    * - `Queue.enqMany`
      - Replace with :meth:`Queue.enqmany()`
    * - `Queue.enqOne`
      - Replace with :meth:`Queue.enqone()`
    * - `Queue.deqOptions`
      - Replace with :data:`Queue.deqoptions`
    * - `Queue.enqOptions`
      - Replace with :meth:`Queue.enqoptions`
    * - `Queue.payloadType`
      - Replace with :meth:`Queue.payload_type`
    * - `Subscription.ipAddress`
      - Replace with :attr:`Subscription.ip_address`
    * - `Message.consumerName`
      - Replace with :attr:`Message.consumer_name`
    * - `Message.queueName`
      - Replace with :attr:`Message.queue_name`
    * - `Variable.actualElements`
      - Replace with :attr:`Variable.actual_elements`
    * - `Variable.bufferSize`
      - Replace with :attr:`Variable.buffer_size`
    * - `Variable.numElements`
      - Replace with :attr:`Variable.num_elements`


.. list-table-with-summary:: Deprecated in cx_Oracle 8.0
    :header-rows: 1
    :widths: 25 75
    :width: 100%
    :summary: The first column, Name, displays the deprecated API name. The second column, Comments, includes information about when the API was deprecated and what API to use, if applicable.
    :name: _deprecations_8_0

    * - Name
      - Comments
    * - oracledb.BFILE
      - Replace with :data:`oracledb.DB_TYPE_BFILE`
    * - oracledb.BLOB
      - Replace with :data:`oracledb.DB_TYPE_BLOB`
    * - oracledb.BOOLEAN
      - Replace with :data:`oracledb.DB_TYPE_BOOLEAN`
    * - oracledb.CLOB
      - Replace with :data:`oracledb.DB_TYPE_CLOB`
    * - oracledb.CURSOR
      - Replace with :data:`oracledb.DB_TYPE_CURSOR`
    * - oracledb.FIXED_CHAR
      - Replace with :data:`oracledb.DB_TYPE_CHAR`
    * - oracledb.FIXED_NCHAR
      - Replace with :data:`oracledb.DB_TYPE_NCHAR`
    * - oracledb.INTERVAL
      - Replace with :data:`oracledb.DB_TYPE_INTERVAL_DS`
    * - oracledb.LONG_BINARY
      - Replace with :data:`oracledb.DB_TYPE_LONG_RAW`
    * - oracledb.LONG_STRING
      - Replace with :data:`oracledb.DB_TYPE_LONG`
    * - oracledb.NATIVE_FLOAT
      - Replace with :data:`oracledb.DB_TYPE_BINARY_DOUBLE`
    * - oracledb.NATIVE_INT
      - Replace with :data:`oracledb.DB_TYPE_BINARY_INTEGER`
    * - oracledb.NCHAR
      - Replace with :data:`oracledb.DB_TYPE_NVARCHAR`
    * - oracledb.NCLOB
      - Replace with :data:`oracledb.DB_TYPE_NCLOB`
    * - oracledb.OBJECT
      - Replace with :data:`oracledb.DB_TYPE_OBJECT`
    * - oracledb.TIMESTAMP
      - Replace with :data:`oracledb.DB_TYPE_TIMESTAMP`


.. list-table-with-summary:: Deprecated in cx_Oracle 7.2
    :header-rows: 1
    :widths: 25 75
    :width: 100%
    :summary: The first column, Name, displays the deprecated API name. The second column, Comments, includes information about when the API was deprecated and what API to use, if applicable.
    :name: _deprecations_7_2

    * - Name
      - Comments
    * - Connection.deq()
      - Replace with :meth:`Queue.deqone()` or :meth:`Queue.deqmany()`.
    * - Connection.deqoptions()
      - Replace with attribute :attr:`Queue.deqoptions`.
    * - Connection.enq()
      - Replace with :meth:`Queue.enqone()` or :meth:`Queue.enqmany()`.
    * - Connection.enqoptions()
      - Replace with attribute :attr:`Queue.enqoptions`.


.. list-table-with-summary:: Deprecated in cx_Oracle 6.4
    :header-rows: 1
    :widths: 25 75
    :width: 100%
    :summary: The first column, Name, displays the deprecated API name. The second column, Comments, includes information about when the API was deprecated and what API to use, if applicable.
    :name: _deprecations_6_4

    * - Name
      - Comments
    * - Cursor.executemanyprepared()
      - Replace with :meth:`~Cursor.executemany()` with None for the statement
        argument and an integer for the parameters argument.
