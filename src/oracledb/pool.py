#------------------------------------------------------------------------------
# Copyright (c) 2020, 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

from typing import Callable, Type
from . import constants, errors, exceptions, utils, thick_impl, thin_impl
from . import connection as connection_module
from .defaults import defaults

class Pool:

    def __init__(self,
                 dsn: str=None, *,
                 user: str=None,
                 password: str=None,
                 host: str=None,
                 port: int=None,
                 service_name: str=None,
                 thin: bool=None,
                 min: int=1,
                 max: int=2,
                 increment: int=1,
                 connectiontype: Type["connection_module.Connection"]=None,
                 threaded: bool=None,
                 getmode: int=constants.POOL_GETMODE_WAIT,
                 events: bool=None,
                 homogeneous: bool=True,
                 externalauth: bool=False,
                 edition: str=None,
                 timeout: int=0,
                 wait_timeout: int=0,
                 max_lifetime_session: int=0,
                 session_callback: Callable=None,
                 max_sessions_per_shard: int=0,
                 soda_metadata_cache: bool=False,
                 stmtcachesize: int=None,
                 ping_interval: int=None,
                 secure_transport: bool=False,
                 config_dir: str=None,
                 enable_drcp: bool=False,
                 waitTimeout: int=0,
                 maxLifetimeSession: int=0,
                 sessionCallback: Callable=None,
                 maxSessionsPerShard: int=0) -> None:
        """
        Constructor for the pool. Connection pooling creates a pool of
        available connections to the database, allowing applications to acquire
        a connection very quickly. It is of primary use in a server where
        connections are requested in rapid succession and used for a short
        period of time, for example in a web server.

        The user, password and dsn parameters are the same as for connect().

        The min, max and increment parameters control pool growth behavior. A
        fixed pool size where min equals max is recommended to help prevent
        connection storms and to help overall system stability. The min
        parameter is the number of connections opened when the pool is created.
        The increment is the number of connections that are opened whenever a
        connection request exceeds the number of currently open connections.
        The max parameter is the maximum number of connections that can be open
        in the connection pool.

        Note that when using external authentication, heterogeneous pools, or
        Database Resident Connection Pooling (DRCP), then the pool growth
        behavior is different. In these cases the number of connections created
        at pool startup is always zero, and the increment is always one.

        If the connectiontype parameter is specified, all calls to acquire()
        will create connection objects of that type, rather than the base type
        defined at the module level.

        The threaded parameter is expected to be a boolean expression which
        indicates whether Oracle should wrap accesses to connections with a
        mutex. Doing so in single threaded applications imposes a performance
        penalty of about 10-15% which is why the default is False.

        The getmode parameter indicates whether or not future acquire() calls
        will wait for available connections.

        The events parameter is expected to be a boolean expression which
        indicates whether or not to initialize Oracle in events mode. This is
        required for continuous query notification and high availability event
        notifications.

        The homogeneous parameter is expected to be a boolean expression which
        indicates whether or not to create a homogeneous pool. A homogeneous
        pool requires that all connections in the pool use the same
        credentials. As such proxy authentication and external authentication
        is not possible with a homogeneous pool. See Heterogeneous and
        Homogeneous Connection Pools.

        The externalauth parameter is expected to be a boolean expression which
        indicates whether or not external authentication should be used.
        External authentication implies that something other than the database
        is authenticating the user to the database. This includes the use of
        operating system authentication and Oracle wallets. See Connecting
        Using External Authentication.

        The edition parameter is expected to be a string, if specified, and
        sets the edition to use for the connections in the pool. It is only
        relevant if both the client and the server are at least Oracle Database
        11.2. See Edition-Based Redefinition (EBR).

        The timeout parameter is expected to be an integer, if specified, and
        sets the length of time (in seconds) after which idle connections in
        the pool are terminated. Note that termination only occurs when the
        pool is accessed. The default value of 0 means that no idle connections
        are terminated.

        The wait_timeout parameter is expected to be an integer, if specified,
        and sets the length of time (in milliseconds) that the caller should
        wait for a connection to become available in the pool before returning
        with an error. This value is only used if the getmode parameter is set
        to the value POOL_GETMODE_TIMEDWAIT.

        The max_lifetime_session parameter is expected to be an integer, if
        specified, and sets the maximum length of time (in seconds) a pooled
        connection may exist. Connections that are in use will not be closed.
        They become candidates for termination only when they are released back
        to the pool and have existed for longer than max_lifetime_session
        seconds.  Note that termination only occurs when the pool is accessed.
        The default value is 0 which means that there is no maximum length of
        time that a pooled connection may exist.

        The session_callback parameter is expected to be either a string or a
        callable. If the session_callback parameter is a callable, it will be
        called when a newly created connection is returned from the pool, or
        when a tag is requested and that tag does not match the connection’s
        actual tag. The callable will be invoked with the connection and the
        requested tag as its only parameters. If the parameter is a string, it
        should be the name of a PL/SQL procedure that will be called when
        acquire() requests a tag and that tag does not match the connection’s
        actual tag. Support for the PL/SQL procedure requires Oracle Client
        libraries 12.2 or later. See the OCI documentation for more
        information.

        The max_sessions_per_shard parameter is expected to be an integer, if
        specified, and sets the maximum number of connections in the pool that
        can be used for any given shard in a sharded database. This lets
        connections in the pool be balanced across the shards. A value of zero
        will not set any maximum number of sessions for each shard. This value
        is ignored if the Oracle client library version is less than 18.3.

        The soda_metadata_cache parameter is expected to be a boolean expresion
        which indicates whether or not to enable the SODA metatata cache. This
        significantly improves the performance of methods
        SodaDatabase.createCollection() and SodaDatabase.openCollection() but
        can become out of date as it does not track changes made externally. It
        is also only available in Oracle Client 19.11 and higher. See Using the
        SODA Metadata Cache.

        The stmtcachesize parameter, if specified, is expected to be an integer
        which specifies the initial value of stmtcachesize.

        The ping_interval parameter, if specified, is expected to be an integer
        which specifies the initial value of ping_interval.
        """
        self._impl = None
        if thin is None:
            thin = defaults.thin
        if stmtcachesize is None:
            stmtcachesize = defaults.stmtcachesize
        if threaded is None:
            threaded = defaults.threaded
        if events is None:
            events = defaults.events
        if config_dir is None:
            config_dir = defaults.config_dir
        if ping_interval is None:
            ping_interval = defaults.ping_interval
        if connectiontype is None:
            connectiontype = connection_module.Connection
        elif not issubclass(connectiontype, connection_module.Connection):
            message = "connection type must be a subclass of " \
                      "oracledb.Connection"
            raise TypeError(message)
        self._connection_type = connectiontype
        params = utils.ConnectParams(user=user, password=password, host=host,
                                     port=port, service_name=service_name,
                                     secure_transport=secure_transport,
                                     config_dir=config_dir,
                                     enable_drcp=enable_drcp)
        if dsn is not None:
            params.parse_dsn(dsn, thin=thin)

        if waitTimeout != 0:
            if wait_timeout != 0:
                message = "waitTimeout and wait_timeout cannot both be " \
                          "specified"
                raise exceptions.ProgrammingError(message)
            wait_timeout = waitTimeout
        if maxLifetimeSession != 0:
            if max_lifetime_session != 0:
                message = "maxLifetimeSession and max_lifetime_session " \
                          "cannot both be specified"
                raise exceptions.ProgrammingError(message)
            max_lifetime_session = maxLifetimeSession
        if sessionCallback is not None:
            if session_callback is not None:
                message = "sessionCallback and session_callback cannot both " \
                          "be specified"
                raise exceptions.ProgrammingError(message)
            session_callback = sessionCallback
        if maxSessionsPerShard != 0:
            if max_sessions_per_shard != 0:
                message = "maxSessionsPerShard and max_sessions_per_shard " \
                          "cannot both be specified"
                raise exceptions.ProgrammingError(message)
            max_sessions_per_shard = maxSessionsPerShard

        if thin:
            impl = thin_impl.ThinPoolImpl(params, min, max, increment,
                                          homogeneous, getmode, wait_timeout,
                                          stmtcachesize)
        else:
            impl = thick_impl.ThickPoolImpl(params.user, params.get_dsn(), min,
                                            max, increment, homogeneous)
            impl._create(password=params.password, threaded=threaded,
                         getmode=getmode, events=events,
                         externalauth=externalauth,
                         edition=edition, timeout=timeout,
                         wait_timeout=wait_timeout,
                         max_lifetime_session=max_lifetime_session,
                         session_callback=session_callback,
                         max_sessions_per_shard=max_sessions_per_shard,
                         soda_metadata_cache=soda_metadata_cache,
                         stmtcachesize=stmtcachesize,
                         ping_interval=ping_interval)
        self._impl = impl
        self.session_callback = session_callback

    def _verify_open(self):
        """
        Verifies that the pool is open and able to perform its work.
        """
        if self._impl is None:
            errors._raise_from_string(exceptions.InterfaceError, "not open")

    def acquire(self,
                user: str=None,
                password: str=None,
                cclass: str=None,
                purity: int=constants.PURITY_DEFAULT,
                tag: str=None,
                matchanytag: bool=False,
                shardingkey: list=None,
                supershardingkey: list=None) -> Type["connection_module.Connection"]:
        """
        Acquire a connection from the pool and return it.

        If the pool is homogeneous, the user and password parameters cannot be
        specified. If they are, an exception will be raised.

        The cclass parameter, if specified, should be a string corresponding to
        the connection class for database resident connection pooling (DRCP).

        The purity parameter is expected to be one of PURITY_DEFAULT,
        PURITY_NEW, or PURITY_ANY.

        The tag parameter, if specified, is expected to be a string with
        name=value pairs like “k1=v1;k2=v2” and will limit the connections that
        can be returned from a pool unless the matchanytag parameter is
        set to True. In that case connections with the specified tag will be
        preferred over others, but if no such connections are available a
        connection with a different tag may be returned instead. In any case,
        untagged connections will always be returned if no connections with the
        specified tag are available. Connections are tagged when they are
        released back to the pool.

        The shardingkey and supershardingkey parameters, if specified, are
        expected to be a sequence of values which will be used to identify the
        database shard to connect to. The key values can be strings, numbers,
        bytes or dates.
        """
        self._verify_open()
        return self._connection_type(user=user, password=password,
                                     cclass=cclass, purity=purity, tag=tag,
                                     matchanytag=matchanytag,
                                     shardingkey=shardingkey,
                                     supershardingkey=supershardingkey,
                                     pool=self)

    @property
    def busy(self) -> int:
        """
        Returns the number of connections that have been acquired from the pool
        and have not yet been returned to the pool.
        """
        self._verify_open()
        return self._impl.get_busy_count()

    def close(self, force: bool=False) -> None:
        """
        Close the pool now, rather than when the last reference to it is
        released, which makes it unusable for further work.

        If any connections have been acquired and not released back to the
        pool, this method will fail unless the force parameter is set to True.
        """
        self._verify_open()
        self._impl.close(force)
        self._impl = None

    def drop(self, connection: Type["connection_module.Connection"]) -> None:
        """
        Drop the connection from the pool, which is useful if the connection is
        no longer usable (such as when the database session is killed).
        """
        self._verify_open()
        if not isinstance(connection, connection_module.Connection):
            message = "connection must be an instance of " \
                      "oracledb.Connection"
            raise TypeError(message)
        connection._verify_connected()
        self._impl.drop(connection._impl)
        connection._impl = None

    @property
    def dsn(self) -> str:
        """
        Returns the connection string (TNS entry) of the database to which
        connections in the pool have been established.
        """
        self._verify_open()
        return self._impl.dsn

    @property
    def getmode(self) -> int:
        self._verify_open()
        return self._impl.get_getmode()

    @getmode.setter
    def getmode(self, value: int) -> None:
        self._verify_open()
        self._impl.set_getmode(value)

    @property
    def homogeneous(self) -> bool:
        """
        Returns a boolean indicating if the pool is homogeneous or not. If the
        pool is not homogeneous, different authentication can be used for each
        connection acquired from the pool.
        """
        self._verify_open()
        return self._impl.homogeneous

    @property
    def increment(self) -> int:
        """
        Returns the number of connections that will be created when additional
        connections need to be created to satisfy requests.
        """
        self._verify_open()
        return self._impl.increment

    @property
    def max(self) -> int:
        """
        Returns the maximum number of connections that the pool can control.
        """
        self._verify_open()
        return self._impl.max

    @property
    def max_lifetime_session(self) -> int:
        """
        Returns the maximum length of time (in seconds) that a pooled
        connection may exist. Connections that are in use will not be closed.
        They become candidates for termination only when they are released back
        to the pool and have existed for longer than max_lifetime_session
        seconds. Note that termination only occurs when the pool is accessed. A
        value of 0 means that there is no maximum length of time that a pooled
        connection may exist. This attribute is only available in Oracle
        Database 12.1.
        """
        self._verify_open()
        return self._impl.get_max_lifetime_session()

    @max_lifetime_session.setter
    def max_lifetime_session(self, value: int) -> None:
        self._verify_open()
        self._impl.set_max_lifetime_session(value)

    @property
    def max_sessions_per_shard(self) -> int:
        """
        Returns the number of sessions that can be created per shard in the
        pool.  Setting this attribute greater than zero specifies the maximum
        number of sessions in the pool that can be used for any given shard in
        a sharded database. This lets connections in the pool be balanced
        across the shards.  A value of zero will not set any maximum number of
        sessions for each shard.  This attribute is only available in Oracle
        Client 18.3 and higher.
        """
        self._verify_open()
        return self._impl.get_max_sessions_per_shard()

    @max_sessions_per_shard.setter
    def max_sessions_per_shard(self, value: int) -> None:
        self._verify_open()
        self._impl.set_max_sessions_per_shard(value)

    @property
    def min(self) -> int:
        """
        Returns the minimum number of connections that the pool will control.
        These are created when the pool is first created.
        """
        self._verify_open()
        return self._impl.min

    @property
    def name(self) -> str:
        """
        Returns the name assigned to the pool by Oracle. This attribute is only
        relevant for the thick portion of the driver.
        """
        self._verify_open()
        return self._impl.name

    @property
    def opened(self) -> int:
        """
        Returns the number of connections currently opened by the pool.
        """
        self._verify_open()
        return self._impl.get_open_count()

    @property
    def ping_interval(self) -> int:
        """
        Returns the pool ping interval in seconds. When a connection is
        acquired from the pool, a check is first made to see how long it
        has been since the connection was put into the pool. If
        this idle time exceeds ping_interval, then a round-trip ping to the
        database is performed. If the connection is unusable, it is discarded
        and a different connection is selected to be returned by
        SessionPool.acquire(). Setting ping_interval to a negative value
        disables pinging. Setting it to 0 forces a ping for every aquire()
        and is not recommended.
        """
        self._verify_open()
        return self._impl.get_ping_interval()

    @ping_interval.setter
    def ping_interval(self, value: int) -> None:
        self._impl.set_ping_interval(value)

    def release(self, connection: Type["connection_module.Connection"],
                tag: str=None) -> None:
        """
        Release the connection back to the pool now, rather than whenever
        __del__ is called. The connection will be unusable from this point
        forward; an Error exception will be raised if any operation is
        attempted with the connection. Any cursors or LOBs created by the
        connection will also be marked unusable and an Error exception will be
        raised if any operation is attempted with them.

        Internally, references to the connection are held by cursor objects,
        LOB objects, etc. Once all of these references are released, the
        connection itself will be released back to the pool automatically.
        Either control references to these related objects carefully or
        explicitly release connections back to the pool in order to ensure
        sufficient resources are available.

        If the tag is not None, it is expected to be a string with name=value
        pairs like “k1=v1;k2=v2” and will override the value in the property
        Connection.tag. If either Connection.tag or the tag parameter are not
        None, the connection will be retagged when it is released back to the
        pool.
        """
        self._verify_open()
        if not isinstance(connection, connection_module.Connection):
            message = "connection must be an instance of " \
                      "oracledb.Connection"
            raise TypeError(message)
        if tag is not None:
            connection.tag = tag
        connection.close()

    def reconfigure(self,
                    min: int=None,
                    max: int=None,
                    increment: int=None,
                    getmode: int=None,
                    timeout: int=None,
                    wait_timeout: int=None,
                    max_lifetime_session: int=None,
                    max_sessions_per_shard: int=None,
                    soda_metadata_cache: bool=None,
                    stmtcachesize: int=None,
                    ping_interval: int=None) -> None:
        """
        Reconfigures various parameters of a connection pool. The pool size
        can be altered with reconfigure() by passing values for min, max
        or increment. The getmode, timeout, wait_timeout,
        max_lifetime_session, max_sessions_per_shard, soda_metadata_cache,
        stmtcachesize and ping_interval can be set directly or by using
        reconfigure(). All parameters are optional. Unspecified parameters
        will leave those pool attributes unchanged. The parameters are
        processed in two stages. After any size change has been processed,
        reconfiguration on the other parameters is done sequentially. If
        an error such as an invalid value occurs when changing one attribute,
        then an exception will be generated but any already changed
        attributes will retain their new values.

        During reconfiguration of a pool's size, the behavior of acquire()
        depends on the getmode in effect when acquire() is called:

        * With mode POOL_GETMODE_FORCEGET, an acquire() call will wait until
          the pool has been reconfigured.

        * With mode POOL_GETMODE__TIMEDWAIT, an acquire() call will try to
          acquire a connection in the time specified by pool.wait_timeout and
          return an error if the time taken exceeds that value.

        * With mode POOL_GETMODE_WAIT, an acquire() call will wait until after
          the pool has been reconfigured and a connection is available.

        * With mode POOL_GETMODE_NOWAIT, if the number of busy connections is
          less than the pool size, ``acquire()`` will return a new connection
          after pool reconfiguration is complete.

        Closing connections with pool.release() or connection.close() will
        wait until any pool size reconfiguration is complete.

        Closing the connection pool with pool.close() will wait until
        reconfiguration is complete.
        """

        if min is None:
            min = self.min
        if max is None:
            max = self.max
        if increment is None:
            increment = self.increment
        if self.min != min or self.max != max or self.increment != increment:
            self._impl.reconfigure(min, max, increment)
        if getmode is not None:
            self.getmode = getmode
        if timeout is not None:
            self.timeout = timeout
        if wait_timeout is not None:
            self.wait_timeout = wait_timeout
        if max_lifetime_session is not None:
            self.max_lifetime_session = max_lifetime_session
        if max_sessions_per_shard is not None:
            self.max_sessions_per_shard = max_sessions_per_shard
        if soda_metadata_cache is not None:
            self.soda_metadata_cache = soda_metadata_cache
        if stmtcachesize is not None:
            self.stmtcachesize = stmtcachesize
        if ping_interval is not None:
            self.ping_interval = ping_interval

    @property
    def soda_metadata_cache(self) -> bool:
        """
        Specifies whether the SODA metadata cache is enabled or not. Enabling
        the cache significantly improves the performance of methods
        SodaDatabase.createCollection() (when not specifying a value for the
        metadata parameter) and SodaDatabase.openCollection(). Note that the
        cache can become out of date if changes to the metadata of cached
        collections are made externally.
        """
        self._verify_open()
        return self._impl.get_soda_metadata_cache()

    @soda_metadata_cache.setter
    def soda_metadata_cache(self, value: bool) -> None:
        if not isinstance(value, bool):
            message = "soda_metadata_cache must be a boolean value."
            raise TypeError(message)
        self._verify_open()
        self._impl.set_soda_metadata_cache(value)

    @property
    def stmtcachesize(self) -> int:
        """
        Specifies the size of the statement cache that will be used as the
        starting point for any connections that are created by the pool. Once a
        connection is created, that connection’s statement cache size can only
        be changed by setting the stmtcachesize attribute on the connection
        itself.
        """
        self._verify_open()
        return self._impl.get_stmt_cache_size()

    @stmtcachesize.setter
    def stmtcachesize(self, value: int) -> None:
        self._verify_open()
        self._impl.set_stmt_cache_size(value)

    @property
    def thin(self) -> bool:
        """
        Returns a boolean indicating if the pool was created with the thin
        driver (True) or thick driver (False).
        """
        self._verify_open()
        return isinstance(self._impl, thin_impl.ThinPoolImpl)

    @property
    def timeout(self) -> int:
        """
        Specifies the time (in seconds) after which idle connections will be
        terminated in order to maintain an optimum number of open connections.
        Note that termination only occurs when the pool is accessed. A value of
        0 means that no idle connections are terminated.
        """
        self._verify_open()
        return self._impl.get_timeout()

    @timeout.setter
    def timeout(self, value: int) -> None:
        self._verify_open()
        self._impl.set_timeout(value)

    @property
    def tnsentry(self) -> str:
        """
        Deprecated. Use dsn instead.
        """
        return self.dsn

    @property
    def username(self) -> str:
        """
        Returns the name of the user which was used to create the pool.
        """
        self._verify_open()
        return self._impl.username

    @property
    def wait_timeout(self) -> int:
        """
        Specifies the time (in milliseconds) that the caller should wait for a
        connection to become available in the pool before returning with an
        error.  This value is only used if the getmode parameter used to create
        the pool was POOL_GETMODE_TIMEDWAIT.
        """
        self._verify_open()
        return self._impl.get_wait_timeout()

    @wait_timeout.setter
    def wait_timeout(self, value: int) -> None:
        self._verify_open()
        self._impl.set_wait_timeout(value)


# alias
create_pool = Pool
