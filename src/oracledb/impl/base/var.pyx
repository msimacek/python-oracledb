#------------------------------------------------------------------------------
# Copyright (c) 2020, 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class BaseVarImpl:

    cdef int _bind(self, object conn, BaseCursorImpl cursor,
                   uint32_t num_execs, str name=None,
                   uint32_t pos=0) except -1:
        """
        Binds a variable to the cursor.
        """
        raise NotImplementedError()

    cdef int _resize(self, uint32_t new_size) except -1:
        """
        Resize the variable to the new size provided.
        """
        self.size = new_size
        self.buffer_size = new_size * self.dbtype._buffer_size_factor

    cdef int _set_type(self, object typ) except -1:
        """
        Internal method used to set the database type associated with the
        variable given a Python type.
        """
        cdef ApiType apitype
        if typ is None:
            self.dbtype = DB_TYPE_VARCHAR
            self.size = 1
        elif isinstance(typ, DbType):
            self.dbtype = typ
        elif isinstance(typ, ApiType):
            apitype = typ
            self.dbtype = apitype.dbtypes[0]
        elif isinstance(typ, DbObjectType):
            self.dbtype = DB_TYPE_OBJECT
            self._objtype = typ._impl
        elif not isinstance(typ, type):
            errors._raise_err(errors.ERR_EXPECTING_TYPE)
        elif typ is int:
            self.dbtype = DB_TYPE_NUMBER
            self._preferred_num_type = NUM_TYPE_INT
        elif typ is float:
            self.dbtype = DB_TYPE_NUMBER
            self._preferred_num_type = NUM_TYPE_FLOAT
        elif typ is str:
            self.dbtype = DB_TYPE_VARCHAR
        elif typ is bytes:
            self.dbtype = DB_TYPE_RAW
        elif typ is decimal.Decimal:
            self.dbtype = DB_TYPE_NUMBER
            self._preferred_num_type = NUM_TYPE_DECIMAL
        elif typ is bool:
            self.dbtype = DB_TYPE_BOOLEAN
        elif typ is datetime.date:
            self.dbtype = DB_TYPE_DATE
        elif typ is datetime.datetime:
            self.dbtype = DB_TYPE_TIMESTAMP
        elif typ is datetime.timedelta:
            self.dbtype = DB_TYPE_INTERVAL_DS
        else:
            errors._raise_err(errors.ERR_PYTHON_TYPE_NOT_SUPPORTED, typ=typ)

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
            dbtype = self.dbtype
            if dbtype is DB_TYPE_NUMBER or dbtype is DB_TYPE_BINARY_INTEGER \
                    or dbtype is DB_TYPE_BINARY_DOUBLE \
                    or dbtype is DB_TYPE_BINARY_FLOAT:
                if not isinstance(value, (bool, int, float, decimal.Decimal)):
                    raise TypeError("expecting number or boolean")
                if dbtype is DB_TYPE_BINARY_FLOAT \
                        or dbtype is DB_TYPE_BINARY_DOUBLE:
                    value = float(value)
                elif dbtype is DB_TYPE_BINARY_INTEGER \
                        or isinstance(value, bool):
                    value = int(value)
            elif dbtype is DB_TYPE_VARCHAR or dbtype is DB_TYPE_NVARCHAR \
                    or dbtype is DB_TYPE_CHAR or dbtype is DB_TYPE_NCHAR \
                    or dbtype is DB_TYPE_LONG:
                if isinstance(value, bytes):
                    value = value.decode()
                elif not isinstance(value, str):
                    raise TypeError("expecting string")
                size = <uint32_t> len(value)
                if size > self.size:
                    self._resize(size)
            elif dbtype is DB_TYPE_RAW or dbtype is DB_TYPE_LONG_RAW:
                if isinstance(value, str):
                    value = value.encode()
                elif not isinstance(value, bytes):
                    raise TypeError("expecting bytes")
                size = <uint32_t> len(value)
                if size > self.size:
                    self._resize(size)
            elif dbtype is DB_TYPE_DATE or dbtype is DB_TYPE_TIMESTAMP \
                    or dbtype is DB_TYPE_TIMESTAMP_LTZ \
                    or dbtype is DB_TYPE_TIMESTAMP_TZ:
                if isinstance(value, datetime.datetime):
                    pass
                elif isinstance(value, datetime.date):
                    value = cydatetime.datetime_new(value.year, value.month,
                                                    value.day, 0, 0, 0, 0,
                                                    None)
                else:
                    message = "expecting datetime.date or datetime.datetime"
                    raise TypeError(message)
            elif dbtype is DB_TYPE_INTERVAL_DS:
                if not isinstance(value, datetime.timedelta):
                    raise TypeError("expecting datetime.timedelta")
            elif dbtype is DB_TYPE_BOOLEAN:
                value = bool(value)
            elif dbtype is DB_TYPE_CLOB or dbtype is DB_TYPE_NCLOB \
                    or dbtype is DB_TYPE_BLOB:
                if isinstance(value, LOB):
                    if value.type is not dbtype:
                        message = f"LOB must be of type {dbtype}"
                        raise TypeError(message)
                elif not isinstance(value, (bytes, str)):
                    raise TypeError("expecting LOB, string or bytes")
                else:
                    lob = self.values[pos]
                    if lob is not None and isinstance(lob, LOB):
                        lob.trim()
                        if value:
                            lob.write(value)
                        value = lob
            elif dbtype is DB_TYPE_ROWID:
                errors._raise_err(errors.ERR_SET_ROWID_DIRECTLY)
            elif dbtype is DB_TYPE_OBJECT:
                if not isinstance(value, DbObject):
                    raise TypeError("expecting DbObject")
                if value._impl.type != self._objtype:
                    errors._raise_err(errors.ERR_WRONG_OBJECT_TYPE,
                                      actual_schema=value.type.schema,
                                      actual_name=value.type.name,
                                      expected_schema=self._objtype.schema,
                                      expected_name=self._objtype.name)
            elif dbtype is DB_TYPE_CURSOR:
                if not isinstance(value, Cursor):
                    raise TypeError("expecting cursor")
        self.values[pos] = value

    def get_description(self):
        """
        Return a 7-tuple containing information about the variable: (name,
        type, display_size, internal_size, precision, scale, null_ok).
        """
        cdef:
            uint32_t display_size = 0, size_in_bytes = 0
            object precision, scale
            DbType dbtype = self.dbtype
        if self.size > 0:
            display_size = self.size
            size_in_bytes = self.buffer_size
        elif dbtype is DB_TYPE_DATE \
                or dbtype is DB_TYPE_TIMESTAMP \
                or dbtype is DB_TYPE_TIMESTAMP_LTZ \
                or dbtype is DB_TYPE_TIMESTAMP_TZ:
            display_size = 23
        elif dbtype is DB_TYPE_BINARY_FLOAT \
                or dbtype is DB_TYPE_BINARY_DOUBLE \
                or dbtype is DB_TYPE_BINARY_INTEGER \
                or dbtype is DB_TYPE_NUMBER:
            if self.precision:
                display_size = self.precision + 1
                if self.scale > 0:
                    display_size += self.scale + 1
            else:
                display_size = 127
        if self.precision or self.scale:
            precision = self.precision
            scale = self.scale
        else:
            scale = precision = None
        return (self.name, dbtype, display_size or None, size_in_bytes or None,
                precision, scale, self.nulls_allowed)

    cpdef set_value(self, uint32_t pos, object value):
        """
        Internal method for setting a variable's value at the specified
        position.
        """
        cdef:
            object element_value
            uint32_t i
        if self.is_array:
            if pos > 0:
                errors._raise_err(errors.ERR_ARRAYS_OF_ARRAYS)
            if not isinstance(value, list):
                raise TypeError("expecting list")
            elif len(value) > self.num_elements:
                raise TypeError("list too large for variable")
            for i, element_value in enumerate(value):
                self._set_single_value(i, element_value)
            self.num_elements_in_array = len(value)
        else:
            if pos >= self.num_elements:
                raise IndexError("position out of range")
            self._set_single_value(pos, value)
        self._is_value_set = True
