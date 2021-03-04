#------------------------------------------------------------------------------
# Copyright (c) 2020, 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class BaseConnImpl:

    def __init__(self, user, dsn):
        self.username = user
        self.dsn = dsn

    cdef BaseMsgProps _create_msg_props(self):
        """
        Internal method for creating a message property object.
        """
        raise NotImplementedError()

    cdef BaseQueue _create_queue(self):
        """
        Internal method for creating a queue.
        """
        raise NotImplementedError()

    cdef BaseSubscription _create_subscription(self, object connection):
        """
        Internal method for creating a subscription.
        """
        raise NotImplementedError()

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

    def get_soda_database(self, conn):
        """
        Internal method for returning a SODA database for the connection.
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

    def msgproperties(self, payload=None, correlation=None, delay=None,
                      exceptionq=None, expiration=None, priority=None):
        """
        Create and return a message properties object. If the parameters are
        not None, they act as a shortcut for setting each of the equivalently
        named properties.
        """
        cdef BaseMsgProps props = self._create_msg_props()
        if payload is not None:
            props.payload = payload
        if correlation is not None:
            props.correlation = correlation
        if delay is not None:
            props.delay = delay
        if exceptionq is not None:
            props.exceptionq = exceptionq
        if expiration is not None:
            props.expiration = expiration
        if priority is not None:
            props.priority = priority
        return props

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

    def queue(self, name, payloadType=None):
        """
        Returns a queue used to enqueue and dequeue messages in AQ.
        """
        cdef BaseQueue queue
        queue = self._create_queue()
        queue.connection = self
        queue.name = name
        queue.payloadType = payloadType
        queue._initialize()
        return queue

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

    def unsubscribe(self, subscr):
        cdef BaseSubscription common_subscr = subscr
        common_subscr._unsubscribe(self)
