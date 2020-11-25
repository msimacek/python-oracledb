#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

from . import exceptions

def parse_connect_params(dsn, user, password, host, port, service_name, thin):

    # parse dsn, if present; dsn is expected to be in the form
    # user/password@host:port/service_name with all parts optional
    if dsn is not None:

        # extract user/password from the dsn, if present
        pos = dsn.rfind("@")
        if pos >= 0:
            credentials = dsn[:pos]
            dsn = dsn[pos + 1:]
            pos = credentials.find("/")
            if pos >= 0:
                if user is None:
                    user = credentials[:pos]
                if password is None:
                    password = credentials[pos + 1:]
            elif user is None:
                user = credentials

        # extract host:port/service, if present
        pos = dsn.find("/")
        if pos >= 0:
            if service_name is None:
                service_name = dsn[pos + 1:]
            remainder = dsn[:pos]
            pos = remainder.find(":")
            if pos >= 0:
                if port is None:
                    port = int(remainder[pos + 1:])
                    remainder = remainder[:pos]
            if host is None:
                host = remainder

    # a service name is mandatory for the thin driver
    if thin and service_name is None:
        raise exceptions.InterfaceError("a service name must be specified")

    # assign defaults to host and port, if needed
    if port is None:
        port = 1521
    if host is None:
        host = "localhost"

    # if dsn was not specified but components were, build up dsn as a
    # convenience to the caller
    if dsn is None and service_name is not None:
        dsn = f"{host}:{port}/{service_name}"

    # the thin driver uses the connect data directly
    if thin:
        connect_data = "(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)" + \
                f"(HOST={host})(PORT={port}))" + \
                f"(CONNECT_DATA=(SERVICE_NAME={service_name})))"
    else:
        connect_data = None

    return (dsn, user, password, host, port, connect_data)
