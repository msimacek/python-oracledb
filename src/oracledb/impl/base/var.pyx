#------------------------------------------------------------------------------
# Copyright (c) 2020, 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class BaseVar:

    def __repr__(self):
        if self.is_array:
            num_elems = self._get_actual_elements()
            value = self._get_array_value(num_elems)
        elif self.num_elements == 1:
            value = self._get_single_value(0)
        else:
            value = self._get_array_value(self.num_elements)
        r = f"<oracledb.Var of type {self._dbtype.name} with value " \
            f"{repr(value)}>"
        return r

    cdef int _bind(self, BaseCursorImpl cursor, uint32_t num_execs,
                   str name=None, uint32_t pos=0) except -1:
        """
        Binds a variable to the cursor.
        """
        raise NotImplementedError()

    cdef int _finalize_init(self) except -1:
        """
        Finalizes initialization.
        """
        if self.num_elements == 0:
            self.num_elements = 1
        self._values = [None] * self.num_elements
        if self.size > 0:
            self.buffer_size = self.size * self._dbtype._buffer_size_factor
        else:
            self.buffer_size = self._dbtype._buffer_size_factor

    cdef uint32_t _get_actual_elements(self):
        """
        Return the number of elements in the variable. This will either be the
        number of elements in a PL/SQL array or the number of elements that
        were originally allocated for the variable.
        """
        if self.is_array:
            return self._num_elements_in_array
        return self.num_elements

    cdef list _get_array_value(self, uint32_t num_elements):
        """
        Return the values stored in the variable as a list.
        """
        return self._values[:num_elements]
    
    cdef object _get_single_value(self, uint32_t pos):
        """
        Return the value stored in the variable at the specified position.
        """
        return self._values[pos]

    cdef int _resize(self, uint32_t new_size) except -1:
        """
        Resize the variable to the new size provided.
        """
        self.size = new_size
        self.buffer_size = new_size * self._dbtype._buffer_size_factor

    cdef int _set_array_value(self, list value) except -1:
        """
        Set the array elements to the value of the list.
        """
        cdef uint32_t i
        for i, element_value in enumerate(value):
            self._set_single_value(i, element_value)
        self._num_elements_in_array = <uint32_t> len(value)

    cdef int _set_dbtype_from_type(self, object typ) except -1:
        """
        Internal method used to set the database type associated with the
        variable given a type.
        """
        cdef ApiType apitype
        if isinstance(typ, DbType):
            self._dbtype = typ
        elif isinstance(typ, ApiType):
            apitype = typ
            self._dbtype = apitype.dbtypes[0]
        elif isinstance(typ, DbObjectType):
            self._dbtype = DB_TYPE_OBJECT
        elif not isinstance(typ, type):
            errors._raise_from_string(TypeError, "expecting type")
        elif typ is int:
            self._dbtype = DB_TYPE_NUMBER
            self._preferred_num_type = NUM_TYPE_INT
        elif typ is float:
            self._dbtype = DB_TYPE_NUMBER
            self._preferred_num_type = NUM_TYPE_FLOAT
        elif typ is str:
            self._dbtype = DB_TYPE_VARCHAR
        elif typ is bytes:
            self._dbtype = DB_TYPE_RAW
        elif typ is decimal.Decimal:
            self._dbtype = DB_TYPE_NUMBER
            self._preferred_num_type = NUM_TYPE_DECIMAL
        elif typ is bool:
            self._dbtype = DB_TYPE_BOOLEAN
        elif typ is datetime.date:
            self._dbtype = DB_TYPE_DATE
        elif typ is datetime.datetime:
            self._dbtype = DB_TYPE_TIMESTAMP
        elif typ is datetime.timedelta:
            self._dbtype = DB_TYPE_INTERVAL_DS
        else:
            errors._raise_from_string(exceptions.NotSupportedError,
                                      f"Python type {typ} not supported")

    cdef int _set_single_value(self, uint32_t pos, object value) except -1:
        """
        Set a single element of the variable to the specified value.
        """
        cdef:
            uint32_t size
            DbType dbtype
            object lob
        if self.inconverter is not None:
            value = self.inconverter(value)
        if value is not None:
            dbtype = self._dbtype
            if dbtype is DB_TYPE_NUMBER or dbtype is DB_TYPE_BINARY_INTEGER:
                if not isinstance(value, (bool, int, float, decimal.Decimal)):
                    raise TypeError("expecting number or boolean")
            elif dbtype is DB_TYPE_VARCHAR or dbtype is DB_TYPE_NVARCHAR \
                    or dbtype is DB_TYPE_CHAR or dbtype is DB_TYPE_NCHAR \
                    or dbtype is DB_TYPE_LONG:
                if not isinstance(value, str):
                    raise TypeError("expecting string")
                size = <uint32_t> len(value)
                if size > self.size:
                    self._resize(size)
            elif dbtype is DB_TYPE_RAW or dbtype is DB_TYPE_LONG_RAW:
                if not isinstance(value, bytes):
                    raise TypeError("expecting bytes")
                size = <uint32_t> len(value)
                if size > self.size:
                    self._resize(size)
            elif dbtype is DB_TYPE_DATE or dbtype is DB_TYPE_TIMESTAMP \
                    or dbtype is DB_TYPE_TIMESTAMP_LTZ \
                    or dbtype is DB_TYPE_TIMESTAMP_TZ:
                if not isinstance(value, (datetime.date, datetime.datetime)):
                    message = "expecting datetime.date or datetime.datetime"
                    raise TypeError(message)
            elif dbtype is DB_TYPE_CLOB or dbtype is DB_TYPE_NCLOB \
                    or dbtype is DB_TYPE_BLOB:
                if isinstance(value, LOB):
                    if value.type is not dbtype:
                        message = f"LOB must be of type {dbtype}"
                        raise TypeError(message)
                else:
                    lob = self._values[pos]
                    if lob is None:
                        lob = self._conn.createlob(dbtype)
                    else:
                        lob.trim()
                    if value:
                        lob.write(value)
                    value = lob
            elif dbtype is DB_TYPE_ROWID:
                msg = "Rowid variables cannot be set directly"
                errors._raise_from_string(exceptions.NotSupportedError, msg)
            elif dbtype is DB_TYPE_OBJECT:
                if not isinstance(value, DbObject):
                    raise TypeError("expecting DbObject")
                if value._impl.type != self._objtype:
                    msg = f"found object of type {value.type.schema}." \
                          f"{value.type.name} when expecting object of type " \
                          f"{self._objtype.schema}.{self._objtype.name}"
                    errors._raise_from_string(exceptions.DatabaseError, msg)
        self._values[pos] = value

    cdef int _set_value(self, uint32_t pos, object value) except -1:
        """
        Internal method for setting the value of a variable which peforms all
        necessary checks.
        """
        if self.is_array:
            if pos > 0:
                errors._raise_from_string(exceptions.NotSupportedError,
                                          "arrays of arrays not supported")
            if not isinstance(value, list):
                raise TypeError("expecting list")
            elif len(value) > self.num_elements:
                raise TypeError("list too large for variable")
            self._set_array_value(value)
        else:
            if pos >= self.num_elements:
                raise IndexError("position out of range")
            self._set_single_value(pos, value)
        self._is_value_set = True

    @property
    def actualElements(self):
        return self._get_actual_elements()

    @property
    def actual_elements(self):
        return self._get_actual_elements()

    @property
    def bufferSize(self):
        return self.buffer_size

    @property
    def description(self):
        size_in_bytes = 0
        if self.size > 0:
            display_size = self.size
            size_in_bytes = self.buffer_size
        elif self._dbtype is DB_TYPE_DATE \
                or self._dbtype is DB_TYPE_TIMESTAMP \
                or self._dbtype is DB_TYPE_TIMESTAMP_LTZ \
                or self._dbtype is DB_TYPE_TIMESTAMP_TZ:
            display_size = 23
        elif self._dbtype is DB_TYPE_BINARY_FLOAT \
                or self._dbtype is DB_TYPE_BINARY_DOUBLE \
                or self._dbtype is DB_TYPE_BINARY_INTEGER \
                or self._dbtype is DB_TYPE_NUMBER:
            if self.precision:
                display_size = self.precision + 1
                if self.scale > 0:
                    display_size += self.scale + 1
            else:
                display_size = 127
        else:
            display_size = 0
        if self.precision or self.scale:
            precision = self.precision
            scale = self.scale
        else:
            scale = precision = None
        return (self.name, self._dbtype, display_size or None,
                size_in_bytes or None, precision, scale, self.nulls_allowed)

    def getvalue(self, pos=0):
        """
        Return the value at the given position in the variable.
        """
        if self.is_array:
            num_elems = self._get_actual_elements()
            return self._get_array_value(num_elems)
        if pos >= self.num_elements:
            raise IndexError("position out of range")
        return self._get_single_value(pos)

    @property
    def numElements(self):
        return self.num_elements

    def setvalue(self, pos=0, value=None):
        """
        Set the value at the specified position in the variable.
        """
        self._set_value(pos, value)

    @property
    def type(self):
        return self._objtype or self._dbtype

    @property
    def values(self):
        num_elems = self._get_actual_elements()
        return self._get_array_value(num_elems)
