#------------------------------------------------------------------------------
# Copyright (c) 2020, 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class BaseDbObjectImpl:

    @utils.CheckImpls("appending a value to a collection")
    def append(self, object value):
        pass

    @utils.CheckImpls("creating a copy of an object")
    def copy(self):
        pass

    @utils.CheckImpls("deleting an element in a collection")
    def delete_by_index(self, int32_t index):
        pass

    @utils.CheckImpls("determining if an entry exists in a collection")
    def exists_by_index(self, int32_t index):
        pass

    @utils.CheckImpls("getting an attribute value")
    def get_attr_value(self, BaseDbObjectAttrImpl attr):
        pass

    @utils.CheckImpls("getting an element of a collection")
    def get_element_by_index(self, int32_t index):
        pass

    @utils.CheckImpls("getting the first index of a collection")
    def get_first_index(self):
        pass

    @utils.CheckImpls("getting the last index of a collection")
    def get_last_index(self):
        pass

    @utils.CheckImpls("getting the next index of a collection")
    def get_next_index(self, int32_t index):
        pass

    @utils.CheckImpls("getting the previous index of a collection")
    def get_prev_index(self, int32_t index):
        pass

    @utils.CheckImpls("getting the size of a collection")
    def get_size(self):
        pass

    @utils.CheckImpls("setting an attribute value")
    def set_attr_value(self, BaseDbObjectAttrImpl attr, object value):
        pass

    @utils.CheckImpls("setting an element of a collection")
    def set_element_by_index(self, int32_t index, object value):
        pass

    @utils.CheckImpls("trimming elements from a collection")
    def trim(self, int32_t num_to_trim):
        pass


cdef class BaseDbObjectAttrImpl:
    pass


cdef class BaseDbObjectTypeImpl:

    def __eq__(self, other):
        if isinstance(other, BaseDbObjectTypeImpl):
            return other._conn_impl is self._conn_impl \
                    and other.schema == self.schema \
                    and other.name == self.name
        return NotImplemented

    @utils.CheckImpls("creating a new object")
    def create_new_object(self):
        pass
