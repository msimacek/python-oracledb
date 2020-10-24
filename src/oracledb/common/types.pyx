#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class ApiType:

    def __init__(self, name, *dbtypes):
        self.name = name
        self.dbtypes = dbtypes

    def __eq__(self, other):
        if isinstance(other, DbType):
            return other in self.dbtypes
        return NotImplemented

    def __hash__(self):
        return hash(self.name)

    def __reduce__(self):
        return self.name

    def __repr__(self):
        return f"<ApiType {self.name}>"


cdef dict db_type_by_num = {}
cdef dict db_type_by_ora_type_num = {}

cdef class DbType:

    def __init__(self, num, name, ora_type_num, default_size=0, csfrm=0,
                 buffer_size_factor=0):
        cdef uint16_t ora_type_key = csfrm * 256 + ora_type_num
        self.num = num
        self.name = name
        self.default_size = default_size
        self._ora_type_num = ora_type_num
        self._csfrm = csfrm
        self._buffer_size_factor = buffer_size_factor
        db_type_by_num[num] = self
        db_type_by_ora_type_num[ora_type_key] = self

    def __reduce__(self):
        return self.name

    def __repr__(self):
        return f"<DbType {self.name}>"

    @staticmethod
    cdef DbType _from_num(uint32_t num):
        try:
            return db_type_by_num[num]
        except KeyError:
            pass
        msg = f"Oracle type {num} not supported"
        errors._raise_from_string(exceptions.NotSupportedError, msg)

    @staticmethod
    cdef DbType _from_ora_type_and_csfrm(uint8_t ora_type_num, uint8_t csfrm):
        cdef uint16_t ora_type_key = csfrm * 256 + ora_type_num
        try:
            return db_type_by_ora_type_num[ora_type_key]
        except KeyError:
            pass
        msg = f"Oracle type {ora_type_num} not supported"
        errors._raise_from_string(exceptions.NotSupportedError, msg)

    @staticmethod
    cdef DbType _from_type(object typ):
        cdef ApiType apitype
        if isinstance(typ, DbType):
            return typ
        elif isinstance(typ, ApiType):
            apitype = typ
            return apitype.dbtypes[0]
        elif not isinstance(typ, type):
            errors._raise_from_string(TypeError, "expecting type")
        elif typ is int:
            return DB_TYPE_NUMBER
        elif typ is float:
            return DB_TYPE_NUMBER
        elif typ is str:
            return DB_TYPE_VARCHAR
        elif typ is bytes:
            return DB_TYPE_RAW
        elif typ is decimal.Decimal:
            return DB_TYPE_NUMBER
        elif typ is bool:
            return DB_TYPE_BOOLEAN
        elif typ is datetime.date:
            return DB_TYPE_DATE
        elif typ is datetime.datetime:
            return DB_TYPE_TIMESTAMP
        elif typ is datetime.timedelta:
            return DB_TYPE_INTERVAL_DS
        else:
            errors._raise_from_string(exceptions.NotSupportedError,
                                      f"Python type {typ} not supported")

    @staticmethod
    cdef DbType _from_value(object value, uint32_t *size):
        if value is None:
            return None
        elif isinstance(value, bool):
            return DB_TYPE_BOOLEAN
        elif isinstance(value, str):
            size[0] = <uint32_t> len(value)
            return DB_TYPE_VARCHAR
        elif isinstance(value, bytes):
            size[0] = <uint32_t> len(value)
            return DB_TYPE_RAW
        elif isinstance(value, (int, float, decimal.Decimal)):
            return DB_TYPE_NUMBER
        elif isinstance(value, (datetime.date, datetime.datetime)):
            return DB_TYPE_DATE
        elif isinstance(value, datetime.timedelta):
            return DB_TYPE_INTERVAL_DS
        else:
            type_name = type(value).__name__
            message = f"Python value of type {type_name} not supported"
            errors._raise_from_string(exceptions.NotSupportedError, message)


# database types
DB_TYPE_BFILE = DbType(2020, "DB_TYPE_BFILE", 114)
DB_TYPE_BINARY_DOUBLE = DbType(2008, "DB_TYPE_BINARY_DOUBLE", 101)
DB_TYPE_BINARY_FLOAT = DbType(2007, "DB_TYPE_BINARY_FLOAT", 100)
DB_TYPE_BINARY_INTEGER = DbType(2009, "DB_TYPE_BINARY_INTEGER", 3)
DB_TYPE_BLOB = DbType(2019, "DB_TYPE_BLOB", 113)
DB_TYPE_BOOLEAN = DbType(2022, "DB_TYPE_BOOLEAN", 252)
DB_TYPE_CHAR = DbType(2003, "DB_TYPE_CHAR", 96, 2000, csfrm=1,
                      buffer_size_factor=4)
DB_TYPE_CLOB = DbType(2017, "DB_TYPE_CLOB", 112)
DB_TYPE_CURSOR = DbType(2021, "DB_TYPE_CURSOR", 116)
DB_TYPE_DATE = DbType(2011, "DB_TYPE_DATE", 12, buffer_size_factor=7)
DB_TYPE_INTERVAL_DS = DbType(2015, "DB_TYPE_INTERVAL_DS", 190)
DB_TYPE_INTERVAL_YM = DbType(2016, "DB_TYPE_INTERVAL_YM", 189)
DB_TYPE_LONG = DbType(2024, "DB_TYPE_LONG", 8, 128 * 1024, csfrm=1,
                      buffer_size_factor=4)
DB_TYPE_LONG_RAW = DbType(2025, "DB_TYPE_LONG_RAW", 24, 128 * 1024,
                          buffer_size_factor=1)
DB_TYPE_NCHAR = DbType(2004, "DB_TYPE_NCHAR", 96, 2000, csfrm=2,
                       buffer_size_factor=4)
DB_TYPE_NCLOB = DbType(2018, "DB_TYPE_NCLOB", 112, csfrm=2)
DB_TYPE_NUMBER = DbType(2010, "DB_TYPE_NUMBER", 2, buffer_size_factor=22)
DB_TYPE_NVARCHAR = DbType(2002, "DB_TYPE_NVARCHAR", 1, 4000, csfrm=2,
                          buffer_size_factor=4)
DB_TYPE_OBJECT = DbType(2023, "DB_TYPE_OBJECT", 108)
DB_TYPE_RAW = DbType(2006, "DB_TYPE_RAW", 23, 4000, buffer_size_factor=1)
DB_TYPE_ROWID = DbType(2005, "DB_TYPE_ROWID", 11)
DB_TYPE_TIMESTAMP = DbType(2012, "DB_TYPE_TIMESTAMP", 180,
                           buffer_size_factor=11)
DB_TYPE_TIMESTAMP_LTZ = DbType(2014, "DB_TYPE_TIMESTAMP_LTZ", 231,
                               buffer_size_factor=11)
DB_TYPE_TIMESTAMP_TZ = DbType(2013, "DB_TYPE_TIMESTAMP_TZ", 181,
                              buffer_size_factor=13)
DB_TYPE_VARCHAR = DbType(2001, "DB_TYPE_VARCHAR", 1, 4000, csfrm=1,
                         buffer_size_factor=4)

# DB API types
BINARY = ApiType("BINARY", DB_TYPE_RAW, DB_TYPE_LONG_RAW)
DATETIME = ApiType("DATETIME", DB_TYPE_DATE, DB_TYPE_TIMESTAMP,
                   DB_TYPE_TIMESTAMP_LTZ, DB_TYPE_TIMESTAMP_TZ)
NUMBER = ApiType("NUMBER", DB_TYPE_NUMBER, DB_TYPE_BINARY_DOUBLE,
                 DB_TYPE_BINARY_FLOAT, DB_TYPE_BINARY_INTEGER)
ROWID = ApiType("ROWID", DB_TYPE_ROWID)
STRING = ApiType("STRING", DB_TYPE_VARCHAR, DB_TYPE_NVARCHAR, DB_TYPE_CHAR,
                 DB_TYPE_NCHAR, DB_TYPE_LONG)
