#------------------------------------------------------------------------------
# Copyright (c) 2020, 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class BaseQueueImpl:

    def deq_many(self, uint32_t max_num_messages):
        """
        Internal method for dequeuing multiple message from a queue.
        """
        raise NotImplementedError()

    def deq_one(self):
        """
        Internal method for dequeuing a single message from a queue.
        """
        raise NotImplementedError()

    def enq_many(self, list props_impls):
        """
        Internal method for enqueuing many messages into a queue.
        """
        raise NotImplementedError()

    def enq_one(self, BaseMsgPropsImpl props_impl):
        """
        Internal method for enqueuing a single message into a queue.
        """
        raise NotImplementedError()

    def initialize(self, BaseConnImpl conn_impl, str name,
                   BaseDbObjectImpl payload_type):
        """
        Internal method for initializing the queue.
        """
        raise NotImplementedError()


cdef class BaseDeqOptionsImpl:

    def get_condition(self):
        """
        Internal method for getting the condition.
        """
        raise NotImplementedError()

    def get_consumer_name(self):
        """
        Internal method for getting the consumer name.
        """
        raise NotImplementedError()

    def get_correlation(self):
        """
        Internal method for getting the correlation.
        """
        raise NotImplementedError()

    def get_message_id(self):
        """
        Internal method for getting the message id.
        """
        raise NotImplementedError()

    def get_mode(self):
        """
        Internal method for getting the mode.
        """
        raise NotImplementedError()

    def get_navigation(self):
        """
        Internal method for getting the navigation.
        """
        raise NotImplementedError()

    def get_transformation(self):
        """
        Internal method for getting the transformation.
        """
        raise NotImplementedError()

    def get_visibility(self):
        """
        Internal method for getting the visibility.
        """
        raise NotImplementedError()

    def get_wait(self):
        """
        Internal method for getting the wait.
        """
        raise NotImplementedError()

    def set_condition(self, str value):
        """
        Internal method for setting the condition.
        """
        raise NotImplementedError()

    def set_consumer_name(self, str value):
        """
        Internal method for setting the consumer name.
        """
        raise NotImplementedError()

    def set_correlation(self, str value):
        """
        Internal method for setting the correlation.
        """
        raise NotImplementedError()

    def set_delivery_mode(self, uint16_t value):
        """
        Internal method for setting the delivery mode.
        """
        raise NotImplementedError()

    def set_mode(self, uint32_t value):
        """
        Internal method for setting the mode.
        """
        raise NotImplementedError()

    def set_message_id(self, bytes value):
        """
        Internal method for setting the message id.
        """
        raise NotImplementedError()

    def set_navigation(self, uint32_t value):
        """
        Internal method for setting the navigation.
        """
        raise NotImplementedError()

    def set_transformation(self, str value):
        """
        Internal method for setting the transformation.
        """
        raise NotImplementedError()

    def set_visibility(self, uint32_t value):
        """
        Internal method for setting the visibility.
        """
        raise NotImplementedError()

    def set_wait(self, uint32_t value):
        """
        Internal method for setting the wait.
        """
        raise NotImplementedError()


cdef class BaseEnqOptionsImpl:

    def get_transformation(self):
        """
        Internal method for getting the transformation.
        """
        raise NotImplementedError()

    def get_visibility(self):
        """
        Internal method for getting the visibility.
        """
        raise NotImplementedError()

    def set_delivery_mode(self, uint16_t value):
        """
        Internal method for setting the delivery mode.
        """
        raise NotImplementedError()

    def set_transformation(self, str value):
        """
        Internal method for setting the transformation.
        """
        raise NotImplementedError()

    def set_visibility(self, uint32_t value):
        """
        Internal method for setting the visibility.
        """
        raise NotImplementedError()


cdef class BaseMsgPropsImpl:

    def get_num_attempts(self):
        """
        Internal method for getting the number of attempts made.
        """
        raise NotImplementedError()

    def get_correlation(self):
        """
        Internal method for getting the correlation.
        """
        raise NotImplementedError()

    def get_delay(self):
        """
        Internal method for getting the delay.
        """
        raise NotImplementedError()

    def get_delivery_mode(self):
        """
        Internal method for getting the delivery mode.
        """
        raise NotImplementedError()

    def get_enq_time(self):
        """
        Internal method for getting the enqueue time.
        """
        raise NotImplementedError()

    def get_exception_queue(self):
        """
        Internal method for getting the exception queue.
        """
        raise NotImplementedError()

    def get_expiration(self):
        """
        Internal method for getting the message expiration.
        """
        raise NotImplementedError()

    def get_message_id(self):
        """
        Internal method for getting the message id.
        """
        raise NotImplementedError()

    def get_priority(self):
        """
        Internal method for getting the priority.
        """
        raise NotImplementedError()

    def get_state(self):
        """
        Internal method for getting the message state.
        """
        raise NotImplementedError()

    def set_correlation(self, str value):
        """
        Internal method for setting the correlation.
        """
        raise NotImplementedError()

    def set_delay(self, int32_t value):
        """
        Internal method for setting the correlation.
        """
        raise NotImplementedError()

    def set_exception_queue(self, str value):
        """
        Internal method for setting the exception queue.
        """
        raise NotImplementedError()

    def set_expiration(self, int32_t value):
        """
        Internal method for setting the message expiration.
        """
        raise NotImplementedError()

    def set_message_id(self, bytes value):
        """
        Internal method for setting the original message id.
        """
        raise NotImplementedError()

    def set_payload_bytes(self, bytes value):
        """
        Internal method for setting the payload from bytes.
        """
        raise NotImplementedError()

    def set_payload_object(self, BaseDbObjectImpl value):
        """
        Internal method for setting the payload from an object.
        """
        raise NotImplementedError()

    def set_priority(self, int32_t value):
        """
        Internal method for setting the priority.
        """
        raise NotImplementedError()
