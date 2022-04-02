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

cdef class PoolParamsImpl:

    def __init__(self, dict args):
        self.min = 1
        self.max = 2
        self.increment = 1
        self.getmode = constants.POOL_GETMODE_WAIT
        self.homogeneous = True
        self.ping_interval = 60
        _set_uint_param(args, "min", &self.min)
        _set_uint_param(args, "max", &self.max)
        _set_uint_param(args, "increment", &self.increment)
        self.connectiontype = args.get("connectiontype")
        _set_uint_param(args, "getmode", &self.getmode)
        _set_bool_param(args, "homogeneous", &self.homogeneous)
        _set_bool_param(args, "externalauth", &self.externalauth)
        _set_uint_param(args, "timeout", &self.timeout)
        _set_uint_param_with_deprecated_name(args, "wait_timeout",
                                             "waitTimeout", &self.wait_timeout)
        _set_uint_param_with_deprecated_name(args, "max_lifetime_session",
                                             "maxLifetimeSession",
                                             &self.max_lifetime_session)
        _set_obj_param_with_deprecated_name(args, "session_callback",
                                            "sessionCallback", self)
        _set_uint_param_with_deprecated_name(args, "max_sessions_per_shard",
                                             "maxSessionsPerShard",
                                             &self.max_sessions_per_shard)
        _set_bool_param(args, "soda_metadata_cache", &self.soda_metadata_cache)
        _set_int_param(args, "ping_interval", &self.ping_interval)
