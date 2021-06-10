#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

import os

from . import exceptions

class ConfigFileCache:
    """
    All configuration files are parsed and the results cached in order to avoid
    parsing a file multiple times. The modification time of the file is checked
    each time, however, to ensure that no changes have taken place since the
    last time that the file was read and parsed.
    """

    def __init__(self):
        self.entries = {}

    def get_config_file(self, config_dir, file_name):
        if config_dir is None:
            return None
        full_file_name = os.path.join(config_dir, file_name)
        entry = self.entries.get(full_file_name)
        try:
            stat_info = os.stat(full_file_name)
        except:
            if entry is not None:
                del self.entries[full_file_name]
            return None
        if entry is not None and entry.mtime == stat_info.st_mtime:
            return entry
        entry = ConfigFile(full_file_name, stat_info.st_mtime)
        entry.read()
        self.entries[full_file_name] = entry
        return entry


# global configuration file cache
_config_file_cache = ConfigFileCache()

def get_config_file(config_dir, file_name):
    """
    Search the global cache for a configuration file and return an entry, if
    the configuration file exists.
    """
    return _config_file_cache.get_config_file(config_dir, file_name)


class ConfigParseError(Exception):
    """
    Exception raised when an error is detected while parsing configuration
    files.
    """


class ConfigNode:
    """
    Simple configuration node that is used to store the information found while
    parsing structured data.
    """


class ConfigFile:
    """
    Parses and retains configuration stored in a file.
    """

    def __init__(self, file_name, mtime):
        self.file_name = file_name
        self.mtime = mtime
        self.entries = {}

    def read(self):
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
                        message = f"line {line} does not have an = character"
                        raise ConfigParseError(message)
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


class ConnectParams:
    """
    Stores connection parameters used for connecting to the database.
    """

    def __init__(self, user=None, password=None, host=None, port=None,
                 service_name=None, secure_transport=False, config_dir=None):
        self.user = user
        self.password = password
        self.host = host
        self.port = port
        self.service_name = service_name
        self.secure_transport = secure_transport
        if config_dir is None:
            config_dir = os.environ.get("TNS_ADMIN")
        self.config_dir = config_dir
        self._dsn = None

    def can_use_oob(self):
        """
        Return a boolean indicating if the platform supports out-of-band urgent
        data and a configuration file hasn't disabled it.
        """
        sqlnet_config = get_config_file(self.config_dir, "sqlnet.ora")
        if sqlnet_config is not None:
            disable_oob = sqlnet_config.entries.get("DISABLE_OOB")
            if disable_oob is not None:
                return disable_oob.lower() != "on"
        return True

    def get_connect_data(self):
        """
        Return normalized connect data used for communicating with the server.
        """
        protocol = "TCPS" if self.secure_transport else "TCP"
        return f"(DESCRIPTION=(ADDRESS=(PROTOCOL={protocol})" + \
               f"(HOST={self.host})(PORT={self.port}))" + \
               f"(CONNECT_DATA=(SERVICE_NAME={self.service_name})(CID=)))"

    def get_dsn(self):
        """
        Return a normalized DSN for use by the caller.
        """
        if self._dsn is None:
            self._dsn = f"{self.host}:{self.port}/{self.service_name}"
        return self._dsn

    def get_wallet_file_name(self):
        """
        Return the name of the file containing the wallet used for TLS
        authentication.
        """
        sqlnet_config = get_config_file(self.config_dir, "sqlnet.ora")
        wallet_dir = self.config_dir
        if sqlnet_config is not None:
            location = sqlnet_config.entries.get("WALLET_LOCATION")
            if location is not None:
                top_node = parse_structured_data(ConfigNode(), location)
                try:
                    wallet_dir = top_node.source.method_data.directory
                except AttributeError:
                    pass
        if wallet_dir is None:
            message = "unable to determine wallet directory"
            raise exceptions.DatabaseError(message)
        file_name = os.path.join(wallet_dir, "wallet.pem")
        if not os.path.exists(file_name):
            message = f"wallet file missing: {file_name}"
            raise exceptions.DatabaseError(message)
        return file_name

    def parse_connect_data(self, connect_data):
        """
        Parse connect data. This will either be in a string form or in an
        already parsed ConfigNode.
        """
        node = parse_structured_data(ConfigNode(), connect_data)
        try:
            address_node = node.description.address
            connect_data_node = node.description.connect_data
            self.host = address_node.host
            self.port = int(address_node.port)
            self.service_name = connect_data_node.service_name
            self.secure_transport = address_node.protocol.lower() == "tcps"
        except AttributeError:
            message = f"invalid connect data: {connect_data}"
            raise ConfigParseError(message)

    def parse_dsn(self, dsn, thin):
        """
        Parse a string provided by the user. This will be in the form
        user/password@connect_string where user and password are optional. The
        connect string will either be in the form host:port/service, a name
        (which will be searched in tnsnames.ora) or a direct connect string
        (such as the values of entries found in tnsnames.ora).
        """

        # extract user/password from the dsn, if present
        pos = dsn.rfind("@")
        if pos >= 0:
            credentials = dsn[:pos]
            dsn = dsn[pos + 1:]
            pos = credentials.find("/")
            if pos >= 0:
                if self.user is None:
                    self.user = credentials[:pos]
                if self.password is None:
                    self.password = credentials[pos + 1:]
            elif self.user is None:
                self.user = credentials

        # store DSN provided by user
        self._dsn = dsn

        # for the thick client, use that DSN without further parsing
        if not thin:
            return

        # check for structured connect data
        if dsn.startswith("("):
            self.parse_connect_data(dsn)
            return

        # otherwise, see if the connect string is in the form host:port/service
        pos = dsn.find("/")
        if pos >= 0:
            if self.service_name is None:
                self.service_name = dsn[pos + 1:]
            remainder = dsn[:pos]
            pos = remainder.find(":")
            if pos >= 0:
                if self.port is None:
                    self.port = int(remainder[pos + 1:])
                remainder = remainder[:pos]
            elif self.port is None:
                self.port = 1521
            if self.host is None:
                self.host = remainder

        # otherwise, look up connect string as a name in tnsnames.ora
        else:
            self.search_tnsnames(dsn.upper())

    def parse_redirect_data(self, redirect_data):
        """
        Parse the redirect data that is returned from a listener in order to
        determine the new host and port that should be used to connect to the
        database.
        """
        pos = redirect_data.find('\x00')
        if pos < 0:
            message = f"invalid redirect data: {redirect_data}"
        adjusted_data = redirect_data[pos + 1:]
        node = parse_structured_data(ConfigNode(), redirect_data[:pos])
        address_node = node.description.address
        self.host = address_node.host
        self.port = int(address_node.port)

    def search_tnsnames(self, name):
        sqlnet_config = get_config_file(self.config_dir, "sqlnet.ora")
        tnsnames_config = get_config_file(self.config_dir, "tnsnames.ora")
        if tnsnames_config is not None:
            connect_data = tnsnames_config.entries.get(name)
            if connect_data is None and sqlnet_config is not None:
                domain_name = sqlnet_config.entries.get("NAMES.DEFAULT_DOMAIN")
                if domain_name is not None:
                    search_name = f"{name}.{domain_name.upper()}"
                    connect_data = tnsnames_config.entries.get(search_name)
            if connect_data is not None:
                self.parse_connect_data(connect_data)
                return
        message = f"unable to find TNS entry name {name}"
        raise exceptions.DatabaseError(message)


def parse_structured_data(node, data):
    """
    Utility function used to parse structured data in the form (KEY = VALUE)
    where value can itself be another nested set of structured data.
    """
    if data[0] != "(" or data[-1] != ")":
        raise ConfigParseError(f"invalid structured data: {data}")
    data = data[1:-1]
    pos = data.find("=")
    if pos < 0:
        raise ConfigParseError(f"invalid structured data: {data}")
    name = data[:pos].strip().lower()
    data = data[pos + 1:].strip()
    if not data or not data.startswith("("):
        value = data
        if value and value[0] == '"' and value[-1] == '"':
            value = value[1:-1]
    else:
        value = ConfigNode()
        while data:
            search_pos = 1
            num_opening_parens = 1
            num_closing_parens = 0
            while num_closing_parens < num_opening_parens:
                end_pos = data.find(")", search_pos)
                if end_pos < 0:
                    raise ConfigParseError(f"invalid structured data: {data}")
                num_closing_parens += 1
                num_opening_parens += data.count("(", search_pos, end_pos)
                search_pos = end_pos + 1
            parse_structured_data(value, data[:end_pos + 1])
            data = data[end_pos + 1:]
    setattr(node, name, value)
    return node
