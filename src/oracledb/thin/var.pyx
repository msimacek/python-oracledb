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

    cdef object _get_single_value(self, uint32_t pos):
        return self._values[pos]

    cdef int _set_single_value(self, uint32_t pos, object value) except -1:
        if self.inconverter:
            value = self.inconverter(value)
        self._values[pos] = value
