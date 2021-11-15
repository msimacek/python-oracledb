#------------------------------------------------------------------------------
# Copyright (c) 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

import copy
import os
import sys
from typing import Type

from . import constants, errors, exceptions
from .defaults import defaults

class ConnectParams:
    """
    Contains all parameters used for establishing a connection to the
    database.
    """

    # dictionary of tnsnames files, indexed by the directory in which the file
    # is found; the results are cached in order to avoid parsing a file
    # multiple times; the modification time of the file is checked each time,
    # though, to ensure that no changes were made since the last time that the
    # file was read and parsed.
    _tnsnames_files = {}

    def __init__(self, *,
                 host: str=None,
                 port: int=None,
                 service_name: str=None,
                 sid: str=None,
                 events: bool=None,
                 protocol: str="tcp",
                 enable_drcp: bool=False,
                 config_dir: str=None,
                 cclass: str=None,
                 purity: int=constants.PURITY_DEFAULT,
                 mode: int=constants.AUTH_MODE_DEFAULT,
                 edition: str=None,
                 appcontext: list=None,
                 tag: str=None,
                 matchanytag: bool=False,
                 shardingkey: list=None,
                 supershardingkey: list=None,
                 stmtcachesize: int=None,
                 disable_oob: bool=None,
                 ssl_server_dn_match: bool=None,
                 ssl_server_cert_dn: str=None,
                 retry_count: int=0,
                 retry_delay: int=0,
                 expire_time: int=0,
                 tcp_connect_timeout: float=None,
                 wallet_location: str=None,
                 wallet_password: str=None,

                 # deprecated parameters: values are ignored
                 threaded: bool=None,
                 encoding: str=None,
                 nencoding: str=None) -> None:
        """
        Constructor for connection parameters. All parameters are optional.

        host: the name or IP address of the machine hosting the listener (the
        process which handles the initial connection to the database)

        port: the port number on which the listener is listening

        service_name: the service name of the database

        sid: the SID of the database (service_name should be used instead)

        events: boolean specifying whether events mode should be enabled. This
        is only relevant for the thick driver and is needed for continuous
        query notification and high availability event notifications
        (default: oracledb.defaults.events)

        protocol: one of the strings "tcp" or "tcps" indicating whether to use
        unencrypted network traffic or encrypted network traffic (TLS).

        enable_drcp: boolean specifying whether Database Resident Connection
        Pooling (DRCP) should be used

        config_dir: directory in which configuration files (tnsnames.ora) are
        found (default: oracledb.defaults.config_dir)

        cclass: connection class to use for DRCP

        purity: purity to use for DRCP

        mode: authorization mode to use

        edition: edition to use for the connection; this parameter cannot be
        used simultaneously with the cclass parameter

        appcontext: application context used by the connection. It should be a
        list of 3-tuples. Each entry in the tuple is a string and makes up the
        namespace, the name and the value. The value can be referenced in the
        database by using the PL/SQL method sys_context() within logon
        triggers or other PL/SQL procedures.

        tag: identifies the type of connection that should be returned from a
        pool. Only a connection with the requested tag or a connection without
        any tag will be returned unless the matchanytag parameter is True. If
        the matchanytag parameter is True a connection with any tag (or no tag)
        will be returned if no connections with the requested tag are currently
        available. Connections are tagged when they are released back to the
        pool. This parameter is only relevant for the thick driver and only
        when acquiring a connection from a pool.

        matchanytag: boolean specifying whether any tag can be used when
        acquiring a connection from the pool. This parameter is only relevant
        for the thick driver and only when acquiring a connection from a pool.

        shardingkey: a sequence of strings, numbers, bytes or dates that
        identify the database shard to connect to. This parameter is only
        relevant for the thick driver.

        supershardingkey: a sequence of strings, numbers, bytes or dates that
        identify the database shard to connect to. This parameter is only
        relevant for the thick driver.

        stmtcachesize: identifies the initial size of the statement cache
        (default: defaults.stmtcachesize)

        disable_oob: boolean indicating whether out-of-band breaks should be
        disabled (default: defaults.disable_oob). Note that out-of-band breaks
        are not supported on Windows.

        ssl_server_dn_match: boolean indicating whether the server certificate
        distinguished name (DN) should be matched in addition to the regular
        certificate verification that is performed (default:
        defaults.ssl_server_dn_match). Note that if the ssl_server_cert_dn is
        not provided, no matching is done regardless of the value of this
        parameter.

        ssl_server_cert_dn: the distinguished name (DN) which should be matched
        with the server. This value is ignored if the ssl_server_dn_match
        parameter is not set to the value True.

        retry_count: the number of times that a connection attempt should be
        made before the attempt is terminated.

        retry_delay: the number of seconds to wait before making a new
        connection attempt.

        expire_time: an integer indicating the number of minutes between the
        sending of keepalive probes. If this parameter is set to a value
        greater than zero it enables keepalive.

        tcp_connect_timeout: a float indicating the maximum number of seconds
        to wait for establishing a connection to the database host.

        wallet_location: the location where the PEM-encoded wallet file
        ewallet.pem can be found. If this parameter is not set, one-way TLS
        authentication will take place instead.

        wallet_password: the password used to decrypt the contents of the
        PEM-encoded wallet file, if applicable.
        """
        self.host = host
        self.port = port
        self.service_name = service_name
        self.sid = sid
        self.events = events if events is not None else defaults.events
        self._set_protocol(protocol)
        self.enable_drcp = enable_drcp
        self.config_dir = config_dir if config_dir is not None \
                else defaults.config_dir
        self.cclass = cclass
        self.purity = purity
        self.mode = mode
        self.edition = edition
        self.appcontext = appcontext if appcontext is not None else []
        self.tag = tag
        self.matchanytag = matchanytag
        self.shardingkey = shardingkey if shardingkey is not None else []
        self.supershardingkey = supershardingkey \
                if supershardingkey is not None else []
        self.stmtcachesize = stmtcachesize if stmtcachesize is not None \
                else defaults.stmtcachesize
        self.disable_oob = disable_oob if disable_oob is not None \
                else defaults.disable_oob
        self.ssl_server_dn_match = ssl_server_dn_match \
                if ssl_server_dn_match is not None \
                else defaults.ssl_server_dn_match
        self.ssl_server_cert_dn = ssl_server_cert_dn
        self.retry_count = retry_count
        self.retry_delay = retry_delay
        self.expire_time = expire_time
        self.tcp_connect_timeout = tcp_connect_timeout \
                if tcp_connect_timeout is not None \
                else defaults.tcp_connect_timeout
        self.wallet_location = wallet_location
        self.wallet_password = wallet_password

    def __repr__(self):
        return f"ConnectParams(" \
               f"host={self.host!r}, " \
               f"port={self.port!r}, " \
               f"service_name={self.service_name!r}, " \
               f"sid={self.sid!r}, " \
               f"events={self.events!r}, " \
               f"protocol={self.protocol!r}, " \
               f"enable_drcp={self.enable_drcp!r}, " \
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
               f"wallet_location={self.wallet_location!r})"

    def _get_tnsnames_file(self):
        """
        Return a tnsnames file, if one is present, or None if one is not. If
        the file was previously loaded, the modification time is checked and,
        if unchanged, the previous file is returned.
        """
        if self.config_dir is None:
            return None
        file_name = os.path.join(self.config_dir, "tnsnames.ora")
        tnsnames_file = self._tnsnames_files.get(self.config_dir)
        try:
            stat_info = os.stat(file_name)
        except:
            if tnsnames_file is not None:
                del self._tnsnames_files[self.config_dir]
            return None
        if tnsnames_file is not None \
                and tnsnames_file.mtime == stat_info.st_mtime:
            return tnsnames_file
        tnsnames_file = TnsNamesFile(file_name, stat_info.st_mtime)
        tnsnames_file.read()
        self._tnsnames_files[self.config_dir] = tnsnames_file
        return tnsnames_file

    def _parse_time_value(self, value):
        """
        Parse a value that contains time with an optional unit of ms
        (milliseconds), sec (seconds) or min (minutes).
        """
        value = value.lower()
        if value.endswith("sec"):
            return float(value[:-3].strip())
        elif value.endswith("ms"):
            return float(value[:-2].strip()) / 1000
        elif value.endswith("min"):
            return float(value[:-3].strip()) * 60
        return float(value.strip())

    def _parse_connect_descriptor(self, connect_string):
        """
        Internal method used for parsing connect data (name-value pairs).
        """
        node = parse_connect_descriptor(connect_string.strip())
        try:
            description_node = node.description
            temp_val = getattr(description_node, "expire_time", None)
            if temp_val is not None:
                self.expire_time = int(temp_val)
            temp_val = getattr(description_node, "retry_count", None)
            if temp_val is not None:
                self.retry_count = int(temp_val)
            temp_val = getattr(description_node, "retry_delay", None)
            if temp_val is not None:
                self.retry_delay = int(temp_val)
            temp_val = getattr(description_node, "transport_connect_timeout",
                               None)
            if temp_val is not None:
                self.tcp_connect_timeout = self._parse_time_value(temp_val)
            address_node = description_node.address
            self._set_protocol(address_node.protocol.lower())
            self.host = address_node.host
            self.port = int(address_node.port)
            connect_data_node = node.description.connect_data
            self.service_name = getattr(connect_data_node, "service_name",
                                        None)
            self.sid = getattr(connect_data_node, "sid", None)
            temp_val = getattr(connect_data_node, "pool_connection_class",
                               None)
            if temp_val is not None:
                self.cclass = temp_val
            temp_val = getattr(connect_data_node, "pool_purity", None)
            if temp_val is not None:
                temp_val = temp_val.lower()
                if temp_val not in ("new", "self"):
                    errors._raise_err(errors.ERR_INVALID_POOL_PURITY,
                                      purity=temp_val)
                self.purity = constants.PURITY_NEW if temp_val == "new" \
                        else constants.PURITY_ANY
            security_node = getattr(node.description, "security", None)
            if security_node is not None:
                temp_val = getattr(security_node, "ssl_server_cert_dn", None)
                if temp_val is not None:
                    self.ssl_server_cert_dn = temp_val
                temp_val = getattr(security_node, "my_wallet_directory", None)
                if temp_val is not None:
                    self.wallet_location = temp_val
        except exceptions.Error:
            raise
        except Exception as e:
            errors._raise_err(errors.ERR_CANNOT_PARSE_CONNECT_DESCRIPTOR,
                              str(e), data=connect_string)

    def _parse_ezconnect_string(self, connect_string):
        """
        Internal method used for parsing an EZConnect string. A boolean is
        returned indicating whether a string in that format was detected and
        parsed.
        """

        # save original connect string for use in error messages
        user_connect_string = connect_string

        try:

            # parse protocol
            protocol = None
            protocol_pos = connect_string.find("://")
            if protocol_pos > 0:
                protocol = connect_string[:protocol_pos]
                self._set_protocol(protocol.lower())
                connect_string = connect_string[protocol_pos + 3:]

            # parse parameters
            params_pos = connect_string.find("?")
            if params_pos > 0:
                for part in connect_string[params_pos + 1:].split("&"):
                    name, value = [s.strip() for s in part.split("=", 1)]
                    name = name.lower()
                    if value.startswith('"') and value.endswith('"'):
                        value = value[1:-1]
                    if name == "ssl_server_cert_dn":
                        self.ssl_server_cert_dn = value
                    elif name == "ssl_server_dn_match":
                        self.ssl_server_dn_match = value.lower() == "on"
                    elif name == "wallet_location":
                        self.wallet_location = value
                    elif name == "expire_time":
                        self.expire_time = int(value)
                    elif name == "retry_delay":
                        self.retry_delay = int(value)
                    elif name == "retry_count":
                        self.retry_count = int(value)
                    elif name == "transport_connect_timeout":
                        self.tcp_connect_timeout = float(value)
                    else:
                        raise Exception(f"unknown parameter name: {name}")
                connect_string = connect_string[:params_pos]

            # parse service name and server type
            slash_pos = connect_string.find("/")
            if slash_pos < 0:
                self.service_name = ""
            else:
                self.service_name = connect_string[slash_pos + 1:]
                drcp_suffix = ":POOLED"
                if self.service_name.upper().endswith(drcp_suffix):
                    self.enable_drcp = True
                    self.service_name = self.service_name[:-len(drcp_suffix)]
                connect_string = connect_string[:slash_pos]

            # parse host and port
            colon_pos = connect_string.find(":")
            if colon_pos >= 0:
                port = connect_string[colon_pos + 1:]
                self.port = 1521 if not(port) else int(port)
                connect_string = connect_string[:colon_pos]
            elif self.port is None:
                if slash_pos < 0:
                    return False
                self.port = 1521
            self.host = connect_string

            return True

        except exceptions.Error:
            raise
        except Exception as e:
            errors._raise_err(errors.ERR_CANNOT_PARSE_EZCONNECT_STRING,
                              str(e), data=connect_string)

    def _parse_redirect_data(self, redirect_data):
        """
        Internal method used for parsing the redirect data that is returned
        from a listener in order to determine the new host and part that should
        be used to connect to the database.
        """
        pos = redirect_data.find('\x00')
        if pos < 0:
            errors._raise_err(errors.ERR_INVALID_REDIRECT_DATA,
                              data=redirect_data)
        node = parse_connect_descriptor(redirect_data)
        address_node = node.description.address
        self.host = address_node.host
        self.port = int(address_node.port)

    def _search_tnsnames(self, name):
        """
        Internal method used to search the tnsnames.ora file. An exception is
        raised if no entry is found (or no tnsnames.ora file is found).
        """
        tnsnames_file = self._get_tnsnames_file()
        if tnsnames_file is not None:
            search_name = name.upper()
            connect_descriptor = tnsnames_file.entries.get(search_name)
            if connect_descriptor is not None:
                self._parse_connect_descriptor(connect_descriptor)
                return
        errors._raise_err(errors.ERR_TNS_ENTRY_NOT_FOUND, name=name)

    def _set_by_keyword_args(self, keyword_args):
        """
        Set parameters provided as keyword arguments. If a keyword parameter is
        supplied that is not a valid connection parameter, a TypeError
        exception is raised.
        """
        for name in keyword_args:
            if not hasattr(self, name):
                message = f"ConnectParams has no parameter named {name!r}"
                raise TypeError(message)
            setattr(self, name, keyword_args[name])

    def _set_protocol(self, protocol):
        """
        Sets the specified protocol. Only tcp and tcps protocols are supported
        at this time.
        """
        if protocol not in ("tcp", "tcps"):
            errors._raise_err(errors.ERR_INVALID_PROTOCOL, protocol=protocol)
        self.protocol = protocol

    def _supports_oob(self):
        """
        Return a boolean indicating if the platform supports out-of-band urgent
        data (all platforms besides Windows) and a configuration parameter
        hasn't explicitly disabled it.
        """
        if sys.platform == "win32":
            return False
        return not self.disable_oob

    def copy(self) -> Type["ConnectParams"]:
        """
        Creates a copy of the parameters and returns it.
        """
        return copy.copy(self)

    def parse_connect_string(self, connect_string: str) -> None:
        """
        Parses the connect string into its components and store the parameters.
        The connect string could be an EZConnect string, name-value pairs or a
        simple alias which is looked up in tnsnames.ora. Any connect parameters
        found in the connect string override any currently stored values.
        """
        if connect_string.startswith("("):
            self._parse_connect_descriptor(connect_string)
        elif not self._parse_ezconnect_string(connect_string):
            self._search_tnsnames(connect_string)

    def parse_dsn(self, dsn: str) -> None:
        """
        Parse a dsn (data source name) string supplied by the user. This can be
        in the form user/password@connect_string or it can be the connect
        string by itself. A 3-tuple is returned containing the user, password
        and connect string.
        """
        connect_string = dsn
        user = password = None
        pos = dsn.rfind("@")
        if pos >= 0:
            credentials = dsn[:pos]
            connect_string = dsn[pos + 1:]
            pos = credentials.find("/")
            if pos >= 0:
                user = credentials[:pos]
                password = credentials[pos + 1:]
            else:
                user = credentials
        return (user, password, connect_string)


class TnsNamesFile:
    """
    Internal class used to parse and retains connect descriptor entries found
    in a tnsnames.ora file.
    """

    def __init__(self, file_name, mtime):
        self.file_name = file_name
        self.mtime = mtime
        self.entries = {}

    def read(self):
        """
        Read and parse the file and retain the connect descriptors found inside
        the file.
        """
        with open(self.file_name) as f:
            entry_name = None
            for line in f:
                line = line.strip()
                pos = line.find("#")
                if pos >= 0:
                    line = line[:pos]
                if not line:
                    continue
                if entry_name is None:
                    pos = line.find("=")
                    if pos < 0:
                        error_num = errors.ERR_INVALID_TNS_ALIAS_DEFINITION
                        errors._raise_err(error_num, line=line)
                    entry_name = line[:pos].strip().upper()
                    entry_lines = []
                    num_parens = 0
                    line = line[pos+1:].strip()
                if line:
                    num_parens += line.count("(") - line.count(")")
                    entry_lines.append(line)
                if entry_lines and num_parens <= 0:
                    self.entries[entry_name.upper()] = "".join(entry_lines)
                    entry_name = None


class NameValuePairGroup:
    """
    Internal class used to store a set of name-value pairs as attributes.
    """


def parse_connect_descriptor(data, group=None):
    """
    Utility function used to parse name-value pairs in the form (KEY = VALUE)
    where value can itself be another nested set of name-value pairs.
    """
    if data[0] != "(" or data[-1] != ")":
        errors._raise_err(errors.ERR_INVALID_CONNECT_DESCRIPTOR, data=data)
    data = data[1:-1]
    pos = data.find("=")
    if pos < 0:
        errors._raise_err(errors.ERR_INVALID_CONNECT_DESCRIPTOR, data=data)
    name = data[:pos].strip().lower()
    data = data[pos + 1:].strip()
    if not data or not data.startswith("("):
        value = data
        if value and value[0] == '"' and value[-1] == '"':
            value = value[1:-1]
    else:
        value = NameValuePairGroup()
        while data:
            search_pos = 1
            num_opening_parens = 1
            num_closing_parens = 0
            while num_closing_parens < num_opening_parens:
                end_pos = data.find(")", search_pos)
                if end_pos < 0:
                    errors._raise_err(errors.ERR_INVALID_CONNECT_DESCRIPTOR,
                                      data=data)
                num_closing_parens += 1
                num_opening_parens += data.count("(", search_pos, end_pos)
                search_pos = end_pos + 1
            parse_connect_descriptor(data[:end_pos + 1].strip(), value)
            data = data[end_pos + 1:].strip()
    if group is None:
        group = NameValuePairGroup()
    setattr(group, name, value)
    return group
