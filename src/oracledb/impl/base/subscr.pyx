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
