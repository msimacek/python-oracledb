#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef void _callback_handler(void* context, dpiSubscrMessage* message) with gil:
    cdef:
        Subscription subscr = <Subscription> context
        Message py_message
    if message.errorInfo:
        _raise_from_info(message.errorInfo)
    else:
        py_message = subscr._create_message(message)
        subscr.callback(py_message)


cdef class Subscription(BaseSubscription):
    cdef:
        dpiSubscr* _handle

    def __dealloc__(self):
        if self._handle != NULL:
            dpiSubscr_release(self._handle)

    cdef Message _create_message(self, dpiSubscrMessage* message):
        cdef:
            Message py_message = Message.__new__(Message)
            const char* txid
            list temp
            uint32_t i
        py_message.subscription = self
        py_message.type = message.eventType
        py_message.dbname = message.dbName[:message.dbNameLength].decode()
        if message.txId != NULL:
            txid = <const char*> message.txId
            py_message.txid = txid[:message.txIdLength]
        if message.queueName != NULL:
            py_message.queueName = \
                    message.queueName[:message.queueNameLength].decode()
        if message.consumerName != NULL:
            py_message.consumerName = \
                    message.consumerName[:message.consumerNameLength].decode()
        if message.eventType == DPI_EVENT_OBJCHANGE:
            temp = py_message.tables = []
            for i in range(message.numTables):
                temp.append(self._create_message_table(&message.tables[i]))
        elif message.eventType == DPI_EVENT_QUERYCHANGE:
            temp = py_message.queries = []
            for i in range(message.numQueries):
                temp.append(self._create_message_query(&message.queries[i]))
        return py_message

    cdef MessageQuery _create_message_query(self,
                                            dpiSubscrMessageQuery* query):
        cdef:
            MessageQuery py_query = MessageQuery.__new__(MessageQuery)
            uint32_t i
            list temp
        py_query.id = query.id
        py_query.operation = query.operation
        temp = py_query.tables = []
        for i in range(query.numTables):
            temp.append(self._create_message_table(&query.tables[i]))
        return py_query

    cdef MessageRow _create_message_row(self, dpiSubscrMessageRow* row):
        cdef MessageRow py_row = MessageRow.__new__(MessageRow)
        py_row.operation = row.operation
        py_row.rowid = row.rowid[:row.rowidLength].decode()
        return py_row

    cdef MessageTable _create_message_table(self,
                                            dpiSubscrMessageTable* table):
        cdef:
            MessageTable py_table = MessageTable.__new__(MessageTable)
            uint32_t i
            list temp
        py_table.operation = table.operation
        py_table.name = table.name[:table.nameLength].decode()
        temp = py_table.rows = []
        for i in range(table.numRows):
            temp.append(self._create_message_row(&table.rows[i]))
        return py_table

    cdef int _register_query(self, str sql, object args,
                             uint64_t* query_id) except -1:
        cdef:
            StringBuffer sql_buf = StringBuffer()
            Cursor cursor
        sql_buf.set_value(sql)
        cursor = Cursor.__new__(Cursor, self.connection)
        if dpiSubscr_prepareStmt(self._handle, sql_buf.ptr, sql_buf.length,
                                 &cursor._handle) < 0:
            _raise_from_odpi()
        if args is not None:
            if isinstance(args, dict):
                cursor._bind_by_name(args)
            else:
                cursor._bind_by_position(args)
        cursor._execute()
        if self.qos & DPI_SUBSCR_QOS_QUERY:
            if dpiStmt_getSubscrQueryId(cursor._handle, query_id) < 0:
                _raise_from_odpi()

    cdef int _subscribe(self) except -1:
        cdef:
            Connection thick_connection = self.connection
            StringBuffer ip_address_buf = StringBuffer()
            StringBuffer name_buf = StringBuffer()
            dpiSubscrCreateParams params
            int status
        name_buf.set_value(self.name)
        ip_address_buf.set_value(self.ip_address)
        if dpiContext_initSubscrCreateParams(driver_context, &params) < 0:
            _raise_from_odpi()
        params.subscrNamespace = self.namespace
        params.protocol = self.protocol
        params.qos = self.qos
        params.operations = self.operations
        params.portNumber = self.port
        params.timeout = self.timeout
        params.name = name_buf.ptr
        params.nameLength = name_buf.length
        if self.callback is not None:
            params.callback = _callback_handler
            params.callbackContext = <void*> self
        params.ipAddress = ip_address_buf.ptr
        params.ipAddressLength = ip_address_buf.length
        params.groupingClass = self.grouping_class
        params.groupingType = self.grouping_type
        params.groupingValue = self.grouping_value
        params.clientInitiated = self.client_initiated
        with nogil:
            status = dpiConn_subscribe(thick_connection._handle, &params,
                                       &self._handle)
        if status < 0:
            _raise_from_odpi()
        self.id = params.outRegId

    cdef int _unsubscribe(self, BaseConnection connection) except -1:
        cdef:
            Connection thick_connection = connection
            int status
        with nogil:
            status = dpiConn_unsubscribe(thick_connection._handle,
                                         self._handle)
        if status < 0:
            _raise_from_odpi()
