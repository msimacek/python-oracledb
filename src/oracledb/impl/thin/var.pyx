#------------------------------------------------------------------------------
# Copyright (c) 2020, 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# var.pyx
#   Cython file defining the variable class (embedded in driver.pyx).
#------------------------------------------------------------------------------

cdef class ThinVarImpl(BaseVarImpl):
    cdef:
        object _conv_func
        object _last_raw_value

    cdef int _bind(self, object conn, BaseCursorImpl cursor_impl,
                   uint32_t num_execs, object name=None,
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

        # for PL/SQL blocks, if the size of a string or bytes object exceeds
        # 32,767 bytes it must be converted to a BLOB/CLOB; and out converter
        # needs to be established as well to return the string in the way that
        # the user expects to get it
        if stmt._is_plsql and self.size > 32767:
            if self.dbtype._ora_type_num == TNS_DATA_TYPE_RAW \
                    or self.dbtype._ora_type_num == TNS_DATA_TYPE_LONG_RAW:
                self.dbtype = DB_TYPE_BLOB
            elif self.dbtype._csfrm == TNS_CS_NCHAR:
                self.dbtype = DB_TYPE_NCLOB
            else:
                self.dbtype = DB_TYPE_CLOB
            orig_converter = self.outconverter
            def converter(v):
                v = v.read()
                if orig_converter is not None:
                    v = orig_converter(v)
                return v
            self.outconverter = converter
            for idx, value in enumerate(self.values):
                lob = conn.createlob(self.dbtype)
                if value:
                    lob.write(value)
                self.values[idx] = lob

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
            if name.startswith('"') and name.endswith('"'):
                normalized_name = name[1:-1]
            else:
                normalized_name = name.upper()
            if normalized_name.startswith(":"):
                normalized_name = normalized_name[1:]
            if normalized_name not in bind_info_dict:
                errors._raise_err(errors.ERR_INVALID_BIND_NAME, name=name)
            var = var_list[name]
            for bind_info in bind_info_dict[normalized_name]:
                stmt._set_var(bind_info, var._impl, thin_cursor_impl)

        # bind by position
        else:
            num_binds = len(bind_info_list)
            num_vars = len(var_list)
            if len(bind_info_list) != len(var_list):
                errors._raise_err(errors.ERR_WRONG_NUMBER_OF_POSITIONAL_BINDS,
                                  expected_num=num_binds, actual_num=num_vars)
            idx = pos - 1
            bind_info = bind_info_list[idx]
            stmt._set_var(bind_info, var_list[idx]._impl, thin_cursor_impl)
