#------------------------------------------------------------------------------
# Copyright (c) 2020, 2022, Oracle and/or its affiliates.
# This program is free software: you can modify it and/or redistribute it
# under the terms of:
#
# (i)  the Universal Permissive License v 1.0 or at your option, any
#      later version (http://oss.oracle.com/licenses/upl); and/or
#
# (ii) the Apache License v 2.0. (http://www.apache.org/licenses/LICENSE-2.0)
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# pool.pyx
#
# Cython file defining the base Pool implementation class (embedded in
# base_impl.pyx).
#------------------------------------------------------------------------------

cdef class BasePoolImpl:

    @utils.CheckImpls("acquiring a connection from a pool")
    def acquire(self, str user, str password, str cclass, uint32_t purity,
                str tag, bint matchanytag, list shardingkey,
                list supershardingkey):
        pass

    @utils.CheckImpls("closing a pool")
    def close(self, bint force):
        pass

    @utils.CheckImpls("dropping a connection from a pool")
    def drop(self, conn_impl):
        pass

    @utils.CheckImpls("getting the number of busy connections in a pool")
    def get_busy_count(self):
        pass

    @utils.CheckImpls("getting the 'get' mode of a pool")
    def get_getmode(self):
        pass

    @utils.CheckImpls("getting the maximum lifetime of a connection in a pool")
    def get_max_lifetime_session(self):
        pass

    @utils.CheckImpls("getting the maximum sessions per shard in a pool")
    def get_max_sessions_per_shard(self):
        pass

    @utils.CheckImpls("getting the number of connections open in a pool")
    def get_open_count(self):
        pass

    @utils.CheckImpls("getting the ping interval of a pool")
    def get_ping_interval(self):
        pass

    @utils.CheckImpls("getting whether the SODA metadata cache is enabled")
    def get_soda_metadata_cache(self):
        pass

    @utils.CheckImpls("getting the size of the statement cache in a pool")
    def get_stmt_cache_size(self):
        pass

    @utils.CheckImpls("getting the timeout for idle connections in a pool")
    def get_timeout(self):
        pass

    @utils.CheckImpls("getting the wait timeout for a pool")
    def get_wait_timeout(self):
        pass

    @utils.CheckImpls("reconfiguring a pool")
    def reconfigure(self, uint32_t min, uint32_t max, uint32_t increment):
        pass

    @utils.CheckImpls("setting the 'get' mode of a pool")
    def set_getmode(self, uint8_t value):
        pass

    @utils.CheckImpls("setting the maximum lifetime of a connection a pool")
    def set_max_lifetime_session(self, uint32_t value):
        pass

    @utils.CheckImpls("setting the maximum sessions per shard")
    def set_max_sessions_per_shard(self, uint32_t value):
        pass

    @utils.CheckImpls("setting the ping interval")
    def set_ping_interval(self, int value):
        pass

    @utils.CheckImpls("setting whether the SODA metadata cache is enabled")
    def set_soda_metadata_cache(self, bint value):
        pass

    @utils.CheckImpls("setting the size of the statement cache in a pool")
    def set_stmt_cache_size(self, uint32_t value):
        pass

    @utils.CheckImpls("setting the timeout for idle connections in a pool")
    def set_timeout(self, uint32_t value):
        pass

    @utils.CheckImpls("setting the wait timeout for a pool")
    def set_wait_timeout(self, uint32_t value):
        pass
