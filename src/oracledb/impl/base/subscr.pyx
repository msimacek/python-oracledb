#------------------------------------------------------------------------------
# Copyright (c) 2020, 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class BaseSubscrImpl:

    def register_query(self, str sql, object args):
        """
        Internal method for registering a query.
        """
        raise NotImplementedError()

    def subscribe(self, object subscr, BaseConnImpl conn_impl):
        """
        Internal method for creating the subscription.
        """
        raise NotImplementedError()

    def unsubscribe(self, BaseConnImpl conn_impl):
        """
        Internal method for destroying the subscription.
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
