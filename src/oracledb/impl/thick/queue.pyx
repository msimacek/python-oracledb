#------------------------------------------------------------------------------
# Copyright (c) 2020, 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class Queue(BaseQueue):
    cdef:
        dpiQueue* _handle

    def __dealloc__(self):
        if self._handle != NULL:
            dpiQueue_release(self._handle)

    cdef object _deq_many(self, uint32_t max_messages):
        cdef:
            uint32_t num_props = max_messages, processed_props = 0, i
            dpiMsgProps** handles
            ssize_t num_bytes
            MsgProps props
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
                props = MsgProps.__new__(MsgProps)
                props._handle = handles[i]
                processed_props += 1
                props._initialize(self)
                result.append(props)
        finally:
            for i in range(processed_props, num_props):
                dpiMsgProps_release(handles[i])
            cpython.PyMem_Free(handles)
        return result

    cdef object _deq_one(self):
        cdef:
            MsgProps props = MsgProps.__new__(MsgProps)
            int status
        with nogil:
            status = dpiQueue_deqOne(self._handle, &props._handle)
        if status < 0:
            _raise_from_odpi()
        if props._handle != NULL:
            props._initialize(self)
            return props

    cdef int _enq_many(self, list messages) except -1:
        cdef:
            uint32_t i, num_props = 0
            dpiMsgProps **handles
            ssize_t num_bytes
            MsgProps props
            int status
        num_props = <uint32_t> len(messages)
        for props in messages:
            props._set_payload()
        num_bytes = num_props * sizeof(dpiMsgProps*)
        handles = <dpiMsgProps**> cpython.PyMem_Malloc(num_bytes)
        for i, props in enumerate(messages):
            handles[i] = props._handle
        with nogil:
            status = dpiQueue_enqMany(self._handle, num_props, handles)
        cpython.PyMem_Free(handles)
        if status < 0:
            _raise_from_odpi()

    cdef int _enq_one(self, BaseMsgProps message) except -1:
        cdef:
            MsgProps props = message
            int status
        props._set_payload()
        with nogil:
            status = dpiQueue_enqOne(self._handle, props._handle)
        if status < 0:
            _raise_from_odpi()

    cdef int _initialize(self) except -1:
        cdef:
            ThickConnImpl thick_connection = self.connection
            DbObjectType thick_objtype = self.payloadType
            dpiObjectType* type_handle = NULL
            StringBuffer buf = StringBuffer()
            DeqOptions deq_options
            EnqOptions enq_options
        buf.set_value(self.name)
        if thick_objtype is not None:
            type_handle = thick_objtype._handle
        if dpiConn_newQueue(thick_connection._handle, buf.ptr, buf.length,
                            type_handle, &self._handle) < 0:
            _raise_from_odpi()
        deq_options = DeqOptions.__new__(DeqOptions)
        if dpiQueue_getDeqOptions(self._handle, &deq_options._handle) < 0:
            _raise_from_odpi()
        self.deqOptions = deq_options
        enq_options = EnqOptions.__new__(EnqOptions)
        if dpiQueue_getEnqOptions(self._handle, &enq_options._handle) < 0:
            _raise_from_odpi()
        self.enqOptions = enq_options


cdef class DeqOptions(BaseDeqOptions):
    cdef:
        dpiDeqOptions* _handle

    def __dealloc__(self):
        if self._handle != NULL:
            dpiDeqOptions_release(self._handle)

    cdef object _get_condition(self):
        cdef:
            uint32_t value_length
            const char *value
        if dpiDeqOptions_getCondition(self._handle, &value, &value_length) < 0:
            _raise_from_odpi()
        if value is not NULL:
            return value[:value_length].decode()

    cdef object _get_consumer_name(self):
        cdef:
            uint32_t value_length
            const char *value
        if dpiDeqOptions_getConsumerName(self._handle, &value,
                                         &value_length) < 0:
            _raise_from_odpi()
        if value is not NULL:
            return value[:value_length].decode()

    cdef object _get_correlation(self):
        cdef:
            uint32_t value_length
            const char *value
        if dpiDeqOptions_getCorrelation(self._handle, &value,
                                        &value_length) < 0:
            _raise_from_odpi()
        if value is not NULL:
            return value[:value_length].decode()

    cdef int _get_mode(self, uint32_t* value) except -1:
        if dpiDeqOptions_getMode(self._handle, value) < 0:
            _raise_from_odpi()

    cdef object _get_message_id(self):
        cdef:
            uint32_t value_length
            const char *value
        if dpiDeqOptions_getMsgId(self._handle, &value, &value_length) < 0:
            _raise_from_odpi()
        if value is not NULL:
            return value[:value_length]

    cdef int _get_navigation(self, uint32_t* value) except -1:
        if dpiDeqOptions_getNavigation(self._handle, value) < 0:
            _raise_from_odpi()

    cdef object _get_transformation(self):
        cdef:
            uint32_t value_length
            const char *value
        if dpiDeqOptions_getTransformation(self._handle, &value,
                                           &value_length) < 0:
            _raise_from_odpi()
        if value is not NULL:
            return value[:value_length].decode()

    cdef int _get_visibility(self, uint32_t* value) except -1:
        if dpiDeqOptions_getVisibility(self._handle, value) < 0:
            _raise_from_odpi()

    cdef int _get_wait(self, uint32_t* value) except -1:
        if dpiDeqOptions_getWait(self._handle, value) < 0:
            _raise_from_odpi()

    cdef int _set_condition(self, str value) except -1:
        cdef StringBuffer buf = StringBuffer()
        buf.set_value(value)
        if dpiDeqOptions_setCondition(self._handle, buf.ptr, buf.length) < 0:
            _raise_from_odpi()

    cdef int _set_consumer_name(self, str value) except -1:
        cdef StringBuffer buf = StringBuffer()
        buf.set_value(value)
        if dpiDeqOptions_setConsumerName(self._handle, buf.ptr,
                                         buf.length) < 0:
            _raise_from_odpi()

    cdef int _set_correlation(self, str value) except -1:
        cdef StringBuffer buf = StringBuffer()
        buf.set_value(value)
        if dpiDeqOptions_setCorrelation(self._handle, buf.ptr, buf.length) < 0:
            _raise_from_odpi()

    cdef int _set_delivery_mode(self, uint16_t value) except -1:
        if dpiDeqOptions_setDeliveryMode(self._handle, value) < 0:
            _raise_from_odpi()

    cdef int _set_mode(self, uint32_t value) except -1:
        if dpiDeqOptions_setMode(self._handle, value) < 0:
            _raise_from_odpi()

    cdef int _set_message_id(self, bytes value) except -1:
        cdef StringBuffer buf = StringBuffer()
        buf.set_value(value)
        if dpiDeqOptions_setMsgId(self._handle, buf.ptr, buf.length) < 0:
            _raise_from_odpi()

    cdef int _set_navigation(self, uint32_t value) except -1:
        if dpiDeqOptions_setNavigation(self._handle, value) < 0:
            _raise_from_odpi()

    cdef int _set_transformation(self, str value) except -1:
        cdef StringBuffer buf = StringBuffer()
        buf.set_value(value)
        if dpiDeqOptions_setTransformation(self._handle, buf.ptr,
                                           buf.length) < 0:
            _raise_from_odpi()

    cdef int _set_visibility(self, uint32_t value) except -1:
        if dpiDeqOptions_setVisibility(self._handle, value) < 0:
            _raise_from_odpi()

    cdef int _set_wait(self, uint32_t value) except -1:
        if dpiDeqOptions_setWait(self._handle, value) < 0:
            _raise_from_odpi()


cdef class EnqOptions(BaseEnqOptions):
    cdef:
        dpiEnqOptions* _handle

    def __dealloc__(self):
        if self._handle != NULL:
            dpiEnqOptions_release(self._handle)

    cdef object _get_transformation(self):
        cdef:
            uint32_t value_length
            const char *value
        if dpiEnqOptions_getTransformation(self._handle, &value,
                                           &value_length) < 0:
            _raise_from_odpi()
        if value is not NULL:
            return value[:value_length].decode()

    cdef int _get_visibility(self, uint32_t* value) except -1:
        if dpiEnqOptions_getVisibility(self._handle, value) < 0:
            _raise_from_odpi()

    cdef int _set_delivery_mode(self, uint16_t value) except -1:
        if dpiEnqOptions_setDeliveryMode(self._handle, value) < 0:
            _raise_from_odpi()

    cdef int _set_transformation(self, str value) except -1:
        cdef StringBuffer buf = StringBuffer()
        buf.set_value(value)
        if dpiEnqOptions_setTransformation(self._handle, buf.ptr,
                                           buf.length) < 0:
            _raise_from_odpi()

    cdef int _set_visibility(self, uint32_t value) except -1:
        if dpiEnqOptions_setVisibility(self._handle, value) < 0:
            _raise_from_odpi()


cdef class MsgProps(BaseMsgProps):
    cdef:
        dpiMsgProps* _handle

    def __dealloc__(self):
        if self._handle != NULL:
            dpiMsgProps_release(self._handle)

    cdef int _get_num_attempts(self, int32_t* value) except -1:
        if dpiMsgProps_getNumAttempts(self._handle, value) < 0:
            _raise_from_odpi()

    cdef object _get_correlation(self):
        cdef:
            uint32_t value_length
            const char *value
        if dpiMsgProps_getCorrelation(self._handle, &value, &value_length) < 0:
            _raise_from_odpi()
        if value is not NULL:
            return value[:value_length].decode()

    cdef int _get_delay(self, int32_t* value) except -1:
        if dpiMsgProps_getDelay(self._handle, value) < 0:
            _raise_from_odpi()

    cdef int _get_delivery_mode(self, uint16_t* value) except -1:
        if dpiMsgProps_getDeliveryMode(self._handle, value) < 0:
            _raise_from_odpi()

    cdef object _get_enq_time(self):
        cdef dpiTimestamp timestamp
        if dpiMsgProps_getEnqTime(self._handle, &timestamp) < 0:
            _raise_from_odpi()
        return cydatetime.datetime_new(timestamp.year, timestamp.month,
                                       timestamp.day, timestamp.hour,
                                       timestamp.minute, timestamp.second,
                                       timestamp.fsecond // 1000, None)

    cdef object _get_exception_queue(self):
        cdef:
            uint32_t value_length
            const char *value
        if dpiMsgProps_getExceptionQ(self._handle, &value, &value_length) < 0:
            _raise_from_odpi()
        if value is not NULL:
            return value[:value_length].decode()

    cdef int _get_expiration(self, int32_t* value) except -1:
        if dpiMsgProps_getExpiration(self._handle, value) < 0:
            _raise_from_odpi()

    cdef object _get_original_message_id(self):
        cdef:
            uint32_t value_length
            const char *value
        if dpiMsgProps_getOriginalMsgId(self._handle, &value,
                                        &value_length) < 0:
            _raise_from_odpi()
        if value is not NULL:
            return value[:value_length]

    cdef int _get_priority(self, int32_t* value) except -1:
        if dpiMsgProps_getPriority(self._handle, value) < 0:
            _raise_from_odpi()

    cdef int _get_message_state(self, uint32_t* value) except -1:
        if dpiMsgProps_getState(self._handle, value) < 0:
            _raise_from_odpi()

    cdef int _initialize(self, Queue queue) except -1:
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
            payload_obj.type = queue.payloadType
            if dpiObject_addRef(payload_obj_handle) < 0:
                _raise_from_odpi()
            payload_obj._handle = payload_obj_handle
            self.payload = payload_obj
        else:
            self.payload = payload_ptr[:payload_len]

    cdef int _set_correlation(self, str value) except -1:
        cdef StringBuffer buf = StringBuffer()
        buf.set_value(value)
        if dpiMsgProps_setCorrelation(self._handle, buf.ptr, buf.length) < 0:
            _raise_from_odpi()

    cdef int _set_delay(self, int32_t value) except -1:
        if dpiMsgProps_setDelay(self._handle, value) < 0:
            _raise_from_odpi()

    cdef int _set_exception_queue(self, str value) except -1:
        cdef StringBuffer buf = StringBuffer()
        buf.set_value(value)
        if dpiMsgProps_setExceptionQ(self._handle, buf.ptr, buf.length) < 0:
            _raise_from_odpi()

    cdef int _set_expiration(self, int32_t value) except -1:
        if dpiMsgProps_setExpiration(self._handle, value) < 0:
            _raise_from_odpi()

    cdef int _set_original_message_id(self, bytes value) except -1:
        cdef StringBuffer buf = StringBuffer()
        buf.set_value(value)
        if dpiMsgProps_setOriginalMsgId(self._handle, buf.ptr, buf.length) < 0:
            _raise_from_odpi()

    cdef int _set_payload(self) except -1:
        cdef:
            StringBuffer buf = StringBuffer()
            DbObject obj
        if isinstance(self.payload, DbObject):
            obj = self.payload
            if dpiMsgProps_setPayloadObject(self._handle, obj._handle) < 0:
                _raise_from_odpi()
        else:
            buf.set_value(self.payload)
            if dpiMsgProps_setPayloadBytes(self._handle, buf.ptr,
                                           buf.length) < 0:
                _raise_from_odpi()

    cdef int _set_priority(self, int32_t value) except -1:
        if dpiMsgProps_setPriority(self._handle, value) < 0:
            _raise_from_odpi()
