#------------------------------------------------------------------------------
# Copyright (c) 2020, 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class ThickQueueImpl(BaseQueueImpl):
    cdef:
        dpiQueue* _handle

    def __dealloc__(self):
        if self._handle != NULL:
            dpiQueue_release(self._handle)

    def deq_many(self, uint32_t max_num_messages):
        """
        Internal method for dequeuing multiple message from a queue.
        """
        cdef:
            uint32_t num_props = max_num_messages, processed_props = 0, i
            dpiMsgProps** handles
            ThickMsgPropsImpl props
            ssize_t num_bytes
            list result
            int status
        result = []
        num_bytes = num_props * sizeof(dpiMsgProps*)
        handles = <dpiMsgProps**> cpython.PyMem_Malloc(num_bytes)
        try:
            with nogil:
                status = dpiQueue_deqMany(self._handle, &num_props, handles)
            if status < 0:
                _raise_from_odpi()
            for i in range(num_props):
                props = ThickMsgPropsImpl.__new__(ThickMsgPropsImpl)
                props._handle = handles[i]
                processed_props += 1
                props._initialize(self.payload_type)
                result.append(props)
        finally:
            for i in range(processed_props, num_props):
                dpiMsgProps_release(handles[i])
            cpython.PyMem_Free(handles)
        return result

    def deq_one(self):
        """
        Internal method for dequeuing a single message from a queue.
        """
        cdef:
            ThickMsgPropsImpl props
            int status
        props = ThickMsgPropsImpl.__new__(ThickMsgPropsImpl)
        with nogil:
            status = dpiQueue_deqOne(self._handle, &props._handle)
        if status < 0:
            _raise_from_odpi()
        if props._handle != NULL:
            props._initialize(self.payload_type)
            return props

    def enq_many(self, list props_impls):
        """
        Internal method for enqueuing many messages into a queue.
        """
        cdef:
            uint32_t i, num_props = 0
            ThickMsgPropsImpl props
            dpiMsgProps **handles
            ssize_t num_bytes
            int status
        num_props = <uint32_t> len(props_impls)
        num_bytes = num_props * sizeof(dpiMsgProps*)
        handles = <dpiMsgProps**> cpython.PyMem_Malloc(num_bytes)
        for i, props in enumerate(props_impls):
            handles[i] = props._handle
        with nogil:
            status = dpiQueue_enqMany(self._handle, num_props, handles)
        cpython.PyMem_Free(handles)
        if status < 0:
            _raise_from_odpi()

    def enq_one(self, ThickMsgPropsImpl props_impl):
        """
        Internal method for enqueuing a single message into a queue.
        """
        cdef int status
        with nogil:
            status = dpiQueue_enqOne(self._handle, props_impl._handle)
        if status < 0:
            _raise_from_odpi()

    def initialize(self, ThickConnImpl conn_impl, str name,
                   DbObjectType payload_type):
        """
        Internal method for initializing the queue.
        """
        cdef:
            ThickDeqOptionsImpl deq_options_impl
            ThickEnqOptionsImpl enq_options_impl
            dpiObjectType* type_handle = NULL
            StringBuffer buf = StringBuffer()
        buf.set_value(name)
        if payload_type is not None:
            type_handle = payload_type._handle
        if dpiConn_newQueue(conn_impl._handle, buf.ptr, buf.length,
                            type_handle, &self._handle) < 0:
            _raise_from_odpi()
        deq_options_impl = ThickDeqOptionsImpl.__new__(ThickDeqOptionsImpl)
        if dpiQueue_getDeqOptions(self._handle, &deq_options_impl._handle) < 0:
            _raise_from_odpi()
        self.deq_options_impl = deq_options_impl
        enq_options_impl = ThickEnqOptionsImpl.__new__(ThickEnqOptionsImpl)
        if dpiQueue_getEnqOptions(self._handle, &enq_options_impl._handle) < 0:
            _raise_from_odpi()
        self.enq_options_impl = enq_options_impl
        self.payload_type = payload_type
        self.name = name


cdef class ThickDeqOptionsImpl(BaseDeqOptionsImpl):
    cdef:
        dpiDeqOptions* _handle

    def __dealloc__(self):
        if self._handle != NULL:
            dpiDeqOptions_release(self._handle)

    def get_condition(self):
        """
        Internal method for getting the condition.
        """
        cdef:
            uint32_t value_length
            const char *value
        if dpiDeqOptions_getCondition(self._handle, &value, &value_length) < 0:
            _raise_from_odpi()
        if value != NULL:
            return value[:value_length].decode()

    def get_consumer_name(self):
        """
        Internal method for getting the consumer name.
        """
        cdef:
            uint32_t value_length
            const char *value
        if dpiDeqOptions_getConsumerName(self._handle, &value,
                                         &value_length) < 0:
            _raise_from_odpi()
        if value != NULL:
            return value[:value_length].decode()

    def get_correlation(self):
        """
        Internal method for getting the correlation.
        """
        cdef:
            uint32_t value_length
            const char *value
        if dpiDeqOptions_getCorrelation(self._handle, &value,
                                        &value_length) < 0:
            _raise_from_odpi()
        if value != NULL:
            return value[:value_length].decode()

    def get_message_id(self):
        """
        Internal method for getting the message id.
        """
        cdef:
            uint32_t value_length
            const char *value
        if dpiDeqOptions_getMsgId(self._handle, &value, &value_length) < 0:
            _raise_from_odpi()
        if value != NULL:
            return value[:value_length]

    def get_mode(self):
        """
        Internal method for getting the mode.
        """
        cdef uint32_t value
        if dpiDeqOptions_getMode(self._handle, &value) < 0:
            _raise_from_odpi()
        return value

    def get_navigation(self):
        """
        Internal method for getting the navigation.
        """
        cdef uint32_t value
        if dpiDeqOptions_getNavigation(self._handle, &value) < 0:
            _raise_from_odpi()
        return value

    def get_transformation(self):
        """
        Internal method for getting the transformation.
        """
        cdef:
            uint32_t value_length
            const char *value
        if dpiDeqOptions_getTransformation(self._handle, &value,
                                           &value_length) < 0:
            _raise_from_odpi()
        if value != NULL:
            return value[:value_length].decode()

    def get_visibility(self):
        """
        Internal method for getting the visibility.
        """
        cdef uint32_t value
        if dpiDeqOptions_getVisibility(self._handle, &value) < 0:
            _raise_from_odpi()
        return value

    def get_wait(self):
        """
        Internal method for getting the wait.
        """
        cdef uint32_t value
        if dpiDeqOptions_getWait(self._handle, &value) < 0:
            _raise_from_odpi()
        return value

    def set_condition(self, str value):
        """
        Internal method for setting the condition.
        """
        cdef StringBuffer buf = StringBuffer()
        buf.set_value(value)
        if dpiDeqOptions_setCondition(self._handle, buf.ptr, buf.length) < 0:
            _raise_from_odpi()

    def set_consumer_name(self, str value):
        """
        Internal method for setting the consumer name.
        """
        cdef StringBuffer buf = StringBuffer()
        buf.set_value(value)
        if dpiDeqOptions_setConsumerName(self._handle, buf.ptr,
                                         buf.length) < 0:
            _raise_from_odpi()

    def set_correlation(self, str value):
        """
        Internal method for setting the correlation.
        """
        cdef StringBuffer buf = StringBuffer()
        buf.set_value(value)
        if dpiDeqOptions_setCorrelation(self._handle, buf.ptr, buf.length) < 0:
            _raise_from_odpi()

    def set_delivery_mode(self, uint16_t value):
        """
        Internal method for setting the delivery mode.
        """
        if dpiDeqOptions_setDeliveryMode(self._handle, value) < 0:
            _raise_from_odpi()

    def set_mode(self, uint32_t value):
        """
        Internal method for setting the mode.
        """
        if dpiDeqOptions_setMode(self._handle, value) < 0:
            _raise_from_odpi()

    def set_message_id(self, bytes value):
        """
        Internal method for setting the message id.
        """
        cdef StringBuffer buf = StringBuffer()
        buf.set_value(value)
        if dpiDeqOptions_setMsgId(self._handle, buf.ptr, buf.length) < 0:
            _raise_from_odpi()

    def set_navigation(self, uint32_t value):
        """
        Internal method for setting the navigation.
        """
        if dpiDeqOptions_setNavigation(self._handle, value) < 0:
            _raise_from_odpi()

    def set_transformation(self, str value):
        """
        Internal method for setting the transformation.
        """
        cdef StringBuffer buf = StringBuffer()
        buf.set_value(value)
        if dpiDeqOptions_setTransformation(self._handle, buf.ptr,
                                           buf.length) < 0:
            _raise_from_odpi()

    def set_visibility(self, uint32_t value):
        """
        Internal method for setting the visibility.
        """
        if dpiDeqOptions_setVisibility(self._handle, value) < 0:
            _raise_from_odpi()

    def set_wait(self, uint32_t value):
        """
        Internal method for setting the wait.
        """
        if dpiDeqOptions_setWait(self._handle, value) < 0:
            _raise_from_odpi()


cdef class ThickEnqOptionsImpl(BaseEnqOptionsImpl):
    cdef:
        dpiEnqOptions* _handle

    def __dealloc__(self):
        if self._handle != NULL:
            dpiEnqOptions_release(self._handle)

    def get_transformation(self):
        """
        Internal method for getting the transformation.
        """
        cdef:
            uint32_t value_length
            const char *value
        if dpiEnqOptions_getTransformation(self._handle, &value,
                                           &value_length) < 0:
            _raise_from_odpi()
        if value != NULL:
            return value[:value_length].decode()

    def get_visibility(self):
        """
        Internal method for getting the visibility.
        """
        cdef uint32_t value
        if dpiEnqOptions_getVisibility(self._handle, &value) < 0:
            _raise_from_odpi()
        return value

    def set_delivery_mode(self, uint16_t value):
        """
        Internal method for setting the delivery mode.
        """
        if dpiEnqOptions_setDeliveryMode(self._handle, value) < 0:
            _raise_from_odpi()

    def set_transformation(self, str value):
        """
        Internal method for setting the transformation.
        """
        cdef StringBuffer buf = StringBuffer()
        buf.set_value(value)
        if dpiEnqOptions_setTransformation(self._handle, buf.ptr,
                                           buf.length) < 0:
            _raise_from_odpi()

    def set_visibility(self, uint32_t value):
        """
        Internal method for setting the visibility.
        """
        if dpiEnqOptions_setVisibility(self._handle, value) < 0:
            _raise_from_odpi()


cdef class ThickMsgPropsImpl(BaseMsgPropsImpl):
    cdef:
        dpiMsgProps* _handle

    def __dealloc__(self):
        if self._handle != NULL:
            dpiMsgProps_release(self._handle)

    cdef int _initialize(self, DbObjectType payload_type) except -1:
        cdef:
            dpiObject *payload_obj_handle
            const char *payload_ptr
            DbObject payload_obj
            uint32_t payload_len
        if dpiMsgProps_getPayload(self._handle, &payload_obj_handle,
                                  &payload_ptr, &payload_len) < 0:
            _raise_from_odpi()
        if payload_obj_handle != NULL:
            payload_obj = DbObject.__new__(DbObject)
            payload_obj.type = payload_type
            if dpiObject_addRef(payload_obj_handle) < 0:
                _raise_from_odpi()
            payload_obj._handle = payload_obj_handle
            self.payload = payload_obj
        else:
            self.payload = payload_ptr[:payload_len]

    def get_num_attempts(self):
        """
        Internal method for getting the number of attempts made.
        """
        cdef int32_t value
        if dpiMsgProps_getNumAttempts(self._handle, &value) < 0:
            _raise_from_odpi()
        return value

    def get_correlation(self):
        """
        Internal method for getting the correlation.
        """
        cdef:
            uint32_t value_length
            const char *value
        if dpiMsgProps_getCorrelation(self._handle, &value, &value_length) < 0:
            _raise_from_odpi()
        if value != NULL:
            return value[:value_length].decode()

    def get_delay(self):
        """
        Internal method for getting the delay.
        """
        cdef int32_t value
        if dpiMsgProps_getDelay(self._handle, &value) < 0:
            _raise_from_odpi()
        return value

    def get_delivery_mode(self):
        """
        Internal method for getting the delivery mode.
        """
        cdef uint16_t value
        if dpiMsgProps_getDeliveryMode(self._handle, &value) < 0:
            _raise_from_odpi()
        return value

    def get_enq_time(self):
        """
        Internal method for getting the enqueue time.
        """
        cdef dpiTimestamp timestamp
        if dpiMsgProps_getEnqTime(self._handle, &timestamp) < 0:
            _raise_from_odpi()
        return cydatetime.datetime_new(timestamp.year, timestamp.month,
                                       timestamp.day, timestamp.hour,
                                       timestamp.minute, timestamp.second,
                                       timestamp.fsecond // 1000, None)

    def get_exception_queue(self):
        """
        Internal method for getting the exception queue.
        """
        cdef:
            uint32_t value_length
            const char *value
        if dpiMsgProps_getExceptionQ(self._handle, &value, &value_length) < 0:
            _raise_from_odpi()
        if value != NULL:
            return value[:value_length].decode()

    def get_expiration(self):
        """
        Internal method for getting the message expiration.
        """
        cdef int32_t value
        if dpiMsgProps_getExpiration(self._handle, &value) < 0:
            _raise_from_odpi()
        return value

    def get_message_id(self):
        """
        Internal method for getting the message id.
        """
        cdef:
            uint32_t value_length
            const char *value
        if dpiMsgProps_getOriginalMsgId(self._handle, &value,
                                        &value_length) < 0:
            _raise_from_odpi()
        if value != NULL:
            return value[:value_length]

    def get_priority(self):
        """
        Internal method for getting the priority.
        """
        cdef int32_t value
        if dpiMsgProps_getPriority(self._handle, &value) < 0:
            _raise_from_odpi()
        return value

    def get_state(self):
        """
        Internal method for getting the message state.
        """
        cdef uint32_t value
        if dpiMsgProps_getState(self._handle, &value) < 0:
            _raise_from_odpi()
        return value

    def set_correlation(self, str value):
        """
        Internal method for setting the correlation.
        """
        cdef StringBuffer buf = StringBuffer()
        buf.set_value(value)
        if dpiMsgProps_setCorrelation(self._handle, buf.ptr, buf.length) < 0:
            _raise_from_odpi()

    def set_delay(self, int32_t value):
        """
        Internal method for setting the correlation.
        """
        if dpiMsgProps_setDelay(self._handle, value) < 0:
            _raise_from_odpi()

    def set_exception_queue(self, str value):
        """
        Internal method for setting the exception queue.
        """
        cdef StringBuffer buf = StringBuffer()
        buf.set_value(value)
        if dpiMsgProps_setExceptionQ(self._handle, buf.ptr, buf.length) < 0:
            _raise_from_odpi()

    def set_expiration(self, int32_t value):
        """
        Internal method for setting the message expiration.
        """
        if dpiMsgProps_setExpiration(self._handle, value) < 0:
            _raise_from_odpi()

    def set_message_id(self, bytes value):
        """
        Internal method for setting the original message id.
        """
        cdef StringBuffer buf = StringBuffer()
        buf.set_value(value)
        if dpiMsgProps_setOriginalMsgId(self._handle, buf.ptr, buf.length) < 0:
            _raise_from_odpi()

    def set_payload_bytes(self, bytes value):
        """
        Internal method for setting the payload from bytes.
        """
        cdef StringBuffer buf = StringBuffer()
        buf.set_value(value)
        if dpiMsgProps_setPayloadBytes(self._handle, buf.ptr, buf.length) < 0:
            _raise_from_odpi()

    def set_payload_object(self, DbObject obj):
        """
        Internal method for setting the payload from an object.
        """
        if dpiMsgProps_setPayloadObject(self._handle, obj._handle) < 0:
            _raise_from_odpi()

    def set_priority(self, int32_t value):
        """
        Internal method for setting the priority.
        """
        if dpiMsgProps_setPriority(self._handle, value) < 0:
            _raise_from_odpi()
