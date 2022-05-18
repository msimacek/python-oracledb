#------------------------------------------------------------------------------
# Copyright (c) 2020, 2022, Oracle and/or its affiliates.
#
# This software is dual-licensed to you under the Universal Permissive License
# (UPL) 1.0 as shown at https://oss.oracle.com/licenses/upl and Apache License
# 2.0 as shown at http://www.apache.org/licenses/LICENSE-2.0. You may choose
# either license.
#
# If you elect to accept the software under the Apache License, Version 2.0,
# the following applies:
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# var.pyx
#
# Cython file defining the base Variable implementation class (embedded in
# base_impl.pyx).
#------------------------------------------------------------------------------

cdef class BaseVarImpl:

    cdef int _bind(self, object conn, BaseCursorImpl cursor,
                   uint32_t num_execs, object name, uint32_t pos) except -1:
        """
        Binds a variable to the cursor.
        """
        raise NotImplementedError()

    cdef int _check_scalar_value(self, object value, bint *can_set) except -1:
        """
        Checks a scalar value to see if the type of Python value is accepted by
        the database type. An exception is raised if the can_set pointer is
        NULL; otherwise, the flag will be adjusted if the value cannot be set.
        """
        cdef:
            bint type_ok = True
            BaseLobImpl lob_impl
            uint32_t db_type_num

        # check to see that the type of value is accepted
        db_type_num = self.dbtype.num
        if db_type_num in (DB_TYPE_NUM_NUMBER, DB_TYPE_NUM_BINARY_INTEGER,
                           DB_TYPE_NUM_BINARY_DOUBLE,
                           DB_TYPE_NUM_BINARY_FLOAT):
            type_ok = isinstance(value,
                                 (PY_TYPE_BOOL, int, float, PY_TYPE_DECIMAL))
        elif db_type_num in (DB_TYPE_NUM_CHAR, DB_TYPE_NUM_VARCHAR,
                             DB_TYPE_NUM_NCHAR, DB_TYPE_NUM_NVARCHAR,
                             DB_TYPE_NUM_LONG_VARCHAR,
                             DB_TYPE_NUM_LONG_NVARCHAR,
                             DB_TYPE_NUM_RAW, DB_TYPE_NUM_LONG_RAW):
            type_ok = isinstance(value, (bytes, str))
        elif db_type_num in (DB_TYPE_NUM_DATE, DB_TYPE_NUM_TIMESTAMP,
                           DB_TYPE_NUM_TIMESTAMP_LTZ,
                           DB_TYPE_NUM_TIMESTAMP_TZ):
            type_ok = cydatetime.PyDateTime_Check(value) \
                    or cydatetime.PyDate_Check(value)
        elif db_type_num == DB_TYPE_NUM_INTERVAL_DS:
            type_ok = isinstance(value, PY_TYPE_TIMEDELTA)
        elif db_type_num in (DB_TYPE_NUM_CLOB,
                             DB_TYPE_NUM_NCLOB,
                             DB_TYPE_NUM_BLOB):
            if isinstance(value, PY_TYPE_LOB):
                lob_impl = value._impl
                if lob_impl.dbtype is not self.dbtype:
                    if can_set != NULL:
                        can_set[0] = False
                        return 0
                    errors._raise_err(errors.ERR_LOB_OF_WRONG_TYPE,
                                      actual_type_name=lob_impl.dbtype.name,
                                      expected_type_name=self.dbtype.name)
            else:
                type_ok = isinstance(value, (bytes, str))
        elif db_type_num == DB_TYPE_NUM_OBJECT:
            type_ok = isinstance(value, PY_TYPE_DB_OBJECT)
            if type_ok and value._impl.type != self.objtype:
                if can_set != NULL:
                    can_set[0] = False
                    return 0
                errors._raise_err(errors.ERR_WRONG_OBJECT_TYPE,
                                  actual_schema=value.type.schema,
                                  actual_name=value.type.name,
                                  expected_schema=self.objtype.schema,
                                  expected_name=self.objtype.name)
        elif db_type_num == DB_TYPE_NUM_CURSOR:
            type_ok = isinstance(value, PY_TYPE_CURSOR)
        elif db_type_num in (DB_TYPE_NUM_ROWID, DB_TYPE_NUM_UROWID,
                             DB_TYPE_NUM_INTERVAL_YM):
            if can_set != NULL:
                can_set[0] = False
                return 0
            errors._raise_err(errors.ERR_UNSUPPORTED_VAR_SET,
                              db_type_name=self.dbtype.name)
        if not type_ok:
            if can_set != NULL:
                can_set[0] = False
                return 0
            errors._raise_err(errors.ERR_UNSUPPORTED_PYTHON_TYPE_FOR_VAR,
                              py_type_name = type(value).__name__,
                              db_type_name = self.dbtype.name)

    cdef object _check_value(self, object value, bint *can_set):
        """
        Checks that the value can be set on the variable. The input converter
        is called, if applicable, and this value is returned if that value can
        be set; otherwise, the original value is returned since a new variable
        will be created (unless an exception is raised when the can_set pointer
        is NULL).
        """
        cdef object element_value, orig_value = value

        # scalar values can be checked directly
        if not self.is_array:
            if self.inconverter is not None:
                value = self.inconverter(value)
            if value is not None:
                self._check_scalar_value(value, can_set)
                if can_set != NULL and not can_set[0]:
                    return orig_value
            return value

        # array variables must have a list supplied to them
        if not isinstance(value, list):
            if can_set != NULL:
                can_set[0] = False
                return orig_value
            errors._raise_err(errors.ERR_EXPECTING_LIST_FOR_ARRAY_VAR)

        # the size of the array must be sufficient to hold all of the
        # elements
        if len(value) > self.num_elements:
            if can_set != NULL:
                can_set[0] = False
                return orig_value
            errors._raise_err(errors.ERR_INCORRECT_VAR_ARRAY_SIZE,
                              var_arraysize=self.arraysize,
                              required_arraysize=len(value))

        # if an input converter is specified, call it for each of the elements
        # in the list
        if self.inconverter is not None:
            value = [self.inconverter(v) for v in value]

        # check each of the element's values
        for element_value in value:
            if value is not None:
                self._check_scalar_value(element_value, can_set)
                if can_set != NULL and not can_set[0]:
                    return orig_value

        return value

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

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cdef int _set_scalar_value(self, ssize_t pos, object value) except -1:
        """
        Set the value of the variable at the given position. At this point it
        is assumed that all checks have been performed!
        """
        cdef:
            uint32_t db_type_num, size
            object orig_value
        if value is not None:
            db_type_num = self.dbtype.num
            if db_type_num in (DB_TYPE_NUM_CHAR, DB_TYPE_NUM_VARCHAR,
                                 DB_TYPE_NUM_NCHAR, DB_TYPE_NUM_NVARCHAR,
                                 DB_TYPE_NUM_LONG_VARCHAR,
                                 DB_TYPE_NUM_LONG_NVARCHAR):
                if isinstance(value, bytes):
                    value = (<bytes> value).decode()
                size = <uint32_t> len(<str> value)
                if size > self.size:
                    self._resize(size)
            elif db_type_num in (DB_TYPE_NUM_RAW, DB_TYPE_NUM_LONG_RAW):
                if isinstance(value, str):
                    value = (<str> value).encode()
                size = <uint32_t> len(<bytes> value)
                if size > self.size:
                    self._resize(size)
            elif db_type_num in (DB_TYPE_NUM_CLOB, DB_TYPE_NUM_NCLOB,
                                 DB_TYPE_NUM_BLOB):
                if not isinstance(value, PY_TYPE_LOB):
                    orig_value = self.values[pos]
                    if isinstance(orig_value, PY_TYPE_LOB):
                        orig_value.trim()
                        if value:
                            orig_value.write(value)
                        value = orig_value
            elif db_type_num == DB_TYPE_NUM_BOOLEAN:
                value = bool(value)
            elif db_type_num in (DB_TYPE_NUM_NUMBER,
                                 DB_TYPE_NUM_BINARY_INTEGER,
                                 DB_TYPE_NUM_BINARY_FLOAT,
                                 DB_TYPE_NUM_BINARY_DOUBLE):
                if db_type_num in (DB_TYPE_NUM_BINARY_FLOAT,
                                   DB_TYPE_NUM_BINARY_DOUBLE):
                    value = float(value)
                elif db_type_num == DB_TYPE_NUM_BINARY_INTEGER \
                        or cpython.PyBool_Check(value):
                    value = int(value)
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
        elif isinstance(value, (PY_TYPE_DATE, PY_TYPE_DATETIME)):
            dbtype = DB_TYPE_DATE
        elif isinstance(value, PY_TYPE_TIMEDELTA):
            dbtype = DB_TYPE_INTERVAL_DS
        elif isinstance(value, PY_TYPE_DB_OBJECT):
            dbtype = DB_TYPE_OBJECT
            objtype = value.type._impl
        elif isinstance(value, PY_TYPE_LOB):
            dbtype = value.type
        elif isinstance(value, PY_TYPE_CURSOR):
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

    cdef int _set_value(self, ssize_t pos, object value) except -1:
        """
        Set the value of the variable at the given position. At this point it
        is assumed that all checks have been performed!
        """
        cdef:
            object element_value
            ssize_t i
        if self.is_array:
            for i, element_value in enumerate(value):
                self._set_scalar_value(i, element_value)
            self.num_elements_in_array = len(value)
        else:
            self._set_scalar_value(pos, value)
        self._is_value_set = True

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

    def get_value(self, uint32_t pos):
        """
        Internal method for getting the value of a variable.
        """
        if self.is_array:
            return self.values[:self.num_elements_in_array]
        if pos >= self.num_elements:
            raise IndexError("position out of range")
        return self.values[pos]

    def set_value(self, ssize_t pos, object value):
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
        elif pos >= self.num_elements:
            raise IndexError("position out of range")
        value = self._check_value(value, NULL)
        self._set_value(pos, value)
