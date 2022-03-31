#------------------------------------------------------------------------------
# Copyright (c) 2022, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

from typing import Callable, Type, Union

from . import base_impl, constants, errors, utils
from . import connection as connection_module

class PoolParams:
    """
    Contains all parameters used for creating a connection pool.
    """
    __module__ = constants.MODULE_NAME
    __slots__ = ["_impl"]

    @utils.WithParamsImpl(base_impl.PoolParamsImpl)
    def __init__(self, *,
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
                 ping_interval: int=None):
        """
        Constructor for pool parameters. All parameters are optional and must
        be specified as keyword parameters only. A brief description of each
        parameter follows:

        - min: the minimum number of connections the pool should contain
          (default: 1)

        - max: the maximum number of connections the pool should contain
          (default: 2)

        - increment: the number of connections that should be added to the pool
          whenever a new connection needs to be created (default: 1)

        - connectiontype: the class of the connection that should be returned
          during calls to pool.acquire(); it must be Connection or a subclass
          of Connection (default: oracledb.Connection)

        - getmode: one of the constants POOL_GETMODE_WAIT, POOL_GETMODE_NOWAIT,
          POOL_GETMODE_FORCEGET, POOL_GETMODE_TIMEDWAIT (default:
          oracledb.POOL_GETMODE_WAIT)

        - homogeneous: a boolean indicating whether the connections are
          homogeneous (same user) or heterogeneous (multiple users) (default:
          True)

        - externalauth: a boolean indicating whether external authentication is
          in use or not (default: False)

        - timeout: length of time (in seconds) that a connection may remain
          idle in the pool before it is terminated or the value 0 which means
          that connections are never terminated (default: 0)

        - wait_timeout: length of time (in milliseconds) that a caller should
          wait when acquiring a connection from the pool with getmode set to
          POOL_GETMODE_TIMEDWAIT (default: 0)

        - max_lifetime_session: length of time (in seconds) that a connection
          can remain in the pool, or the value 0 which means that the
          connection may remain in the pool indefinitely (default: 0)

        - session_callback: a callable that is invoked when a connection is
          returned from the pool for the first time, or when the connection tag
          differs from the one requested (default: None)

        - max_sessions_per_shard: the maximum number of connections that may be
          associated with a particular shard

        - soda_metadata_cache: boolean indicating whether or not the SODA
          metadata cache should be enabled (default: False)

        - ping_interval: length of time (in seconds) after which an idle
          connection will be pinged before being returned to the caller, or a
          negative value, which will disable this functionality (default: 60)

        """
        pass

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
        Returns the number of seconds a connection must be idle before pinging
        the database to see if it is still alive. A negative value disables
        this functionality.
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
