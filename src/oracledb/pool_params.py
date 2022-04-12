#------------------------------------------------------------------------------
# Copyright (c) 2022, Oracle and/or its affiliates.
# This program is free software: you can modify it and/or redistribute it
# under the terms of:
#
# (i)  the Universal Permissive License v 1.0 or at your option, any
#      later version (http://oss.oracle.com/licenses/upl); and/or
#
# (ii) the Apache License v 2.0. (http://www.apache.org/licenses/LICENSE-2.0)
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# pool_params.py
#
# Contains the PoolParams class used for managing the parameters required to
# create a connection pool.
#------------------------------------------------------------------------------

from typing import Callable, Type, Union

from . import base_impl, constants, errors, utils
from . import connection as connection_module
from .connect_params import ConnectParams

class PoolParams(ConnectParams):
    """
    Contains all parameters used for creating a connection pool.
    """
    __module__ = constants.MODULE_NAME
    __slots__ = ["_impl"]

    def __init__(self, **kwargs):
        """
        Constructor for pool parameters. If any parameters are specified they
        are passed to the set() method. See the documentation there for details
        on the available parameters.
        """
        self._impl = base_impl.PoolParamsImpl()
        if kwargs:
            self.set(**kwargs)

    def __repr__(self):
        return f"PoolParams(" \
               f"min={self.min!r}, " \
               f"max={self.max!r}, " \
               f"increment={self.increment!r}, " \
               f"connectiontype={self.connectiontype!r}, " \
               f"getmode={self.getmode!r}, " \
               f"homogeneous={self.homogeneous!r}, " \
               f"externalauth={self.externalauth!r}, " \
               f"timeout={self.timeout!r}, " \
               f"wait_timeout={self.wait_timeout!r}, " \
               f"max_lifetime_session={self.max_lifetime_session!r}, " \
               f"session_callback={self.session_callback!r}, " \
               f"max_sessions_per_shard={self.max_sessions_per_shard!r}, " \
               f"soda_metadata_cache={self.soda_metadata_cache!r}, " \
               f"ping_interval={self.ping_interval!r})"

    @property
    def connectiontype(self) -> Type["connection_module.Connection"]:
        """
        Returns the mininum number of connections to retain in the pool.
        """
        return self._impl.connectiontype

    @connectiontype.setter
    def connectiontype(self, value: Type["connection_module.Connection"]) -> None:
        self._impl.connectiontype = value

    def copy(self) -> Type["PoolParams"]:
        """
        Creates a copy of the parameters and returns it.
        """
        params = PoolParams.__new__(PoolParams)
        params._impl = self._impl.copy()
        return params

    @property
    def externalauth(self) -> bool:
        """
        Returns whether the pool uses external authentication to connect to the
        database.
        """
        return self._impl.externalauth

    @externalauth.setter
    def externalauth(self, value: bool) -> None:
        self._impl.externalauth = value

    @property
    def getmode(self) -> int:
        """
        Returns the mode to use when getting connections from the pool.
        """
        return self._impl.getmode

    @getmode.setter
    def getmode(self, value: int) -> None:
        self._impl.getmode = value

    @property
    def homogeneous(self) -> bool:
        """
        Returns whether the pool is homogeneous or not.
        """
        return self._impl.homogeneous

    @homogeneous.setter
    def homogeneous(self, value: bool) -> None:
        self._impl.homogeneous = value

    @property
    def increment(self) -> int:
        """
        Returns the number of connections to add to the pool when all
        connections in the pool are busy.
        """
        return self._impl.increment

    @increment.setter
    def increment(self, value: int) -> None:
        self._impl.increment = value

    @property
    def min(self) -> int:
        """
        Returns the mininum number of connections to retain in the pool.
        """
        return self._impl.min

    @min.setter
    def min(self, value: int) -> None:
        self._impl.min = value

    @property
    def max(self) -> int:
        """
        Returns the maxinum number of connections to retain in the pool.
        """
        return self._impl.max

    @max.setter
    def max(self, value: int) -> None:
        self._impl.max = value

    @property
    def max_lifetime_session(self) -> int:
        """
        Returns the number of seconds a connection may remain in the pool.
        """
        return self._impl.max_lifetime_session

    @max_lifetime_session.setter
    def max_lifetime_session(self, value: int) -> None:
        self._impl.max_lifetime_session = value

    @property
    def max_sessions_per_shard(self) -> int:
        """
        Returns the maximum number of connections for a particular shard to
        retain in the pool.
        """
        return self._impl.max_sessions_per_shard

    @max_sessions_per_shard.setter
    def max_sessions_per_shard(self, value: int) -> None:
        self._impl.max_sessions_per_shard = value

    @property
    def ping_interval(self) -> int:
        """
        Returns the number of seconds after which an unused connection in the
        pool will be a candidate for pinging when pool.acquire() is called.
        If the ping to the database indicates the connection is not alive a
        replacement connection will be returned by pool.acquire(). If
        ping_interval is a negative value the ping functionality will be
        disabled.
        """
        return self._impl.ping_interval

    @ping_interval.setter
    def ping_interval(self, value: int) -> None:
        self._impl.ping_interval = value

    @property
    def session_callback(self) -> Callable:
        """
        Returns the callback to invoke when new connections are created or when
        the connection returned does not have the requested tag.
        """
        return self._impl.session_callback

    @session_callback.setter
    def session_callback(self, value: Callable) -> None:
        self._impl.session_callback = value

    @utils.params_setter
    def set(self, *,

            # pool configuration parameters
            min: int=None,
            max: int=None,
            increment: int=None,
            connectiontype: Type["connection_module.Connection"]=None,
            getmode: int=None,
            homogeneous: bool=True,
            externalauth: bool=None,
            timeout: int=0,
            wait_timeout: int=0,
            max_lifetime_session: int=0,
            session_callback: Callable=None,
            max_sessions_per_shard: int=0,
            soda_metadata_cache: bool=None,
            ping_interval: int=None,

            # credentials
            user: str=None,
            proxy_user: str=None,
            password: str=None,
            newpassword: str=None,
            wallet_password: str=None,

            # connect string parameters
            host: str=None,
            port: int=None,
            protocol: str=None,
            https_proxy: str=None,
            https_proxy_port: int=None,
            service_name: str=None,
            sid: str=None,
            server_type: str=None,
            cclass: str=None,
            purity: int=None,
            expire_time: int=None,
            retry_count: int=None,
            retry_delay: int=None,
            tcp_connect_timeout: float=None,
            ssl_server_dn_match: bool=None,
            ssl_server_cert_dn: str=None,
            wallet_location: str=None,

            # other parameters
            events: bool=None,
            mode: int=None,
            disable_oob: bool=None,
            stmtcachesize: int=None,
            edition: str=None,
            tag: str=None,
            matchanytag: bool=None,
            config_dir: str=None,
            appcontext: list=None,
            shardingkey: list=None,
            supershardingkey: list=None,
            handle: int=None,

            # deprecated (ignored) parameters
            threaded: bool=None,
            encoding: str=None,
            nencoding: str=None) -> None:
        """
        Sets pool parameters. Only those parameters which are specified (and
        are not None) will be changed; all other values will remain unchanged.
        A brief description of each parameter follows:

        - min: the minimum number of connections the pool should contain
          (default: 1)

        - max: the maximum number of connections the pool should contain
          (default: 2)

        - increment: the number of connections that should be added to the pool
          whenever a new connection needs to be created (default: 1)

        - connectiontype: the class of the connection that should be returned
          during calls to pool.acquire(). It must be Connection or a subclass
          of Connection (default: oracledb.Connection)

        - getmode: how pool.acquire() will behave. One of the constants
          oracledb.POOL_GETMODE_WAIT, oracledb.POOL_GETMODE_NOWAIT,
          oracledb.POOL_GETMODE_FORCEGET, or oracledb.POOL_GETMODE_TIMEDWAIT
          (default: oracledb.POOL_GETMODE_WAIT)

        - homogeneous: a boolean indicating whether the connections are
          homogeneous (same user) or heterogeneous (multiple users) (default:
          True)

        - externalauth: a boolean indicating whether to use external
          authentication (default: False)

        - timeout: length of time (in seconds) that a connection may remain
          idle in the pool before it is terminated. If it is 0 then connections
          are never terminated (default: 0)

        - wait_timeout: length of time (in milliseconds) that a caller should
          wait when acquiring a connection from the pool with getmode set to
          oracledb.POOL_GETMODE_TIMEDWAIT (default: 0)

        - max_lifetime_session: length of time (in seconds) that connections
          can remain in the pool. If it is 0 then connections may remain in the
          pool indefinitely (default: 0)

        - session_callback: a callable that is invoked when a connection is
          returned from the pool for the first time, or when the connection tag
          differs from the one requested (default: None)

        - max_sessions_per_shard: the maximum number of connections that may be
          associated with a particular shard

        - soda_metadata_cache: boolean indicating whether or not the SODA
          metadata cache should be enabled (default: False)

        - ping_interval: length of time (in seconds) after which an unused
          connection in the pool will be a candidate for pinging when
          pool.acquire() is called. If the ping to the database indicates the
          connection is not alive a replacement connection will be returned by
          pool.acquire(). If ping_interval is a negative value the ping
          functionality will be disabled (default: 60)

        The remaining parameters are the same as for connection parameters and
        are described there.
        """
        pass

    @property
    def soda_metadata_cache(self) -> bool:
        """
        Returns whether the SODA metadata cache should be enabled.
        """
        return self._impl.soda_metadata_cache

    @soda_metadata_cache.setter
    def soda_metadata_cache(self, value: bool) -> None:
        self._impl.soda_metadata_cache = value

    @property
    def timeout(self) -> int:
        """
        Returns the number of seconds a connection may remain idle in the pool.
        """
        return self._impl.timeout

    @timeout.setter
    def timeout(self, value: int) -> None:
        self._impl.timeout = value

    @property
    def wait_timeout(self) -> int:
        """
        Returns the maximum number of milliseconds to wait before an error is
        raised when getting a connection from the pool with get mode set to
        oracledb.POOL_GETMODE_TIMEDWAIT.
        """
        return self._impl.wait_timeout

    @wait_timeout.setter
    def wait_timeout(self, value: int) -> None:
        self._impl.wait_timeout = value
