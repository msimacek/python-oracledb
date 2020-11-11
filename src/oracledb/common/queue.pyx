#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class BaseQueue:

    cdef object _deq_many(self, uint32_t max_messages):
        """
        Internal method for dequeuing multiple message from a queue.
        """
        raise NotImplementedError()

    cdef object _deq_one(self):
        """
        Internal method for dequeuing a single message from a queue.
        """
        raise NotImplementedError()

    cdef int _enq_many(self, list messages) except -1:
        """
        Internal method for enqueuing many messages into a queue.
        """
        raise NotImplementedError()

    cdef int _enq_one(self, BaseMsgProps message) except -1:
        """
        Internal method for enqueuing a single message into a queue.
        """
        raise NotImplementedError()

    cdef int _initialize(self) except -1:
        """
        Internal method for initializing the queue.
        """
        raise NotImplementedError()

    def deqMany(self, max_messages):
        """
        Dequeue up to the specified number of message from the queue and return
        them in a list.
        """
        return self._deq_many(max_messages)

    def deqOne(self):
        """
        Dequeue a single message from the queue and return it.
        """
        return self._deq_one()

    def enqMany(self, messages):
        """
        Enqueue multiple messages into the queue.
        """
        cdef BaseMsgProps props
        for props in messages:
            if props.payload is None:
                errors._raise_from_string(exceptions.ProgrammingError,
                                          "message has no payload")
        self._enq_many(messages)

    def enqOne(self, message):
        """
        Enqueue a single message into the queue
        """
        self._enq_one(message)


cdef class BaseDeqOptions:

    cdef object _get_condition(self):
        """
        Internal method for getting the condition.
        """
        raise NotImplementedError()

    cdef object _get_consumer_name(self):
        """
        Internal method for getting the consumer name.
        """
        raise NotImplementedError()

    cdef object _get_correlation(self):
        """
        Internal method for getting the correlation.
        """
        raise NotImplementedError()

    cdef int _get_mode(self, uint32_t* value) except -1:
        """
        Internal method for getting the mode.
        """
        raise NotImplementedError()

    cdef object _get_message_id(self):
        """
        Internal method for getting the message id.
        """
        raise NotImplementedError()

    cdef int _get_navigation(self, uint32_t* value) except -1:
        """
        Internal method for getting the navigation.
        """
        raise NotImplementedError()

    cdef object _get_transformation(self):
        """
        Internal method for getting the transformation.
        """
        raise NotImplementedError()

    cdef int _get_visibility(self, uint32_t* value) except -1:
        """
        Internal method for getting the visibility.
        """
        raise NotImplementedError()

    cdef int _get_wait(self, uint32_t* value) except -1:
        """
        Internal method for getting the wait.
        """
        raise NotImplementedError()

    cdef int _set_condition(self, str value) except -1:
        """
        Internal method for setting the condition.
        """
        raise NotImplementedError()

    cdef int _set_consumer_name(self, str value) except -1:
        """
        Internal method for setting the consumer name.
        """
        raise NotImplementedError()

    cdef int _set_correlation(self, str value) except -1:
        """
        Internal method for setting the correlation.
        """
        raise NotImplementedError()

    cdef int _set_delivery_mode(self, uint16_t value) except -1:
        """
        Internal method for setting the delivery mode.
        """
        raise NotImplementedError()

    cdef int _set_mode(self, uint32_t value) except -1:
        """
        Internal method for setting the mode.
        """
        raise NotImplementedError()

    cdef int _set_message_id(self, bytes value) except -1:
        """
        Internal method for setting the message id.
        """
        raise NotImplementedError()

    cdef int _set_navigation(self, uint32_t value) except -1:
        """
        Internal method for setting the navigation.
        """
        raise NotImplementedError()

    cdef int _set_transformation(self, str value) except -1:
        """
        Internal method for setting the transformation.
        """
        raise NotImplementedError()

    cdef int _set_visibility(self, uint32_t value) except -1:
        """
        Internal method for setting the visibility.
        """
        raise NotImplementedError()

    cdef int _set_wait(self, uint32_t value) except -1:
        """
        Internal method for setting the wait.
        """
        raise NotImplementedError()

    @property
    def condition(self):
        return self._get_condition()

    @condition.setter
    def condition(self, value):
        self._set_condition(value)

    @property
    def consumername(self):
        return self._get_consumer_name()

    @consumername.setter
    def consumername(self, value):
        self._set_consumer_name(value)

    @property
    def correlation(self):
        return self._get_correlation()

    @correlation.setter
    def correlation(self, value):
        self._set_correlation(value)

    @property
    def deliverymode(self):
        raise AttributeError("deliverymode is not readable")

    @deliverymode.setter
    def deliverymode(self, value):
        self._set_delivery_mode(value)

    @property
    def mode(self):
        cdef uint32_t value
        self._get_mode(&value)
        return value

    @mode.setter
    def mode(self, value):
        self._set_mode(value)

    @property
    def msgid(self):
        return self._get_message_id()

    @msgid.setter
    def msgid(self, value):
        self._set_message_id(value)

    @property
    def navigation(self):
        cdef uint32_t value
        self._get_navigation(&value)
        return value

    @navigation.setter
    def navigation(self, value):
        self._set_navigation(value)

    @property
    def transformation(self):
        return self._get_transformation()

    @transformation.setter
    def transformation(self, value):
        self._set_transformation(value)

    @property
    def visibility(self):
        cdef uint32_t value
        self._get_visibility(&value)
        return value

    @visibility.setter
    def visibility(self, value):
        self._set_visibility(value)

    @property
    def wait(self):
        cdef uint32_t value
        self._get_wait(&value)
        return value

    @wait.setter
    def wait(self, value):
        self._set_wait(value)


cdef class BaseEnqOptions:

    cdef object _get_transformation(self):
        """
        Internal method for getting the transformation.
        """
        raise NotImplementedError()

    cdef int _get_visibility(self, uint32_t* value) except -1:
        """
        Internal method for getting the visibility.
        """
        raise NotImplementedError()

    cdef int _set_delivery_mode(self, uint16_t value) except -1:
        """
        Internal method for setting the delivery mode.
        """
        raise NotImplementedError()

    cdef int _set_transformation(self, str value) except -1:
        """
        Internal method for setting the transformation.
        """
        raise NotImplementedError()

    cdef int _set_visibility(self, uint32_t value) except -1:
        """
        Internal method for setting the visibility.
        """
        raise NotImplementedError()

    @property
    def deliverymode(self):
        raise AttributeError("deliverymode is not readable")

    @deliverymode.setter
    def deliverymode(self, value):
        self._set_delivery_mode(value)

    @property
    def transformation(self):
        return self._get_transformation()

    @transformation.setter
    def transformation(self, value):
        self._set_transformation(value)

    @property
    def visibility(self):
        cdef uint32_t value
        self._get_visibility(&value)
        return value

    @visibility.setter
    def visibility(self, value):
        self._set_visibility(value)


cdef class BaseMsgProps:

    cdef int _get_num_attempts(self, int32_t* value) except -1:
        """
        Internal method for getting the number of attempts made.
        """
        raise NotImplementedError()

    cdef object _get_correlation(self):
        """
        Internal method for getting the correlation.
        """
        raise NotImplementedError()

    cdef int _get_delay(self, int32_t* value) except -1:
        """
        Internal method for getting the delay.
        """
        raise NotImplementedError()

    cdef int _get_delivery_mode(self, uint16_t* value) except -1:
        """
        Internal method for getting the delivery mode.
        """
        raise NotImplementedError()

    cdef object _get_enq_time(self):
        """
        Internal method for getting the enqueue time.
        """
        raise NotImplementedError()

    cdef object _get_exception_queue(self):
        """
        Internal method for getting the exception queue.
        """
        raise NotImplementedError()

    cdef int _get_expiration(self, int32_t* value) except -1:
        """
        Internal method for getting the message expiration.
        """
        raise NotImplementedError()

    cdef object _get_original_message_id(self):
        """
        Internal method for getting the original message id.
        """
        raise NotImplementedError()

    cdef int _get_priority(self, int32_t* value) except -1:
        """
        Internal method for getting the priority.
        """
        raise NotImplementedError()

    cdef int _get_message_state(self, uint32_t* value) except -1:
        """
        Internal method for getting the message state.
        """
        raise NotImplementedError()

    cdef int _set_correlation(self, str value) except -1:
        """
        Internal method for setting the correlation.
        """
        raise NotImplementedError()

    cdef int _set_delay(self, int32_t value) except -1:
        """
        Internal method for setting the correlation.
        """
        raise NotImplementedError()

    cdef int _set_exception_queue(self, str value) except -1:
        """
        Internal method for setting the exception queue.
        """
        raise NotImplementedError()

    cdef int _set_expiration(self, int32_t value) except -1:
        """
        Internal method for setting the message expiration.
        """
        raise NotImplementedError()

    cdef int _set_original_message_id(self, bytes value) except -1:
        """
        Internal method for setting the original message id.
        """
        raise NotImplementedError()

    cdef int _set_priority(self, int32_t value) except -1:
        """
        Internal method for setting the priority.
        """
        raise NotImplementedError()

    @property
    def attempts(self):
        cdef int32_t value
        self._get_num_attempts(&value)
        return value

    @property
    def correlation(self):
        return self._get_correlation()

    @correlation.setter
    def correlation(self, value):
        self._set_correlation(value)

    @property
    def delay(self):
        cdef int32_t value
        self._get_delay(&value)
        return value

    @delay.setter
    def delay(self, value):
        self._set_delay(value)

    @property
    def deliverymode(self):
        cdef uint16_t value
        self._get_delivery_mode(&value)
        return value

    @deliverymode.setter
    def deliverymode(self, value):
        self._set_delivery_mode(value)

    @property
    def enqtime(self):
        return self._get_enq_time()

    @property
    def exceptionq(self):
        return self._get_exception_queue()

    @exceptionq.setter
    def exceptionq(self, value):
        self._set_exception_queue(value)

    @property
    def expiration(self):
        cdef int32_t value
        self._get_expiration(&value)
        return value

    @expiration.setter
    def expiration(self, value):
        self._set_expiration(value)

    @property
    def msgid(self):
        return self._get_original_message_id()

    @msgid.setter
    def msgid(self, value):
        self._set_original_message_id(value)

    @property
    def priority(self):
        cdef int32_t value
        self._get_priority(&value)
        return value

    @priority.setter
    def priority(self, value):
        self._set_priority(value)

    @property
    def state(self):
        cdef uint32_t value
        self._get_message_state(&value)
        return value
