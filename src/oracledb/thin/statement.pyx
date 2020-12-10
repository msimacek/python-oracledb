#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class BindInfo:

    cdef:
        bint _is_dup
        bint _is_return_bind
        str _bind_name
        Var _bind_var

    def __cinit__(self, str name):
        self._bind_name = name


cdef class StatementCache:

    cdef:
        uint32_t _max_entries
        object _statements

    def __init__(self, max_entries):
        self._max_entries = max_entries
        self._statements = collections.OrderedDict()

    def get_statement(self, sql):
        statement = self._statements.get(sql)
        if statement is not None:
            self._statements.move_to_end(sql)
        return statement

    cdef put_statement(self, Statement statement):
        self._statements[statement._sql] = statement
        self._statements.move_to_end(statement._sql)
        if len(self._statements) > self._max_entries:
            self.statements.popitem(last=False)

    def set_max_entries(self, max_entries):
        while len(self._statements) > max_entries:
            self.statements.popitem(last=False)
        self._max_entries = max_entries


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

    cdef _determine_statement_type(self, str sql):
        tokens = sql.strip()[:10].split()
        if tokens:
            sql_keyword = tokens[0]
            if sql_keyword in ("DECLARE", "BEGIN", "CALL"):
                self._is_plsql = True
            elif sql_keyword in ("SELECT", "WITH"):
                self._is_query = True
            elif sql_keyword in ("INSERT", "UPDATE", "DELETE", "MERGE"):
                self._is_dml = True
            elif sql_keyword in ("CREATE", "ALTER", "DROP"):
                self._is_ddl = True
        if not self._is_plsql and "RETURNING" in sql:
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
            str name, return_str
            BindInfo bind_info

        # Strip single/multiline comments and strings from the sql statement
        sql = re.sub(r"/\\*[\S\n ]+\\*/", "", sql)
        sql = re.sub(r"\--.*(\n|$)", "", sql)
        sql = re.sub(r"'(.*?)+'", "", sql)

        # determine statement type
        sql = sql.upper()
        self._determine_statement_type(sql)

        # bind variables can only be found in queries, DML and PL/SQL
        if self._is_query or self._is_dml or self._is_plsql:
            bind_names = re.findall(r"(?<=\:)[A-Z]?[A-Z0-9_]+", sql)
            if self._is_plsql:
                bind_names = list(collections.OrderedDict.fromkeys(bind_names))

        # find all bind variables used in DML returning
        if self._is_returning:
            return_str = re.findall(r"RETURNING.*?$|\;", sql)[0]
            return_bind_names = re.findall(r"(?<=\:)[A-Z]?[A-Z0-9_]+",
                                           return_str)

        self._bind_info_dict = collections.OrderedDict()
        self._bind_info_list = [BindInfo(name) for name in bind_names]
        for bind_info in self._bind_info_list:
            if bind_info._bind_name in self._bind_info_dict:
                bind_info._is_dup = True
                self._bind_info_dict[bind_info._bind_name].append(bind_info)
            else:
                self._bind_info_dict[bind_info._bind_name] = [bind_info]
            if bind_info._bind_name in return_bind_names:
                bind_info._is_return_bind = True
