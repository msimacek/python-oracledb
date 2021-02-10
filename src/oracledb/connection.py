#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

from . import constants, errors, exceptions, utils
from . import thick_impl, thin_impl

def connect(dsn=None, *, user=None, password=None, host=None, port=None,
            service_name=None, thin=True, mode=constants.DEFAULT_AUTH,
            handle=0, pool=None, threaded=False, events=False, cclass=None,
            purity=constants.ATTR_PURITY_DEFAULT, newpassword=None,
            edition=None, appcontext=[], tag=None, matchanytag=False,
            shardingkey=[], supershardingkey=[]):
    """
    Creates a connection to the database and returns a Connection object.
    """
    result = utils.parse_connect_params(dsn, user, password, host, port,
                                        service_name, thin)
    dsn, user, password, host, port, connect_data = result
    if thin:
        conn = thin_impl.Connection(user, dsn)
        conn._connect(host, port, connect_data, password)
    else:
        conn = thick_impl.Connection(user, dsn)
        conn._connect(password=password, mode=mode, handle=handle,
                      pool=pool, threaded=threaded, events=events,
                      cclass=cclass, purity=purity, newpassword=newpassword,
                      edition=edition, appcontext=appcontext, tag=tag,
                      matchanytag=matchanytag, shardingkey=shardingkey,
                      supershardingkey=supershardingkey)
    return conn
