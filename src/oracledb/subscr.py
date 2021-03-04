#------------------------------------------------------------------------------
# Copyright (c) 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

class Subscription:

    def __repr__(self):
        return f"<oracledb.Subscription on {self.connection!r}>"

    @classmethod
    def _from_impl(cls, impl):
        subscr = cls.__new__(cls)
        subscr._impl = impl
        return subscr

    @property
    def callback(self):
        """
        Returns the callback that was registered when the subscription was
        created.
        """
        return self._impl.callback

    @property
    def connection(self):
        """
        Returns the connection that was used to register the subscription when
        it was created.
        """
        return self._impl.connection

    @property
    def id(self):
        """
        Returns the value of REGID found in the database view
        USER_CHANGE_NOTIFICATION_REGS or the value of REG_ID found in the
        database view USER_SUBSCR_REGISTRATIONS. For AQ subscriptions, this
        value is 0.
        """
        return self._impl.id

    @property
    def ipAddress(self):
        """
        Returns the IP address used for callback notifications from the
        database server. If not set during construction, this value is None.
        """
        return self._impl.ip_address

    @property
    def name(self):
        """
        Returns the name used to register the subscription when it was created.
        """
        return self._impl.name

    @property
    def namespace(self):
        """
        Returns the namespace used to register the subscription when it was
        created.
        """
        return self._impl.namespace

    @property
    def operations(self):
        """
        Returns the operations that will send notifications for each table or
        query that is registered using this subscription.
        """
        return self._impl.operations

    @property
    def port(self):
        """
        Returns the port used for callback notifications from the database
        server. If not set during construction, this value is zero.
        """
        return self._impl.port

    @property
    def protocol(self):
        """
        Returns the protocol used to register the subscription when it was
        created.
        """
        return self._impl.protocol

    @property
    def qos(self):
        """
        Returns the quality of service flags used to register the subscription
        when it was created.
        """
        return self._impl.qos

    def registerquery(self, statement, args=None):
        """
        Register the query for subsequent notification when tables referenced
        by the query are changed. This behaves similarly to cursor.execute()
        but only queries are permitted and the args parameter, if specified,
        must be a sequence or dictionary. If the qos parameter included the
        flag SUBSCR_QOS_QUERY when the subscription was created, then the ID
        for the registered query is returned; otherwise, None is returned.
        """
        if args is not None and not isinstance(args, (list, dict)):
            raise TypeError("expecting args to be a dictionary or list")
        return self._impl.register_query(statement, args)

    @property
    def timeout(self):
        """
        Returns the timeout (in seconds) that was specified when the
        subscription was created. A value of 0 indicates that there is no
        timeout.
        """
        return self._impl.timeout


class Message:

    def __init__(self, subscription):
        self._subscription = subscription
        self._consumer_name = None
        self._db_name = None
        self._queries = []
        self._queue_name = None
        self._registered = False
        self._tables = []
        self._txid = None
        self._type = 0


    @property
    def consumerName(self):
        """
        Returns the name of the consumer which generated the notification. It
        will be populated if the subscription was created with the namespace
        SUBSCR_NAMESPACE_AQ and the queue is a multiple consumer queue.
        """
        return self._consumer_name

    @property
    def dbname(self):
        """
        Returns the name of the database that generated the notification.
        """
        return self._db_name

    @property
    def queries(self):
        """
        Returns a list of message query objects that give information about
        query result sets changed for this notification. This attribute will be
        an empty list if the qos parameter did not include the flag
        SUBSCR_QOS_QUERY when the subscription was created.
        """
        return self._queries

    @property
    def queueName(self):
        """
        Returns the name of the queue which generated the notification. It will
        only be populated if the subscription was created with the namespace
        SUBSCR_NAMESPACE_AQ.
        """
        return self._queue_name

    @property
    def registered(self):
        """
        Returns whether the subscription which generated this notification is
        still registered with the database. The subscription is automatically
        deregistered with the database when the subscription timeout value is
        reached or when the first notification is sent (when the quality of
        service flag SUBSCR_QOS_DEREG_NFY is used).
        """
        return self._registered

    @property
    def subscription(self):
        """
        Returns the subscription object for which this notification was
        generated.
        """
        return self._subscription

    @property
    def tables(self):
        """
        Returns a list of message table objects that give information about the
        tables changed for this notification. This attribute will be an empty
        list if the qos parameter included the flag SUBSCR_QOS_QUERY when the
        subscription was created.
        """
        return self._tables

    @property
    def txid(self):
        """
        Returns the id of the transaction that generated the notification.
        """
        return self._txid

    @property
    def type(self):
        """
        Returns the type of message that has been sent.
        """
        return self._type


class MessageQuery:

    def __init__(self):
        self._id = 0
        self._operation = 0
        self._tables = []

    @property
    def id(self):
        """
        Returns the query id of the query for which the result set changed. The
        value will match the value returned by Subscription.registerquery()
        when the related query was registered.
        """
        return self._id

    @property
    def operation(self):
        """
        Returns the operation that took place on the query result set that was
        changed. Valid values for this attribute are EVENT_DEREG and
        EVENT_QUERYCHANGE.
        """
        return self._operation

    @property
    def tables(self):
        """
        Returns a list of message table objects that give information about the
        table changes that caused the query result set to change for this
        notification.
        """
        return self._tables


class MessageRow:

    def __init__(self):
        self._operation = 0
        self._rowid = None

    @property
    def operation(self):
        """
        Returns the operation that took place on the row that was changed.
        """
        return self._operation

    @property
    def rowid(self):
        """
        Returns the rowid of the row that was changed.
        """
        return self._rowid


class MessageTable:

    def __init__(self):
        self._name = None
        self._operation = 0
        self._rows = []

    @property
    def name(self):
        """
        Returns the name of the table that was changed.
        """
        return self._name

    @property
    def operation(self):
        """
        Returns the operation that took place on the table that was changed.
        """
        return self._operation

    @property
    def rows(self):
        """
        Returns a list of message row objects that give information about the
        rows changed on the table. This value is only filled in if the qos
        parameter to the Connection.subscribe() method included the flag
        SUBSCR_QOS_ROWIDS.
        """
        return self._rows
