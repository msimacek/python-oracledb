#------------------------------------------------------------------------------
# Copyright (c) 2020, 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# var.pyx
#   Cython file defining the variable class (embedded in driver.pyx).
#------------------------------------------------------------------------------

cdef class FetchInfo:
    cdef:
        int16_t _precision
        int16_t _scale
        uint32_t _buffer_size
        uint32_t _size
        bint _nulls_allowed
        str _name
        DbType _dbtype


cdef class ThinVarImpl(BaseVarImpl):
    cdef:
        ThinConnImpl _conn_impl
        object _conv_func
        FetchInfo _fetch_info

    def __cinit__(self, conn):
        self._conn = conn
        self._conn_impl = <ThinConnImpl> conn._impl

    cdef int _bind(self, BaseCursorImpl cursor_impl, uint32_t num_execs,
                   str name=None, uint32_t pos=0) except -1:
        cdef:
            ThinCursorImpl thin_cursor_impl = <ThinCursorImpl> cursor_impl
            Statement stmt = thin_cursor_impl._statement
            uint32_t idx, num_binds, num_vars
            object var_list, bind_info_dict
            list bind_info_list
            BindInfo bind_info
            str upper_name
            object var

        bind_info_dict = stmt._bind_info_dict
        bind_info_list = stmt._bind_info_list
        var_list = thin_cursor_impl.bind_vars

        # Bind by name
        if name is not None:
            upper_name = name.upper()
            if upper_name not in bind_info_dict:
                message = f"Invalid named bind: {name}."
                errors._raise_from_string(exceptions.DatabaseError, message)
            var = var_list[name]
            for bind_info in bind_info_dict[upper_name]:
                stmt._set_var(bind_info, var, thin_cursor_impl)

        # Bind by position
        else:
            num_binds = len(bind_info_list)
            num_vars = len(var_list)
            if len(bind_info_list) != len(var_list):
                message = f"{num_binds} positional bind(s) required but " \
                          f"only {num_vars} positional bind(s) provided."
                errors._raise_from_string(exceptions.DatabaseError, message)
            idx = pos - 1
            bind_info = bind_info_list[idx]
            stmt._set_var(bind_info, var_list[idx], thin_cursor_impl)
