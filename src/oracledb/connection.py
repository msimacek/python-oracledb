#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

from . import constants, errors, exceptions
from .thick import driver as thick_driver
from .thin import driver as thin_driver

def connect(dsn=None, *, user=None, password=None, host=None, port=None,
            service_name=None, thin=True, mode=constants.DEFAULT_AUTH,
            handle=0, pool=None, threaded=False, events=False, cclass=None,
            purity=constants.ATTR_PURITY_DEFAULT, newpassword=None,
            edition=None, appcontext=[], tag=None, matchanytag=False,
            shardingkey=[], supershardingkey=[]):
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
            remainder = dsn[:pos]
            pos = remainder.find(":")
            if pos >= 0:
                if port is None:
                    port = int(remainder[pos + 1:])
                    remainder = remainder[:pos]
            if host is None:
                host = remainder

    # a service name is mandatory
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

    # establish connection
    if thin:
        connect_data = "(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)" + \
                f"(HOST={host})(PORT={port}))" + \
                f"(CONNECT_DATA=(SERVICE_NAME={service_name})))"
        conn = thin_driver.Connection(user, dsn)
        conn._connect(host, port, connect_data, password)
    else:
        conn = thick_driver.Connection(user, dsn)
        conn._connect(password=password, mode=mode, handle=handle,
                      threaded=threaded, events=events, cclass=cclass,
                      purity=purity, newpassword=newpassword, edition=edition,
                      appcontext=appcontext, shardingkey=shardingkey,
                      supershardingkey=supershardingkey)
    return conn
