#------------------------------------------------------------------------------
# Copyright (c) 2020, 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class BaseConnImpl:

    def __init__(self, user, dsn):
        self.username = user
        self.dsn = dsn

    @utils.CheckImpls("beginning a distributed transaction")
    def begin(self, format_id, transaction_id, branch_id):
        pass

    @utils.CheckImpls("aborting a currently executing statement")
    def cancel(self):
        pass

    @utils.CheckImpls("changing a password")
    def change_password(self, old_password, new_password):
        pass

    @utils.CheckImpls("closing a connection")
    def close(self, in_del=False):
        pass

    @utils.CheckImpls("committing a transaction")
    def commit(self):
        pass

    @utils.CheckImpls("creating a cursor")
    def create_cursor_impl(self):
        pass

    @utils.CheckImpls("creating a queue")
    def create_queue_impl(self):
        pass

    @utils.CheckImpls("creating a SODA database object")
    def create_soda_database_impl(self, conn):
        pass

    @utils.CheckImpls("creating a subscription")
    def create_subscr_impl(self, object conn, object callback,
                           uint32_t namespace, str name, uint32_t protocol,
                           str ip_address, uint32_t port, uint32_t timeout,
                           uint32_t operations, uint32_t qos,
                           uint8_t grouping_class, uint32_t grouping_value,
                           uint8_t grouping_type, bint client_initiated):
        pass

    @utils.CheckImpls("creating a temporary LOB")
    def create_temp_lob_impl(self, DbType dbtype):
        pass

    @utils.CheckImpls("getting the call timeout")
    def get_call_timeout(self):
        pass

    @utils.CheckImpls("getting the current schema")
    def get_current_schema(self):
        pass

    @utils.CheckImpls("getting the edition")
    def get_edition(self):
        pass

    @utils.CheckImpls("getting the external name")
    def get_external_name(self):
        pass

    @utils.CheckImpls("getting the OCI service context handle")
    def get_handle(self):
        pass

    @utils.CheckImpls("getting the internal name")
    def get_internal_name(self):
        pass

    @utils.CheckImpls("getting the logical transaction id")
    def get_ltxid(self):
        pass

    @utils.CheckImpls("getting the statement cache size")
    def get_stmt_cache_size(self):
        pass

    @utils.CheckImpls("getting an object type")
    def get_type(self, str name):
        pass

    @utils.CheckImpls("getting the database version")
    def get_version(self):
        pass

    @utils.CheckImpls("pinging the database")
    def ping(self):
        pass

    @utils.CheckImpls("preparing a global transaction for commit")
    def prepare(self):
        pass

    @utils.CheckImpls("rolling back a transaction")
    def rollback(self):
        pass

    @utils.CheckImpls("setting the action")
    def set_action(self, value):
        pass

    @utils.CheckImpls("setting the call timeout")
    def set_call_timeout(self, value):
        pass

    @utils.CheckImpls("setting the client identifier")
    def set_client_identifier(self, value):
        pass

    @utils.CheckImpls("setting the client info")
    def set_client_info(self, value):
        pass

    @utils.CheckImpls("setting the current schema")
    def set_current_schema(self, value):
        pass

    @utils.CheckImpls("setting the database operation")
    def set_dbop(self, value):
        pass

    @utils.CheckImpls("setting the external name")
    def set_external_name(self, value):
        pass

    @utils.CheckImpls("setting the internal name")
    def set_internal_name(self, value):
        pass

    @utils.CheckImpls("setting the module")
    def set_module(self, value):
        pass

    @utils.CheckImpls("setting the statement cache size")
    def set_stmt_cache_size(self, value):
        pass

    @utils.CheckImpls("shutting down the database")
    def shutdown(self, uint32_t mode):
        pass

    @utils.CheckImpls("starting up the database")
    def startup(self, bint force, bint restrict, str pfile):
        pass
