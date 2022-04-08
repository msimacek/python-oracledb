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

#------------------------------------------------------------------------------
# pool_params.pyx
#
# Cython file defining the base PoolParams implementation class (embedded in
# base_impl.pyx).
#------------------------------------------------------------------------------

cdef class PoolParamsImpl(ConnectParamsImpl):

    def __init__(self):
        ConnectParamsImpl.__init__(self)
        self.min = 1
        self.max = 2
        self.increment = 1
        self.getmode = constants.POOL_GETMODE_WAIT
        self.homogeneous = True
        self.ping_interval = 60

    cdef int _copy(self, ConnectParamsImpl other_params) except -1:
        """
        Internal method for copying attributes from another set of parameters.
        """
        cdef PoolParamsImpl pool_params = <PoolParamsImpl> other_params
        ConnectParamsImpl._copy(self, other_params)
        self.min = pool_params.min
        self.max = pool_params.max
        self.increment = pool_params.increment
        self.connectiontype = pool_params.connectiontype
        self.getmode = pool_params.getmode
        self.homogeneous = pool_params.homogeneous
        self.externalauth = pool_params.externalauth
        self.timeout = pool_params.timeout
        self.wait_timeout = pool_params.wait_timeout
        self.max_lifetime_session = pool_params.max_lifetime_session
        self.session_callback = pool_params.session_callback
        self.max_sessions_per_shard = pool_params.max_sessions_per_shard
        self.soda_metadata_cache = pool_params.soda_metadata_cache
        self.ping_interval = pool_params.ping_interval

    def copy(self):
        """
        Creates a copy of the connection parameters and returns it.
        """
        cdef PoolParamsImpl new_params
        new_params = PoolParamsImpl.__new__(PoolParamsImpl)
        new_params._copy(self)
        return new_params

    def set(self, dict args):
        """
        Sets the property values based on the supplied arguments. All values
        not supplied will be left unchanged.
        """
        ConnectParamsImpl.set(self, args)
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
