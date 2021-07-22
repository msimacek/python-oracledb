#------------------------------------------------------------------------------
# Copyright (c) 2020, 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class BaseSubscrImpl:

    @utils.CheckImpls("registering a query on a subscription")
    def register_query(self, str sql, object args):
        pass

    @utils.CheckImpls("creating a subscription")
    def subscribe(self, object subscr, BaseConnImpl conn_impl):
        pass

    @utils.CheckImpls("destroying a subscription")
    def unsubscribe(self, BaseConnImpl conn_impl):
        pass


cdef class Message:
    pass


cdef class MessageQuery:
    pass


cdef class MessageRow:
    pass


cdef class MessageTable:
    pass
