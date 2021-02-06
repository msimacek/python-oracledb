#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class BaseConnection:

    def __init__(self, user, dsn):
        self.username = user
        self.dsn = dsn

    def __enter__(self):
        self._verify_connected()
        return self

    def __exit__(self, exc_type, exc_value, exc_tb):
        self.close()

    def __repr__(self):
        cls_name = type(self).__name__
        if self.username is None:
            return f"<oracledb.{cls_name} to externally identified user>"
        return f"<oracledb.{cls_name} to {self.username}@{self.dsn}>"

    cdef int _begin(self, long format_id, str transaction_id,
                    str branch_id) except -1:
        """
        Internal method for beginning a distributed transaction.
        """
        raise NotImplementedError()

    cdef int _cancel(self) except -1:
        """
        Internal method for breaking execution of any currently executing
        statement.
        """
        raise NotImplementedError()

    cdef int _change_password(self, str old_password,
                              str new_password) except -1:
        """
        Internal method for changing the password.
        """
        raise NotImplementedError()

    cdef int _close(self) except -1:
        """
        Internal method for closing the connection.
        """
        raise NotImplementedError()

    cdef int _commit(self) except -1:
        """
        Internal method for committing the transaction.
        """
        raise NotImplementedError()

    cdef BaseCursor _create_cursor(self):
        """
        Internal method for creating a cursor.
        """
        raise NotImplementedError()

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

    cdef BaseSubscription _create_subscription(self):
        """
        Internal method for creating a subscription.
        """
        raise NotImplementedError()

    cdef BaseLob _create_temp_lob(self, DbType dbtype):
        """
        Internal method for creating a temporary LOB.
        """
        raise NotImplementedError()

    cdef str _get_current_schema(self):
        """
        Internal method for returning the current schema.
        """
        raise NotImplementedError()

    cdef str _get_edition(self):
        """
        Internal method for returning the edition.
        """
        raise NotImplementedError()

    cdef str _get_external_name(self):
        """
        Internal method for returning the external name.
        """
        raise NotImplementedError()

    cdef str _get_internal_name(self):
        """
        Internal method for returning the internal name.
        """
        raise NotImplementedError()

    cdef bytes _get_ltxid(self):
        """
        Internal method for returning the logical transaction id.
        """
        raise NotImplementedError()

    cdef BaseSodaDatabase _get_soda_database(self):
        """
        Internal method for returning a SODA database for the connection.
        """
        raise NotImplementedError()

    cdef int _get_stmtcachesize(self, uint32_t *value) except -1:
        """
        Internal method for returning the size of the statement cache.
        """
        raise NotImplementedError()

    cdef int _get_calltimeout(self, uint32_t *value) except -1:
        """
        Internal method for returning the call timeout.
        """
        raise NotImplementedError()

    cdef BaseDbObjectType _get_type(self, str name):
        """
        Internal method for returning an object type given its name.
        """
        raise NotImplementedError()

    cdef str _get_version(self):
        """
        Return the version associated with the connection.
        """
        raise NotImplementedError()

    cdef int _ping(self) except -1:
        """
        Internal method for pinging the database.
        """
        raise NotImplementedError()

    cdef int _prepare(self, bint *commit_needed) except -1:
        """
        Internal method for preparing to commit a distributed transaction.
        """
        raise NotImplementedError()

    cdef int _rollback(self) except -1:
        """
        Internal method for rolling back the transaction.
        """
        raise NotImplementedError()

    cdef int _set_action(self, str value) except -1:
        """
        Internal method for setting the action.
        """
        raise NotImplementedError()

    cdef int _set_client_identifier(self, str value) except -1:
        """
        Internal method for setting the client identifier.
        """
        raise NotImplementedError()

    cdef int _set_client_info(self, str value) except -1:
        """
        Internal method for setting the client info.
        """
        raise NotImplementedError()

    cdef int _set_current_schema(self, str value) except -1:
        """
        Internal method for setting the current schema.
        """
        raise NotImplementedError()

    cdef int _set_dbop(self, str value) except -1:
        """
        Internal method for setting the database operation.
        """
        raise NotImplementedError()

    cdef int _set_external_name(self, str value) except -1:
        """
        Internal method for setting the external name.
        """
        raise NotImplementedError()

    cdef int _set_internal_name(self, str value) except -1:
        """
        Internal method for setting the internal name.
        """
        raise NotImplementedError()

    cdef int _set_module(self, str value) except -1:
        """
        Internal method for setting the module.
        """
        raise NotImplementedError()

    cdef int _set_stmtcachesize(self, uint32_t value) except -1:
        """
        Internal method for setting the size of the statement cache.
        """
        raise NotImplementedError()

    cdef int _set_calltimeout(self, uint32_t value) except -1:
        """
        Internal method for setting the call timeout.
        """
        raise NotImplementedError()

    cdef int _verify_connected(self) except -1:
        """
        Verifies that the connection is connected to the database. If it is not
        an exception is raised.
        """
        if not self._is_connected:
            errors._raise_from_string(exceptions.InterfaceError,
                                      "not connected")

    @property
    def action(self):
        raise AttributeError("action is not readable")

    @action.setter
    def action(self, value):
        self._verify_connected()
        self._set_action(value)

    def begin(self, format_id=-1, transaction_id="", branch_id=""):
        """
        Begins a distributed transaction.
        """
        self._verify_connected()
        self._begin(format_id, transaction_id, branch_id)

    def cancel(self):
        """
        Issues an immediate (asynchronous) abort of any currently executing
        statement.
        """
        self._verify_connected()
        self._cancel()

    def changepassword(self, old_password, new_password):
        """
        Changes the password for the user to which the connection is connected.
        """
        self._verify_connected()
        self._change_password(old_password, new_password)

    @property
    def client_identifier(self):
        raise AttributeError("client_identifier is not readable")

    @client_identifier.setter
    def client_identifier(self, value):
        self._verify_connected()
        self._set_client_identifier(value)

    @property
    def clientinfo(self):
        raise AttributeError("clientinfo is not readable")

    @clientinfo.setter
    def clientinfo(self, value):
        self._verify_connected()
        self._set_client_info(value)

    def close(self):
        """
        Closes the connection and makes it unusable for further operations.
        """
        self._verify_connected()
        self._close()
        self._is_connected = False

    def commit(self):
        """
        Commits any outstanding connection.
        """
        self._verify_connected()
        self._commit()

    def createlob(self, lob_type):
        """
        Create and return a new temporary LOB of the specified type.
        """
        self._verify_connected()
        if lob_type not in (DB_TYPE_CLOB, DB_TYPE_NCLOB, DB_TYPE_BLOB):
            message = "parameter should be one of oracledb.DB_TYPE_CLOB, " \
                      "oracledb.DB_TYPE_BLOB or oracledb.DB_TYPE_NCLOB"
            raise TypeError(message)
        return self._create_temp_lob(lob_type)

    @property
    def current_schema(self):
        self._verify_connected()
        return self._get_current_schema()

    @current_schema.setter
    def current_schema(self, value):
        self._verify_connected()
        self._set_current_schema(value)

    def cursor(self, scrollable=False):
        """
        Returns a cursor associated with the connection.
        """
        cdef BaseCursor cursor
        cursor = self._create_cursor()
        cursor.scrollable = scrollable
        return cursor

    @property
    def dbop(self):
        raise AttributeError("dbop is not readable")

    @dbop.setter
    def dbop(self, value):
        self._verify_connected()
        self._set_dbop(value)

    @property
    def edition(self):
        self._verify_connected()
        return self._get_edition()

    @property
    def external_name(self):
        self._verify_connected()
        return self._get_external_name()

    @external_name.setter
    def external_name(self, value):
        self._verify_connected()
        self._set_external_name(value)

    def getSodaDatabase(self):
        self._verify_connected()
        return self._get_soda_database()

    def gettype(self, name):
        self._verify_connected()
        return self._get_type(name)

    @property
    def internal_name(self):
        self._verify_connected()
        return self._get_internal_name()

    @internal_name.setter
    def internal_name(self, value):
        self._verify_connected()
        self._set_internal_name(value)

    @property
    def ltxid(self):
        self._verify_connected()
        return self._get_ltxid()

    @property
    def module(self):
        raise AttributeError("module is not readable")

    @module.setter
    def module(self, value):
        self._verify_connected()
        self._set_module(value)

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
        self._verify_connected()
        self._ping()

    def prepare(self):
        """
        Prepares the distributed transaction for commit. Returns a boolean
        indicating if a commit is in fact needed.
        """
        cdef bint commit_needed
        self._verify_connected()
        self._prepare(&commit_needed)
        return commit_needed

    def queue(self, name, payloadType=None):
        """
        Returns a queue used to enqueue and dequeue messages in AQ.
        """
        cdef BaseQueue queue
        self._verify_connected()
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
        self._verify_connected()
        self._rollback()

    @property
    def stmtcachesize(self):
        cdef uint32_t value
        self._verify_connected()
        self._get_stmtcachesize(&value)
        return value

    @stmtcachesize.setter
    def stmtcachesize(self, value):
        self._verify_connected()
        self._set_stmtcachesize(value)

    @property
    def callTimeout(self):
        cdef uint32_t value
        self._verify_connected()
        self._get_calltimeout(&value)
        return value

    @callTimeout.setter
    def callTimeout(self, value):
        self._verify_connected()
        self._set_calltimeout(value)

    def subscribe(self, namespace=constants.SUBSCR_NAMESPACE_DBCHANGE,
                  protocol=constants.SUBSCR_PROTOCOL_CALLBACK, callback=None,
                  timeout=0, operations=constants.OPCODE_ALLOPS, port=0,
                  qos=constants.SUBSCR_QOS_DEFAULT, ipAddress=None,
                  groupingClass=constants.SUBSCR_GROUPING_CLASS_NONE,
                  groupingValue=0,
                  groupingType=constants.SUBSCR_GROUPING_TYPE_SUMMARY,
                  name=None, clientInitiated=False):
        cdef BaseSubscription subscr
        subscr = self._create_subscription()
        subscr.connection = self
        subscr.callback = callback
        subscr.namespace = namespace
        subscr.name = name
        subscr.protocol = protocol
        subscr.ip_address = ipAddress
        subscr.port = port
        subscr.timeout = timeout
        subscr.operations = operations
        subscr.qos = qos
        subscr.grouping_class = groupingClass
        subscr.grouping_value = groupingValue
        subscr.grouping_type = groupingType
        subscr.client_initiated = clientInitiated
        subscr._subscribe()
        return subscr

    def unsubscribe(self, subscr):
        cdef BaseSubscription common_subscr = subscr
        self._verify_connected()
        common_subscr._unsubscribe(self)

    @property
    def version(self):
        if self._version is None:
            self._version = self._get_version()
        return self._version
