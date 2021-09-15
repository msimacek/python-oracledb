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
        object _conv_func
        FetchInfo _fetch_info

    cdef int _bind(self, object conn, BaseCursorImpl cursor_impl,
                   uint32_t num_execs, str name=None,
                   uint32_t pos=0) except -1:
        cdef:
            ThinCursorImpl thin_cursor_impl = <ThinCursorImpl> cursor_impl
            object var_list, bind_info_dict, var, value, lob
            Statement stmt = thin_cursor_impl._statement
            uint32_t idx, num_binds, num_vars
            list bind_info_list
            BindInfo bind_info
            str normalized_name

        bind_info_dict = stmt._bind_info_dict
        bind_info_list = stmt._bind_info_list
        var_list = thin_cursor_impl.bind_vars

        # for variables containing LOBs, create temporary LOBs, if needed
        if self.dbtype._ora_type_num == TNS_DATA_TYPE_CLOB \
                or self.dbtype._ora_type_num == TNS_DATA_TYPE_BLOB:
            idx = 0
            for value in self.values:
                if value is not None and not isinstance(value, LOB):
                    lob = conn.createlob(self.dbtype)
                    if value:
                        lob.write(value)
                    self.values[idx] = lob
                idx += 1

        # bind by name
        if name is not None:
            normalized_name = name.upper()
            if normalized_name.startswith(":"):
                normalized_name = normalized_name[1:]
            if normalized_name not in bind_info_dict:
                errors._raise_err(errors.ERR_INVALID_BIND_NAME, name=name)
            var = var_list[name]
            for bind_info in bind_info_dict[normalized_name]:
                stmt._set_var(bind_info, var, thin_cursor_impl)

        # bind by position
        else:
            num_binds = len(bind_info_list)
            num_vars = len(var_list)
            if len(bind_info_list) != len(var_list):
                errors._raise_err(errors.ERR_WRONG_NUMBER_OF_POSITIONAL_BINDS,
                                  expected_num=num_binds, actual_num=num_vars)
            idx = pos - 1
            bind_info = bind_info_list[idx]
            stmt._set_var(bind_info, var_list[idx], thin_cursor_impl)
