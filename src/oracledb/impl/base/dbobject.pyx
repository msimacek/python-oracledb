#------------------------------------------------------------------------------
# Copyright (c) 2020, 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class BaseDbObjectImpl:

    def append(self, object value):
        """
        Internal method for appending a value to a collection object.
        """
        raise NotImplementedError()

    def copy(self):
        """
        Internal method for creating a copy of an object.
        """
        raise NotImplementedError()

    def delete_by_index(self, int32_t index):
        """
        Internal method for deleting an entry from a collection that is indexed
        by integers.
        """
        raise NotImplementedError()

    def exists_by_index(self, int32_t index):
        """
        Internal method for determining if an entry exists in a collection that
        is indexed by integers.
        """
        raise NotImplementedError()

    def get_attr_value(self, BaseDbObjectAttrImpl attr):
        """
        Internal method for getting an attribute value.
        """
        raise NotImplementedError()

    def get_element_by_index(self, int32_t index):
        """
        Internal method for getting an entry from a collection that is indexed
        by integers.
        """
        raise NotImplementedError()

    def get_first_index(self):
        """
        Internal method for getting the first index from a collection that is
        indexed by integers.
        """
        raise NotImplementedError()

    def get_last_index(self):
        """
        Internal method for getting the last index from a collection that is
        indexed by integers.
        """
        raise NotImplementedError()

    def get_next_index(self, int32_t index):
        """
        Internal method for getting the next index from a collection that is
        indexed by integers.
        """
        raise NotImplementedError()

    def get_prev_index(self, int32_t index):
        """
        Internal method for getting the next index from a collection that is
        indexed by integers.
        """
        raise NotImplementedError()

    def get_size(self):
        """
        Internal method for getting the size of a collection.
        """
        raise NotImplementedError()

    def set_attr_value(self, BaseDbObjectAttrImpl attr, object value):
        """
        Internal method for setting an attribute value.
        """
        raise NotImplementedError()

    def set_element_by_index(self, int32_t index, object value):
        """
        Internal method for setting an entry in a collection that is indexed by
        integers.
        """
        raise NotImplementedError()

    def trim(self, int32_t num_to_trim):
        """
        Internal method for trimming a number of entries from a collection.
        """
        raise NotImplementedError()


cdef class BaseDbObjectAttrImpl:
    pass


cdef class BaseDbObjectTypeImpl:

    def __eq__(self, other):
        if isinstance(other, BaseDbObjectTypeImpl):
            return other._conn is self._conn \
                    and other.schema == self.schema \
                    and other.name == self.name
        return NotImplemented

    def create_new_object(self):
        """
        Internal method for creating a new object.
        """
        raise NotImplementedError()
