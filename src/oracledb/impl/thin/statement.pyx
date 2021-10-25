#------------------------------------------------------------------------------
# Copyright (c) 2020, 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class BindInfo:

    cdef:
        uint32_t num_elements
        bint _is_return_bind
        uint8_t ora_type_num
        uint32_t buffer_size
        int16_t precision
        uint8_t bind_dir
        uint32_t size
        str _bind_name
        bint is_array
        int16_t scale
        uint8_t csfrm
        object _bind_var

    def __cinit__(self, str name):
        self._bind_name = name

    cdef BindInfo copy(self):
        cdef BindInfo copied_bind_info = BindInfo(self._bind_name)
        copied_bind_info._is_return_bind = self._is_return_bind
        return copied_bind_info


cdef class Statement:

    cdef:
        str _sql
        bytes _sql_bytes
        uint32_t _sql_bytes_length
        uint16_t _cursor_id
        bint _is_query
        bint _is_plsql
        bint _is_dml
        bint _is_ddl
        bint _is_returning
        list _bind_info_list
        list _fetch_vars
        object _bind_info_dict
        object _last_output_type_handler
        bint _requires_full_execute
        bint _return_to_cache
        bint _in_use

    cdef Statement copy(self):
        cdef:
            Statement copied_statement = Statement()
            object bind_info_dict
            BindInfo bind_info
        copied_statement._sql = self._sql
        copied_statement._sql_bytes = self._sql_bytes
        copied_statement._sql_bytes_length = self._sql_bytes_length
        copied_statement._is_query = self._is_query
        copied_statement._is_plsql = self._is_plsql
        copied_statement._is_dml = self._is_dml
        copied_statement._is_ddl = self._is_ddl
        copied_statement._is_returning = self._is_returning
        copied_statement._bind_info_list = \
                [bind_info.copy() for bind_info in self._bind_info_list]
        copied_statement._bind_info_dict = collections.OrderedDict()
        bind_info_dict = copied_statement._bind_info_dict
        for bind_info in copied_statement._bind_info_list:
            if bind_info._bind_name in bind_info_dict:
                bind_info_dict[bind_info._bind_name].append(bind_info)
            else:
                bind_info_dict[bind_info._bind_name] = [bind_info]
        copied_statement._return_to_cache = False
        return copied_statement

    cdef _determine_statement_type(self, str sql, str dml_pattern):
        tokens = sql.strip().lstrip("(")[:10].split()
        if tokens:
            sql_keyword = tokens[0]
            if sql_keyword in ("DECLARE", "BEGIN", "CALL"):
                self._is_plsql = True
            elif sql_keyword in ("SELECT", "WITH"):
                self._is_query = True
            elif sql_keyword in ("INSERT", "UPDATE", "DELETE", "MERGE"):
                self._is_dml = True
            elif sql_keyword in ("CREATE", "ALTER", "DROP", "TRUNCATE"):
                self._is_ddl = True
        if not self._is_plsql and re.search(dml_pattern, sql) is not None:
            self._is_returning = True

    cdef _prepare(self, str sql):
        self._sql = sql
        sql = sql.strip()
        self._sql_bytes = sql.encode()
        self._sql_bytes_length = <uint32_t> len(self._sql_bytes)
        self._get_bind_names(sql)

    cdef _get_bind_names(self, str sql):
        cdef:
            list bind_names = [], return_bind_names = []
            str name, return_str, dml_pattern
            BindInfo bind_info

        # Strip single/multiline comments and strings from the sql statement
        sql = re.sub(r"/\*[\S\n ]+\*/", "", sql)
        sql = re.sub(r"\--.*(\n|$)", "", sql)
        sql = re.sub(r"'(.*?)+'", "", sql)

        # determine statement type
        sql = sql.upper()
        dml_pattern = r"RETURNING [\s\S]+ INTO .*?$|\;"
        self._determine_statement_type(sql, dml_pattern)

        # bind variables can only be found in queries, DML and PL/SQL
        if self._is_query or self._is_dml or self._is_plsql:
            bind_names = re.findall(r"(?<=\:)[A-Z]?[A-Z0-9_]+", sql)
            if self._is_plsql:
                bind_names = list(collections.OrderedDict.fromkeys(bind_names))

        # find all bind variables used in DML returning
        if self._is_returning:
            return_str = re.findall(dml_pattern, sql)[0]
            return_bind_names = re.findall(r"(?<=\:)[A-Z]?[A-Z0-9_]+",
                                           return_str)

        self._bind_info_dict = collections.OrderedDict()
        self._bind_info_list = [BindInfo(name) for name in bind_names]
        for bind_info in self._bind_info_list:
            if bind_info._bind_name in self._bind_info_dict:
                self._bind_info_dict[bind_info._bind_name].append(bind_info)
            else:
                self._bind_info_dict[bind_info._bind_name] = [bind_info]
            if bind_info._bind_name in return_bind_names:
                bind_info._is_return_bind = True

    cdef int _set_var(self, BindInfo bind_info, object var,
                      ThinCursorImpl cursor_impl) except -1:
        """
        Set the variable on the bind information and copy across metadata that
        will be used for binding. If the bind metadata has changed, mark the
        statement as requiring a full execute. In addition, binding a REF
        cursor also requires a full execute.
        """
        cdef:
            ThinVarImpl var_impl = <ThinVarImpl> var._impl
            object value
        if var_impl.dbtype._ora_type_num == TNS_DATA_TYPE_CURSOR:
            for value in var_impl.values:
                if value is not None and value._impl is cursor_impl:
                    errors._raise_err(errors.ERR_SELF_BIND_NOT_SUPPORTED)
            self._requires_full_execute = True
        if var_impl.dbtype._ora_type_num != bind_info.ora_type_num \
                or var_impl.size > bind_info.size \
                or var_impl.buffer_size > bind_info.buffer_size \
                or var_impl.precision != bind_info.precision \
                or var_impl.scale != bind_info.scale \
                or var_impl.is_array != bind_info.is_array \
                or var_impl.num_elements > bind_info.num_elements \
                or var_impl.dbtype._csfrm != bind_info.csfrm:
            bind_info.ora_type_num = var_impl.dbtype._ora_type_num
            bind_info.csfrm = var_impl.dbtype._csfrm
            bind_info.is_array = var_impl.is_array
            bind_info.num_elements = var_impl.num_elements
            bind_info.size = var_impl.size
            bind_info.buffer_size = var_impl.buffer_size
            bind_info.precision = var_impl.precision
            bind_info.scale = var_impl.scale
            self._requires_full_execute = True
        bind_info._bind_var = var
