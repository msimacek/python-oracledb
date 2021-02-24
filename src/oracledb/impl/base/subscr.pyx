#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class BaseSubscription:

    def __repr__(self):
        return f"<oracledb.Subscription on {self.connection!r}>"

    cdef int _register_query(self, str sql, object args,
                             uint64_t* query_id) except -1:
        """
        Internal method for registering a query.
        """
        raise NotImplementedError()

    cdef int _unsubscribe(self, BaseConnImpl connection) except -1:
        """
        Internal method for destroying the subscription.
        """
        raise NotImplementedError()

    @property
    def ipAddress(self):
        return self.ip_address

    def registerquery(self, sql, args=None):
        cdef uint64_t query_id
        if args is not None and not isinstance(args, (list, dict)):
            raise TypeError("expecting args to be a dictionary or list")
        self._register_query(sql, args, &query_id)
        if self.qos & constants.SUBSCR_QOS_QUERY:
            return query_id

    def subscribe(self):
        """
        Internal method for creating the subscription.
        """
        raise NotImplementedError()


cdef class Message:
    pass


cdef class MessageQuery:
    pass


cdef class MessageRow:
    pass


cdef class MessageTable:
    pass
