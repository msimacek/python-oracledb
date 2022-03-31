#------------------------------------------------------------------------------
# Copyright (c) 2021, 2022, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

from typing import Type, Union

from . import base_impl, constants, errors, utils

class ConnectParams:
    """
    Contains all parameters used for establishing a connection to the
    database.
    """
    __module__ = constants.MODULE_NAME
    __slots__ = ["_impl"]

    @utils.WithParamsImpl(base_impl.ConnectParamsImpl)
    def __init__(self, *,

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
        Constructor for connection parameters. All parameters are optional and
        must be specified as keyword parameters only. A brief description of
        each parameter follows:

        - user: the name of the user to connect to (default: None)

        - proxy_user: the name of the proxy user to connect to; if this value
          is not specified, it will be parsed out of user if it is in the form
          "user[proxy_user]" (default: None)

        - password: the password for the user (default: None)

        - newpassword: the new password for the user; the new password will
          take effect immediately upon a successful connection to the database
          (default: None)

        - wallet_password: the password to use to decrypt the wallet, if it is
          encrypted; this value is only used in thin mode (default: None)

        - host: the name or IP address of the machine hosting the listener,
          which handles the initial connection to the database (default: None)

        - port: the port number on which the listener is listening
          (default: 1521)

        - protocol: one of the strings "tcp" or "tcps" indicating whether to
          use unencrypted network traffic or encrypted network traffic (TLS)
          (default: "tcp")

        - https_proxy: the name or IP address of a proxy host to use for
          tunneling secure connections (default: None)

        - https_proxy_port: the port on which to communicate with the proxy
          host (default: 0)

        - service_name: the service name of the database (default: None)

        - sid: the SID of the database; service_name should be used instead
          (default: None)

        - server_type: the type of server connection that should be
          established; if specified, it should be one of "dedicated", "shared"
          or "pooled" (default: None)

        - cclass: connection class to use for DRCP (default: None)

        - purity: purity to use for DRCP (default: oracledb.PURITY_DEFAULT)

        - expire_time: an integer indicating the number of minutes between the
          sending of keepalive probes; if this parameter is set to a value
          greater than zero it enables keepalive (default: 0)

        - retry_count: the number of times that a connection attempt should be
          retried before the attempt is terminated (default: 0)

        - retry_delay: the number of seconds to wait before making a new
          connection attempt (default: 0)

        - tcp_connect_timeout: a float indicating the maximum number of seconds
          to wait for establishing a connection to the database host
          (default: 60.0)

        - ssl_server_dn_match: boolean indicating whether the server
          certificate distinguished name (DN) should be matched in addition to
          the regular certificate verification that is performed; note that if
          the ssl_server_cert_dn parameter is not privided, host name matching
          is performed instead (default: True)

        - ssl_server_cert_dn: the distinguished name (DN) which should be
          matched with the server. This value is ignored if the
          ssl_server_dn_match parameter is not set to the value True.

        - wallet_location: the directory where the wallet can be found; in thin
          mode this must be the directory of the PEM-encoded wallet file
          ewallet.pem; in thick mode this must be the directory of the file
          cwallet.sso (default: None)

        - events: boolean specifying whether events mode should be enabled;
          this value is only used in thick mode and is needed for continuous
          query notification and high availability event notifications
          (default: False)

        - mode: authorization mode to use (default: oracledb.AUTH_MODE_DEFAULT)

        - disable_oob: boolean indicating whether out-of-band breaks should be
          disabled; this value is only used in thin mode and has no effect on
          Windows which doesn't support this functionality (default: False)

        - stmtcachesize: identifies the initial size of the statement cache
          (default: oracledb.defaults.stmtcachesize)

        - edition: edition to use for the connection; this parameter cannot be
          used simultaneously with the cclass parameter (default: None)

        - tag: identifies the type of connection that should be returned from a
          pool; this value is only used in thick mode (default: None)

        - matchanytag: boolean specifying whether any tag can be used when
          acquiring a connection from the pool; this value is only used in
          thick mode when acquiring a connection from a pool (default: None)

        - config_dir: directory in which configuration files (tnsnames.ora) are
          found; this value is only used in thin mode (default:
          oracledb.defaults.config_dir)

        - appcontext: application context used by the connection; it should be
          a list of 3-tuples (namespace, name, value) and each entry in the
          tuple should be a string; this value is only used in thick mode
          (default: [])

        - shardingkey: a list of strings, numbers, bytes or dates that identify
          the database shard to connect to; this value is only used in thick
          mode (default: [])

        - supershardingkey: a list of strings, numbers, bytes or dates that
          identify the database shard to connect to; this value is only used in
          thick mode (default: [])

        - handle: an integer representing a pointer to a valid service context
          handle; this value is only used in thick mode and should be used with
          extreme caution (default: 0)

        """
        pass

    def __repr__(self):
        return f"ConnectParams(" \
               f"user={self.user!r}, " \
               f"proxy_user={self.proxy_user!r}, " \
               f"host={self.host!r}, " \
               f"port={self.port!r}, " \
               f"service_name={self.service_name!r}, " \
               f"sid={self.sid!r}, " \
               f"events={self.events!r}, " \
               f"protocol={self.protocol!r}, " \
               f"server_type={self.server_type!r}, " \
               f"config_dir={self.config_dir!r}, " \
               f"cclass={self.cclass!r}, " \
               f"purity={self.purity!r}, " \
               f"mode={self.mode!r}, " \
               f"edition={self.edition!r}, " \
               f"appcontext={self.appcontext!r}, " \
               f"tag={self.tag!r}, " \
               f"matchanytag={self.matchanytag!r}, " \
               f"shardingkey={self.shardingkey!r}, " \
               f"supershardingkey={self.supershardingkey!r}, " \
               f"stmtcachesize={self.stmtcachesize!r}, " \
               f"disable_oob={self.disable_oob!r}, " \
               f"ssl_server_dn_match={self.ssl_server_dn_match!r}, " \
               f"ssl_server_cert_dn={self.ssl_server_cert_dn!r}, " \
               f"retry_count={self.retry_count!r}, " \
               f"retry_delay={self.retry_delay!r}, " \
               f"expire_time={self.expire_time!r}, " \
               f"tcp_connect_timeout={self.tcp_connect_timeout!r}, " \
               f"wallet_location={self.wallet_location!r}, " \
               f"https_proxy={self.https_proxy!r}, " \
               f"https_proxy_port={self.https_proxy_port!r})"

    def _address_attr(f):
        """
        Helper function used to get address level attributes.
        """
        def wrapped_func(self):
            output = []
            for description in self._impl.description_list.descriptions:
                for address_list in description.address_lists:
                    for address in address_list.addresses:
                        output.append(getattr(address, f.__name__))
            return output if len(output) > 1 else output[0]
        return wrapped_func

    def _description_attr(f):
        """
        Helper function used to get description level attributes.
        """
        def wrapped_func(self):
            output = []
            for description in self._impl.description_list.descriptions:
                output.append(getattr(description, f.__name__))
            return output if len(output) > 1 else output[0]
        return wrapped_func

    @property
    def appcontext(self) -> list:
        """
        Returns the application context to use when connecting to the database.
        """
        return self._impl.appcontext

    @appcontext.setter
    def appcontext(self, value: list) -> None:
        self._impl.appcontext = value

    @property
    @_description_attr
    def cclass(self) -> Union[list, str]:
        """
        Returns the cclass associated with each description in the
        connect string. If the connect string contains multiple descriptions,
        a list of cclass is returned in the order they appear.
        """
        pass

    @property
    def config_dir(self) -> str:
        """
        Returns the directory where configuration files are located.
        """
        return self._impl.config_dir

    @config_dir.setter
    def config_dir(self, value: str) -> None:
        self._impl.config_dir = value

    @property
    def disable_oob(self) -> bool:
        """
        Returns whether OOB (out-of-band) breaks should be disabled or not.
        """
        return self._impl.disable_oob

    @disable_oob.setter
    def disable_oob(self, value: bool) -> None:
        self._impl.disable_oob = value

    @property
    def edition(self) -> str:
        """
        Returns the edition to use with the connection.
        """
        return self._impl.edition

    @edition.setter
    def edition(self, value: str) -> None:
        self._impl.edition = value

    @property
    def events(self) -> bool:
        """
        Returns whether events mode is enabled or not.
        """
        return self._impl.events

    @events.setter
    def events(self, value: bool) -> None:
        self._impl.events = value

    @property
    @_description_attr
    def expire_time(self) -> Union[list, int]:
        """
        Returns the expire_times associated with each description in the
        connect string. If the connect string contains multiple descriptions,
        a list of expire_times is returned in the order they appear.
        """
        pass

    @property
    @_address_attr
    def host(self) -> Union[list, str]:
        """
        Returns the host associated with the address in the connect string.
        If the connect string contains multiple addresses, a list of hosts
        is returned in the order they appear.
        """
        pass

    @property
    @_address_attr
    def https_proxy(self) -> Union[list, str]:
        """
        Returns the proxy host associated with the address in the connect
        string.  If the connect string contains multiple addresses, a list of
        proxy hosts is returned in the order they appear.
        """
        pass

    @property
    @_address_attr
    def https_proxy_port(self) -> Union[list, int]:
        """
        Returns the proxy host port associated with the address in the connect
        string.  If the connect string contains multiple addresses, a list of
        proxy host ports is returned in the order they appear.
        """
        pass

    @property
    def matchanytag(self) -> bool:
        """
        Returns whether a connection returned from the pool should only match
        the requested tag or if any connection should be returned if none
        matching the tag are available.
        """
        return self._impl.matchanytag

    @matchanytag.setter
    def matchanytag(self, value: bool) -> None:
        self._impl.matchanytag = value

    @property
    def mode(self) -> int:
        """
        Returns the authorization mode to use when connecting to the database.
        """
        return self._impl.mode

    @mode.setter
    def mode(self, value: int) -> None:
        self._impl.mode = value

    @property
    @_address_attr
    def port(self) -> Union[list, int]:
        """
        Returns the port associated with the address in the connect string. If
        the connect string contains multiple addresses, a list of ports is
        returned in the order they appear.
        """
        pass

    @property
    @_address_attr
    def protocol(self) -> Union[list, str]:
        """
        Returns the protocol associated with the address in the connect
        string. If the connect string contains multiple addresses, a list of
        protocols is returned in the order they appear.
        """
        pass

    @property
    def proxy_user(self) -> str:
        """
        Returns the proxy user to use with the connection.
        """
        return self._impl.proxy_user

    @proxy_user.setter
    def proxy_user(self, value: str) -> None:
        self._impl.proxy_user = value

    @property
    @_description_attr
    def purity(self) -> Union[list, int]:
        """
        Returns the purity associated with each description in the connect
        string. If the connect string contains multiple descriptions, a list
        of purity is returned in the order they appear.
        """
        pass

    @property
    @_description_attr
    def service_name(self) -> Union[list, str]:
        """
        Returns the service_names associated with each description in the
        connect string. If the connect string contains multiple descriptions,
        a list of service_names is returned in the order they appear.
        """
        pass

    @property
    def shardingkey(self) -> list:
        """
        Returns the sharding key to use when connecting to the database.
        """
        return self._impl.shardingkey

    @shardingkey.setter
    def shardingkey(self, value: list) -> None:
        self._impl.shardingkey = value

    @property
    def supershardingkey(self) -> list:
        """
        Returns the super sharding key to use when connecting to the database.
        """
        return self._impl.supershardingkey

    @supershardingkey.setter
    def supershardingkey(self, value: list) -> None:
        self._impl.supershardingkey = value

    @property
    @_description_attr
    def sid(self) -> Union[list, str]:
        """
        Returns the sid associated with each description in the connect
        string. If the connect string contains multiple descriptions, a list
        of sid is returned in the order they appear.
        """
        pass

    @property
    @_description_attr
    def retry_count(self) -> Union[list, int]:
        """
        Returns the retry_counts associated with each description in the
        connect string. If the connect string contains multiple descriptions,
        a list of retry_counts is returned in the order they appear.
        """
        pass

    @property
    @_description_attr
    def retry_delay(self) -> Union[list, int]:
        """
        Returns the retry_delays associated with each description in the
        connect string. If the connect string contains multiple descriptions,
        a list of retry_delays is returned in the order they appear.
        """
        pass

    @property
    @_description_attr
    def server_type(self) -> Union[list, str]:
        """
        Returns the type of server connection that should be established. If
        the connect string contains multiple descriptions, a list of
        server_types is returned in the order they appear.
        """
        pass

    @property
    @_description_attr
    def ssl_server_dn_match(self) -> Union[list, bool]:
        """
        Returns the ssl_server_dn_match associated with each description in
        the connect string. If the connect string contains multiple
        descriptions, a list of ssl_server_dn_match is returned in the order
        they appear.
        """
        pass

    @property
    @_description_attr
    def ssl_server_cert_dn(self) -> Union[list, str]:
        """
        Returns the ssl_server_cert_dn associated with each description in
        the connect string. If the connect string contains multiple
        descriptions, a list of ssl_server_cert_dn is returned in the order
        they appear.
        """
        pass

    @property
    def stmtcachesize(self) -> int:
        """
        Returns the size of the statement cache to use when a connection is
        created.
        """
        return self._impl.stmtcachesize

    @stmtcachesize.setter
    def stmtcachesize(self, value: int) -> None:
        self._impl.stmtcachesize = value

    @property
    def tag(self) -> str:
        """
        Returns the tag to use when acquiring a connection from a pool.
        """
        return self._impl.tag

    @tag.setter
    def tag(self, value: str) -> None:
        self._impl.tag = value

    @property
    @_description_attr
    def tcp_connect_timeout(self) -> Union[list, float]:
        """
        Returns the tcp_connect_timeout associated with each description in
        the connect string. If the connect string contains multiple
        descriptions, a list of tcp_connect_timeout is returned in the order
        they appear.
        """
        pass

    @property
    def user(self) -> str:
        """
        Returns the user to use with the connection.
        """
        return self._impl.user

    @user.setter
    def user(self, value: str) -> None:
        self._impl.user = value

    @property
    @_description_attr
    def wallet_location(self) -> Union[list, str]:
        """
        Returns the wallet_location associated with each description in
        the connect string. If the connect string contains multiple
        descriptions, a list of wallet_location is returned in the order
        they appear.
        """
        pass

    def copy(self) -> Type["ConnectParams"]:
        """
        Creates a copy of the parameters and returns it.
        """
        params = ConnectParams.__new__(ConnectParams)
        params._impl = self._impl.copy()
        return params

    def get_connect_string(self) -> str:
        """
        Returns the connect string associated with the parameters. This will
        either be the connect string passed to parse_dsn() or
        parse_connect_string(), or it will be a connect string generated from
        the individual components that were passed when the parameters object
        was created.
        """
        return self._impl.get_connect_string()

    def parse_connect_string(self, connect_string: str) -> None:
        """
        Parses the connect string into its components and stores the
        parameters.  The connect string could be an Easy Connect string,
        name-value pairs or a simple alias which is looked up in tnsnames.ora.
        Any parameters found in the connect string override any currently
        stored values. The connect string itself will also be retained.
        """
        self._impl.parse_connect_string(connect_string)

    def parse_dsn(self, dsn: str, parse_connect_string: bool=False) -> None:
        """
        Parse a dsn (data source name) string supplied by the user. This can be
        in the form user/password@connect_string or it can be the connect
        string by itself. The user, password and connect string that are parsed
        will be retained. If the user is of the form user[proxy_user], the
        proxy user will also be retained.
        """
        self._impl.parse_dsn(dsn, parse_connect_string)
