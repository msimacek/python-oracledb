#------------------------------------------------------------------------------
# Copyright (c) 2020, 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class BaseConnImpl:

    def __init__(self, user, dsn):
        self.username = user
        self.dsn = dsn

    def begin(self, format_id, transaction_id, branch_id):
        """
        Internal method for beginning a distributed transaction.
        """
        raise NotImplementedError()

    def cancel(self):
        """
        Issues an immediate (asynchronous) abort of any currently executing
        statement.
        """
        raise NotImplementedError()

    def change_password(self, old_password, new_password):
        """
        Changes the password for the user to which the connection is connected.
        """
        raise NotImplementedError()

    def close(self, in_del=False):
        """
        Internal method used to close the connection to the database.
        """
        raise NotImplementedError()

    def commit(self):
        """
        Commits any outstanding connection.
        """
        raise NotImplementedError()

    def create_cursor_impl(self):
        """
        Internal method for creating a cursor implementation.
        """
        raise NotImplementedError()

    def create_queue_impl(self):
        """
        Internal method for creating a queue.
        """
        raise NotImplementedError()

    def create_soda_database_impl(self, conn):
        """
        Internal method for returning a SODA database for the connection.
        """
        raise NotImplementedError()

    def create_subscr_impl(self, object conn, object callback,
                           uint32_t namespace, str name, uint32_t protocol,
                           str ip_address, uint32_t port, uint32_t timeout,
                           uint32_t operations, uint32_t qos,
                           uint8_t grouping_class, uint32_t grouping_value,
                           uint8_t grouping_type, bint client_initiated):
        """
        Internal method for creating a subscription implementation.
        """
        raise NotImplementedError()

    def create_temp_lob_impl(self, DbType dbtype):
        """
        Internal method for creating a LOB implementation.
        """
        raise NotImplementedError()

    def get_call_timeout(self):
        """
        Internal method for returning the call timeout.
        """
        raise NotImplementedError()

    def get_current_schema(self):
        """
        Internal method for returning the current schema.
        """
        raise NotImplementedError()

    def get_edition(self):
        """
        Internal method for returning the edition.
        """
        raise NotImplementedError()

    def get_external_name(self):
        """
        Internal method for returning the external name.
        """
        raise NotImplementedError()

    def get_handle(self):
        """
        Internal method for getting the OCI service context handle.
        """
        raise NotImplementedError()

    def get_internal_name(self):
        """
        Internal method for returning the internal name.
        """
        raise NotImplementedError()

    def get_ltxid(self):
        """
        Internal method for returning the logical transaction id.
        """
        raise NotImplementedError()

    def get_stmt_cache_size(self):
        """
        Internal method for returning the size of the statement cache.
        """
        raise NotImplementedError()

    def get_type(self, conn, name):
        """
        Internal method for returning an object type given its name.
        """
        raise NotImplementedError()

    def get_version(self):
        """
        Return the version associated with the connection.
        """
        raise NotImplementedError()

    def ping(self):
        """
        Pings the database to verify the connection is valid.
        """
        raise NotImplementedError()

    def prepare(self):
        """
        Prepares the distributed transaction for commit. Returns a boolean
        indicating if a commit is in fact needed.
        """
        raise NotImplementedError()

    def rollback(self):
        """
        Rolls back any outstanding connection.
        """
        raise NotImplementedError()

    def set_action(self, value):
        """
        Internal method for setting the action.
        """
        raise NotImplementedError()

    def set_call_timeout(self, value):
        """
        Internal method for setting the call timeout.
        """
        raise NotImplementedError()

    def set_client_identifier(self, value):
        """
        Internal method for setting the client identifier.
        """
        raise NotImplementedError()

    def set_client_info(self, value):
        """
        Internal method for setting the client info.
        """
        raise NotImplementedError()

    def set_current_schema(self, value):
        """
        Internal method for setting the current schema.
        """
        raise NotImplementedError()

    def set_dbop(self, value):
        """
        Internal method for setting the database operation.
        """
        raise NotImplementedError()

    def set_external_name(self, value):
        """
        Internal method for setting the external name.
        """
        raise NotImplementedError()

    def set_internal_name(self, value):
        """
        Internal method for setting the internal name.
        """
        raise NotImplementedError()

    def set_module(self, value):
        """
        Internal method for setting the module.
        """
        raise NotImplementedError()

    def set_stmt_cache_size(self, value):
        """
        Internal method for setting the size of the statement cache.
        """
        raise NotImplementedError()
