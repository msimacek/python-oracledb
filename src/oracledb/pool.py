#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

from . import constants, utils
from .thick import driver as thick_driver
from .thin import driver as thin_driver

def create_pool(dsn=None, *, user=None, password=None, host=None, port=None,
                service_name=None, thin=True, min=1, max=2, increment=1,
                threaded=False, getmode=constants.POOL_GETMODE_NOWAIT,
                events=False, homogeneous=True, externalauth=False,
                edition=None, timeout=0, wait_timeout=0,
                max_lifetime_session=0, session_callback=None,
                max_sessions_per_shard=0):
    """
    """
    result = utils.parse_connect_params(dsn, user, password, host, port,
                                        service_name, thin)
    dsn, user, password, host, port, connect_data = result
    if thin:
        pool = thin_driver.Pool(user, dsn, min, max, increment, homogeneous)
        pool._create(host, port, connect_data, password)
    else:
        pool = thick_driver.Pool(user, dsn, min, max, increment, homogeneous)
        pool._create(user=user, password=password, min=min, max=max,
                     increment=increment, threaded=threaded, getmode=getmode,
                     events=events, homogeneous=homogeneous,
                     externalauth=externalauth, edition=edition,
                     timeout=timeout, wait_timeout=wait_timeout,
                     max_lifetime_session=max_lifetime_session,
                     session_callback=session_callback,
                     max_sessions_per_shard=max_sessions_per_shard)
    return pool
