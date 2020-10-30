#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

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
        list _bind_names

    cdef _determine_statement_type(self, str sql):
        tokens = sql.strip()[:10].split()
        if tokens:
            sql_keyword = tokens[0].lower()
            if sql_keyword in ("declare", "begin", "call"):
                self._is_plsql = True
            elif sql_keyword in ("select", "with"):
                self._is_query = True
            elif sql_keyword in ("insert", "update", "delete", "merge"):
                self._is_dml = True
            elif sql_keyword in ("create", "alter", "drop"):
                self._is_ddl = True

    cdef _prepare(self, str sql):
        self._sql = sql
        sql = sql.strip()
        self._sql_bytes = sql.encode()
        self._sql_bytes_length = <uint32_t> len(self._sql_bytes)
        self._get_bind_names(sql)

    cdef _get_bind_names(self, str sql):
        # Strip any single or multiline comments from sql statement
        sql = re.sub(r"/\\*[\S\n ]+\\*/", "", sql)
        sql = re.sub(r"\--.*(\n|$)", "", sql)

        # dtermine statement type
        self._determine_statement_type(sql)

        # bind variables can only be found in queries, DML and PL/SQL
        if self._is_query or self._is_dml or self._is_plsql:
            self._bind_names = re.findall(r"(?<=\:)[a-zA-Z]?[a-zA-Z0-9_]+",
                                          sql.upper())
        else:
            self._bind_names = []
