#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

from . import errors, exceptions
from .thick import driver as thick_driver


def connect(dsn=None, *, user=None, password=None, host=None, port=None,
        service_name=None, thin=True):
    """
    Creates a connection to the database and returns a Connection object.
    """

    # parse dsn, if present; dsn is expected to be in the form
    # user/password@host:port/service with all parts optional
    if dsn is not None:

        # extract user/password from the dsn, if present
        pos = dsn.find("@")
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
            dsn = dsn[:pos]
            pos = dsn.find(":")
            if pos >= 0:
                if port is None:
                    port = int(dsn[pos + 1:])
                    dsn = dsn[:pos]
            if host is None:
                host = dsn

    # a service name is mandatory
    if service_name is None:
        raise exceptions.InterfaceError("a service name must be specified")

    # assign defaults to host and port, if needed
    if port is None:
        port = 1521
    if host is None:
        host = "localhost"

    # establish connection
    connect_data = "(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)" + \
            f"(HOST={host})(PORT={port}))" + \
            f"(CONNECT_DATA=(SERVICE_NAME={service_name})))"
    normalized_dsn = f"{host}:{port}/{service_name}"
    if thin:
        errors._raise_from_string(exceptions.InterfaceError,
                "Thin driver not implemented yet")
    else:
        cls = thick_driver.Connection
    conn = cls(user, normalized_dsn)
    conn._connect(connect_data, password)
    return conn
