#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# var.pyx
#   Cython file defining the variable class (embedded in driver.pyx).
#------------------------------------------------------------------------------

cdef class Var(BaseVar):
    cdef:
        Connection _connection
        list _values
        uint32_t _num_elements_in_array

    def __cinit__(self, connection):
        self._connection = connection

    cdef int _bind(self, BaseCursor cursor, str name=None,
                   uint32_t pos=0) except -1:
        cdef:
            Cursor thin_cursor
            uint32_t idx, num_binds, num_vars
            list bind_info_list
            object var_list, bind_info_dict
            BindInfo bind_info
            str upper_name
            Var var

        thin_cursor = <Cursor> cursor
        bind_info_dict = thin_cursor._statement._bind_info_dict
        bind_info_list = thin_cursor._statement._bind_info_list
        var_list = thin_cursor._bind_vars

        if name is not None:
            # Bind by name
            upper_name = name.upper()
            if upper_name not in bind_info_dict:
                message = f"Invalid named bind: {name}."
                errors._raise_from_string(exceptions.DatabaseError, message)
            var = var_list[name]
            for bind_info in bind_info_dict[upper_name]:
                bind_info._bind_var = var
        else:
            # Bind by position
            num_binds = len(bind_info_list)
            num_vars = len(var_list)
            if len(bind_info_list) != len(var_list):
                message = f"{num_binds} positional bind(s) required but " \
                          f"only {num_vars} positional bind(s) provided."
                errors._raise_from_string(exceptions.DatabaseError, message)
            idx = pos - 1
            bind_info = bind_info_list[idx]
            bind_info._bind_var = var_list[idx]

    cdef int _finalize_init(self) except -1:
        self._values = [None] * self.num_elements

    cdef uint32_t _get_actual_elements(self) except *:
        if self.is_array:
            return self._num_elements_in_array
        return self.num_elements

    cdef list _get_array_value(self, uint32_t num_elements):
        return self._values[:num_elements]

    cdef object _get_single_value(self, uint32_t pos):
        return self._values[pos]

    cdef int _set_array_value(self, list value) except -1:
        cdef uint32_t i
        for i, element_value in enumerate(value):
            self._set_single_value(i, element_value)
        self._num_elements_in_array = <uint32_t> len(value)

    cdef int _set_single_value(self, uint32_t pos, object value) except -1:
        cdef:
            uint8_t ora_type_num
            Lob lob
        if self.inconverter:
            value = self.inconverter(value)
        if value is not None:
            ora_type_num = self._dbtype._ora_type_num
            if ora_type_num == TNS_DATA_TYPE_NUMBER \
                    or ora_type_num == TNS_DATA_TYPE_BINARY_INTEGER:
                if not isinstance(value, (bool, int, float, decimal.Decimal)):
                    raise TypeError("expecting number or boolean")
            elif ora_type_num == TNS_DATA_TYPE_VARCHAR \
                    or ora_type_num == TNS_DATA_TYPE_CHAR \
                    or ora_type_num == TNS_DATA_TYPE_LONG:
                if not isinstance(value, str):
                    raise TypeError("expecting string")
                if len(value) > self.size:
                    self.size = len(value)
                    self.buffer_size = len(value)
            elif ora_type_num == TNS_DATA_TYPE_RAW \
                    or ora_type_num == TNS_DATA_TYPE_LONG_RAW:
                if not isinstance(value, bytes):
                    raise TypeError("expecting bytes")
                if len(value) > self.size:
                    self.size = len(value)
                    self.buffer_size = len(value)
            elif ora_type_num == TNS_DATA_TYPE_DATE \
                    or ora_type_num == TNS_DATA_TYPE_TIMESTAMP \
                    or ora_type_num == TNS_DATA_TYPE_TIMESTAMP_LTZ \
                    or ora_type_num == TNS_DATA_TYPE_TIMESTAMP_TZ:
                if not isinstance(value, (datetime.date, datetime.datetime)):
                    message = "expecting datetime.date or datetime.datetime"
                    raise TypeError(message)
            elif ora_type_num == TNS_DATA_TYPE_CLOB \
                    or ora_type_num == TNS_DATA_TYPE_BLOB:
                if isinstance(value, Lob):
                    lob = <Lob> value
                    if lob.type is not self._dbtype:
                        message = f"LOB must be of type {self._dbtype}"
                        raise TypeError(message)
                else:
                    lob = <Lob> self._values[pos]
                    if lob is None:
                        lob = self._connection.createlob(self._dbtype)
                    if value:
                        lob.write(value)
                    value = lob
            elif ora_type_num == TNS_DATA_TYPE_ROWID:
                msg = "Rowid variables cannot be set directly"
                errors._raise_from_string(exceptions.NotSupportedError, msg)
        self._values[pos] = value
