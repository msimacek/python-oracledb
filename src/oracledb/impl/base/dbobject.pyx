#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class BaseDbObjectType:

    def __call__(self, value=None):
        return self.newobject(value)

    def __eq__(self, other):
        cdef other_type
        if isinstance(other, BaseDbObjectType):
            other_type = <BaseDbObjectType> other
            if other_type._connection is other_type._connection \
                    and other_type.schema == other_type.schema \
                    and other_type.name == other_type.name:
                return True
        return NotImplemented

    def __repr__(self):
        return f"<oracledb.ObjectType {self.schema}.{self.name}>"

    cdef BaseDbObject _new_object(self):
        """
        Internal method for creating a new object.
        """
        raise NotImplementedError()

    @property
    def element_type(self):
        return self._element_objtype or self._element_dbtype

    def newobject(self, value=None):
        cdef BaseDbObject obj = self._new_object()
        if value is not None:
            obj.extend(value)
        return obj


cdef class BaseDbObjectAttr:

    def __repr__(self):
        return f"<oracledb.ObjectAttribute {self.name}>"

    @property
    def type(self):
        return self._objtype or self._dbtype


cdef class BaseDbObject:

    def __getattr__(self, name):
        cdef BaseDbObjectAttr attr
        attr = self.type._attributesByName[name]
        return self._get_attr_value(attr)

    def __repr__(self):
        return f"<oracledb.Object {self.type.schema}.{self.type.name} at " \
               f"{hex(id(self))}>"

    def __setattr__(self, name, value):
        cdef BaseDbObjectAttr attr
        attr = self.type._attributesByName[name]
        self._set_attr_value(attr, value)

    cdef int _append(self, object value) except -1:
        """
        Internal method for appending a value to a collection object.
        """
        raise NotImplementedError()

    cdef object _copy(self):
        """
        Internal method for creating a copy of an object.
        """
        raise NotImplementedError()

    cdef int _delete_by_index(self, int32_t index) except -1:
        """
        Internal method for deleting an entry from a collection that is indexed
        by integers.
        """
        raise NotImplementedError()

    cdef int _exists_by_index(self, int32_t index, bint *exists) except -1:
        """
        Internal method for determining if an entry exists in a collection that
        is indexed by integers.
        """
        raise NotImplementedError()

    cdef object _get_attr_value(self, BaseDbObjectAttr attr):
        """
        Internal method for getting an attribute value.
        """
        raise NotImplementedError()

    cdef object _get_element_by_index(self, int32_t index):
        """
        Internal method for getting an entry from a collection that is indexed
        by integers.
        """
        raise NotImplementedError()

    cdef int _get_first_index(self, int32_t* index, bint* exists) except -1:
        """
        Internal method for getting the first index from a collection that is
        indexed by integers.
        """
        raise NotImplementedError()

    cdef int _get_last_index(self, int32_t* index, bint* exists) except -1:
        """
        Internal method for getting the last index from a collection that is
        indexed by integers.
        """
        raise NotImplementedError()

    cdef int _get_next_index(self, int32_t index, int32_t* next_index,
                             bint* exists) except -1:
        """
        Internal method for getting the next index from a collection that is
        indexed by integers.
        """
        raise NotImplementedError()

    cdef int _get_prev_index(self, int32_t index, int32_t* prev_index,
                             bint* exists) except -1:
        """
        Internal method for getting the next index from a collection that is
        indexed by integers.
        """
        raise NotImplementedError()

    cdef int _get_size(self, int32_t *size) except -1:
        """
        Internal method for getting the size of a collection.
        """
        raise NotImplementedError()

    cdef int _set_attr_value(self, BaseDbObjectAttr attr,
                             object value) except -1:
        """
        Internal method for setting an attribute value.
        """
        raise NotImplementedError()

    cdef int _set_element_by_index(self, int32_t index,
                                   object value) except -1:
        """
        Internal method for setting an entry in a collection that is indexed by
        integers.
        """
        raise NotImplementedError()

    cdef int _trim(self, int32_t num_to_trim) except -1:
        """
        Internal method for trimming a number of entries from a collection.
        """
        raise NotImplementedError()

    def append(self, value):
        """
        Append a value to the collection.
        """
        self._append(value)

    def asdict(self):
        """
        Return the collection as a dictionary.
        """
        cdef:
            int32_t index, next_index
            bint exists
        result = {}
        self._get_first_index(&index, &exists)
        while exists:
            result[index] = self._get_element_by_index(index)
            self._get_next_index(index, &next_index, &exists)
            index = next_index
        return result

    def aslist(self):
        """
        Return the elements in the collection as a list, ordered by index.
        """
        cdef:
            int32_t index, next_index
            bint exists
        result = []
        self._get_first_index(&index, &exists)
        while exists:
            result.append(self._get_element_by_index(index))
            self._get_next_index(index, &next_index, &exists)
            index = next_index
        return result

    def copy(self):
        """
        Return a copy of the object which can be manipulated independently of
        the original object.
        """
        return self._copy()

    def delete(self, index):
        """
        Delete an entry from a collection given its index.
        """
        self._delete_by_index(index)

    def exists(self, index):
        """
        Return a boolean indicating if an entry exists in the collection with
        the given index.
        """
        cdef bint exists
        self._exists_by_index(index, &exists)
        return exists

    def extend(self, values):
        """
        Extends a collection by appending each of the values in the given
        sequence.
        """
        for value in values:
            self._append(value)

    def first(self):
        """
        Return the index of the first element in the collection.
        """
        cdef:
            int32_t index
            bint exists
        self._get_first_index(&index, &exists)
        if exists:
            return index

    def getelement(self, index):
        """
        Return the value stored at the given index in the collection if such an
        element exists; otherwise, None is returned.
        """
        return self._get_element_by_index(index)

    def last(self):
        """
        Return the index of the last element in the collection.
        """
        cdef:
            int32_t index
            bint exists
        self._get_last_index(&index, &exists)
        if exists:
            return index

    def next(self, index):
        """
        Return the index of the next element in the collection given another
        index.
        """
        cdef:
            int32_t next_index
            bint exists
        self._get_next_index(index, &next_index, &exists)
        if exists:
            return next_index

    def prev(self, index):
        """
        Return the index of the previous element in the collection given
        another index.
        """
        cdef:
            int32_t prev_index
            bint exists
        self._get_prev_index(index, &prev_index, &exists)
        if exists:
            return prev_index

    def setelement(self, index, value):
        """
        Sets the value of the entry at the given index in the collection.
        """
        self._set_element_by_index(index, value)

    def size(self):
        """
        Returns the number of elements in the collection
        """
        cdef int32_t size
        self._get_size(&size)
        return size

    def trim(self, num_to_trim):
        """
        Trims the specified number of elements from the end of the collection.
        """
        self._trim(num_to_trim)
