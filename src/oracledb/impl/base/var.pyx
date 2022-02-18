#------------------------------------------------------------------------------
# Copyright (c) 2020, 2022, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class BaseVarImpl:

    cdef int _bind(self, object conn, BaseCursorImpl cursor,
                   uint32_t num_execs, object name, uint32_t pos) except -1:
        """
        Binds a variable to the cursor.
        """
        raise NotImplementedError()

    cdef int _finalize_init(self) except -1:
        """
        Internal method that finalizes initialization of the variable.
        """
        if self.dbtype.default_size > 0:
            if self.size == 0:
                self.size = self.dbtype.default_size
            self.buffer_size = self.size * self.dbtype._buffer_size_factor
        else:
            self.buffer_size = self.dbtype._buffer_size_factor
        if self.num_elements == 0:
            self.num_elements = 1
        self.values = [None] * self.num_elements

    cdef int _resize(self, uint32_t new_size) except -1:
        """
        Resize the variable to the new size provided.
        """
        self.size = new_size
        self.buffer_size = new_size * self.dbtype._buffer_size_factor

    cdef int _set_single_value(self, uint32_t pos, object value) except -1:
        """
        Set a single element of the variable to the specified value.
        """
        cdef:
            uint32_t db_type_num, size
            object lob
        if self.inconverter is not None:
            value = self.inconverter(value)
        if value is not None:
            db_type_num = self.dbtype.num
            if db_type_num in (DB_TYPE_NUM_NUMBER, DB_TYPE_NUM_BINARY_INTEGER,
                               DB_TYPE_NUM_BINARY_DOUBLE,
                               DB_TYPE_NUM_BINARY_FLOAT):
                if not isinstance(value,
                                  (PY_TYPE_BOOL, int, float, PY_TYPE_DECIMAL)):
                    raise TypeError("expecting number or boolean")
                if db_type_num in (DB_TYPE_NUM_BINARY_FLOAT,
                                   DB_TYPE_NUM_BINARY_DOUBLE):
                    value = float(value)
                elif db_type_num == DB_TYPE_NUM_BINARY_INTEGER \
                        or isinstance(value, PY_TYPE_BOOL):
                    value = int(value)
            elif db_type_num in (DB_TYPE_NUM_CHAR, DB_TYPE_NUM_VARCHAR,
                                 DB_TYPE_NUM_NCHAR, DB_TYPE_NUM_NVARCHAR,
                                 DB_TYPE_NUM_LONG_VARCHAR,
                                 DB_TYPE_NUM_LONG_NVARCHAR):
                if isinstance(value, bytes):
                    value = (<bytes> value).decode()
                elif not isinstance(value, str):
                    raise TypeError("expecting string")
                size = <uint32_t> len(<str> value)
                if size > self.size:
                    self._resize(size)
            elif db_type_num in (DB_TYPE_NUM_RAW, DB_TYPE_NUM_LONG_RAW):
                if isinstance(value, str):
                    value = (<str> value).encode()
                elif not isinstance(value, bytes):
                    raise TypeError("expecting bytes")
                size = <uint32_t> len(<bytes> value)
                if size > self.size:
                    self._resize(size)
            elif db_type_num in (DB_TYPE_NUM_DATE, DB_TYPE_NUM_TIMESTAMP,
                                 DB_TYPE_NUM_TIMESTAMP_LTZ,
                                 DB_TYPE_NUM_TIMESTAMP_TZ):
                if isinstance(value, PY_TYPE_DATETIME):
                    pass
                elif isinstance(value, PY_TYPE_DATE):
                    value = cydatetime.datetime_new(value.year, value.month,
                                                    value.day, 0, 0, 0, 0,
                                                    None)
                else:
                    message = "expecting datetime.date or datetime.datetime"
                    raise TypeError(message)
            elif db_type_num == DB_TYPE_NUM_INTERVAL_DS:
                if not isinstance(value, PY_TYPE_TIMEDELTA):
                    raise TypeError("expecting datetime.timedelta")
            elif db_type_num == DB_TYPE_NUM_BOOLEAN:
                value = bool(value)
            elif db_type_num in (DB_TYPE_NUM_CLOB, DB_TYPE_NUM_NCLOB,
                                 DB_TYPE_NUM_BLOB):
                if isinstance(value, PY_TYPE_LOB):
                    if value.type is not self.dbtype:
                        message = f"LOB must be of type {self.dbtype}"
                        raise TypeError(message)
                elif not isinstance(value, (bytes, str)):
                    raise TypeError("expecting LOB, string or bytes")
                else:
                    lob = self.values[pos]
                    if lob is not None and isinstance(lob, PY_TYPE_LOB):
                        lob.trim()
                        if value:
                            lob.write(value)
                        value = lob
            elif db_type_num in (DB_TYPE_NUM_ROWID, DB_TYPE_NUM_UROWID):
                errors._raise_err(errors.ERR_SET_ROWID_DIRECTLY)
            elif db_type_num == DB_TYPE_NUM_OBJECT:
                if not isinstance(value, PY_TYPE_DB_OBJECT):
                    raise TypeError("expecting DbObject")
                if value._impl.type != self.objtype:
                    errors._raise_err(errors.ERR_WRONG_OBJECT_TYPE,
                                      actual_schema=value.type.schema,
                                      actual_name=value.type.name,
                                      expected_schema=self.objtype.schema,
                                      expected_name=self.objtype.name)
            elif db_type_num == DB_TYPE_NUM_CURSOR:
                if not isinstance(value, PY_TYPE_CURSOR):
                    raise TypeError("expecting cursor")
        self.values[pos] = value

    cdef int _set_type_info_from_type(self, object typ) except -1:
        """
        Sets the type and size of the variable given a Python type.
        """
        cdef ApiType apitype
        if isinstance(typ, DbType):
            self.dbtype = typ
        elif isinstance(typ, ApiType):
            apitype = typ
            self.dbtype = apitype.dbtypes[0]
        elif isinstance(typ, PY_TYPE_DB_OBJECT_TYPE):
            self.dbtype = DB_TYPE_OBJECT
            self.objtype = typ._impl
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
        elif typ is PY_TYPE_DECIMAL:
            self.dbtype = DB_TYPE_NUMBER
            self._preferred_num_type = NUM_TYPE_DECIMAL
        elif typ is PY_TYPE_BOOL:
            self.dbtype = DB_TYPE_BOOLEAN
        elif typ is PY_TYPE_DATE:
            self.dbtype = DB_TYPE_DATE
        elif typ is PY_TYPE_DATETIME:
            self.dbtype = DB_TYPE_TIMESTAMP
        elif typ is PY_TYPE_TIMEDELTA:
            self.dbtype = DB_TYPE_INTERVAL_DS
        else:
            errors._raise_err(errors.ERR_PYTHON_TYPE_NOT_SUPPORTED, typ=typ)

    cdef int _set_type_info_from_value(self, object value,
                                       bint is_plsql) except -1:
        """
        Sets the type and size of the variable given a Python value. This
        method is called once for scalars and once per element in a list for
        array values. If a different type is detected an error is raised.
        """
        cdef:
            BaseDbObjectTypeImpl objtype = None
            DbType dbtype = None
            uint32_t size = 0
        if value is None:
            dbtype = DB_TYPE_VARCHAR
            size = 1
        elif isinstance(value, PY_TYPE_BOOL):
            dbtype = DB_TYPE_BOOLEAN if is_plsql else DB_TYPE_BINARY_INTEGER
        elif isinstance(value, str):
            size = <uint32_t> len(value)
            dbtype = DB_TYPE_VARCHAR
        elif isinstance(value, bytes):
            size = <uint32_t> len(value)
            dbtype = DB_TYPE_RAW
        elif isinstance(value, (int, float, PY_TYPE_DECIMAL)):
            dbtype = DB_TYPE_NUMBER
        elif isinstance(value, (datetime.date, datetime.datetime)):
            dbtype = DB_TYPE_DATE
        elif isinstance(value, datetime.timedelta):
            dbtype = DB_TYPE_INTERVAL_DS
        elif isinstance(value, PY_TYPE_DB_OBJECT):
            dbtype = DB_TYPE_OBJECT
            objtype = value.type._impl
        elif isinstance(value, LOB):
            dbtype = value.type
        elif isinstance(value, Cursor):
            dbtype = DB_TYPE_CURSOR
        else:
            errors._raise_err(errors.ERR_PYTHON_VALUE_NOT_SUPPORTED,
                              type_name=type(value).__name__)
        if self.dbtype is None:
            self.dbtype = dbtype
            self.objtype = objtype
        elif dbtype is not self.dbtype or objtype is not self.objtype:
            errors._raise_err(errors.ERR_MIXED_ELEMENT_TYPES, element=value)
        if size > self.size:
            self.size = size

    def get_description(self):
        """
        Return a 7-tuple containing information about the variable: (name,
        type, display_size, internal_size, precision, scale, null_ok).
        """
        cdef:
            uint32_t display_size = 0, size_in_bytes = 0
            FetchInfo fetch_info = self._fetch_info
            DbType dbtype = fetch_info._dbtype
            object precision, scale
        if fetch_info._size > 0:
            display_size = fetch_info._size
            size_in_bytes = fetch_info._buffer_size
        elif dbtype is DB_TYPE_DATE \
                or dbtype is DB_TYPE_TIMESTAMP \
                or dbtype is DB_TYPE_TIMESTAMP_LTZ \
                or dbtype is DB_TYPE_TIMESTAMP_TZ:
            display_size = 23
        elif dbtype is DB_TYPE_BINARY_FLOAT \
                or dbtype is DB_TYPE_BINARY_DOUBLE \
                or dbtype is DB_TYPE_BINARY_INTEGER \
                or dbtype is DB_TYPE_NUMBER:
            if fetch_info._precision:
                display_size = fetch_info._precision + 1
                if fetch_info._scale > 0:
                    display_size += fetch_info._scale + 1
            else:
                display_size = 127
        if fetch_info._precision or fetch_info._scale:
            precision = fetch_info._precision
            scale = fetch_info._scale
        else:
            scale = precision = None
        return (fetch_info._name, dbtype, display_size or None,
                size_in_bytes or None, precision, scale,
                fetch_info._nulls_allowed)

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
