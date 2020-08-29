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

    def __repr__(self):
        return f"<ApiType {self.name}>"


cdef dict db_type_by_num = {}

cdef class DbType:

    def __init__(self, num, name, default_size=0):
        self.num = num
        self.name = name
        self.default_size = default_size
        db_type_by_num[num] = self

    def __repr__(self):
        return f"<DbType {self.name}>"

    @staticmethod
    cdef DbType _from_num(uint32_t num):
        try:
            return db_type_by_num[num]
        except KeyError:
            pass
        errors._raise_from_string(exceptions.NotSupportedError,
                                  f"Oracle type {num} not supported")

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


# database types
DB_TYPE_BFILE = DbType(2020, "DB_TYPE_BFILE")
DB_TYPE_BINARY_DOUBLE = DbType(2008, "DB_TYPE_BINARY_DOUBLE")
DB_TYPE_BINARY_FLOAT = DbType(2007, "DB_TYPE_BINARY_FLOAT")
DB_TYPE_BINARY_INTEGER = DbType(2009, "DB_TYPE_BINARY_INTEGER")
DB_TYPE_BLOB = DbType(2019, "DB_TYPE_BLOB")
DB_TYPE_BOOLEAN = DbType(2022, "DB_TYPE_BOOLEAN")
DB_TYPE_CHAR = DbType(2003, "DB_TYPE_CHAR", 2000)
DB_TYPE_CLOB = DbType(2017, "DB_TYPE_CLOB")
DB_TYPE_CURSOR = DbType(2021, "DB_TYPE_CURSOR")
DB_TYPE_DATE = DbType(2011, "DB_TYPE_DATE")
DB_TYPE_INTERVAL_DS = DbType(2015, "DB_TYPE_INTERVAL_DS")
DB_TYPE_INTERVAL_YM = DbType(2016, "DB_TYPE_INTERVAL_YM")
DB_TYPE_LONG = DbType(2024, "DB_TYPE_LONG", 128 * 1024)
DB_TYPE_LONG_RAW = DbType(2025, "DB_TYPE_LONG_RAW", 128 * 1024)
DB_TYPE_NCHAR = DbType(2004, "DB_TYPE_NCHAR", 2000)
DB_TYPE_NCLOB = DbType(2018, "DB_TYPE_NCLOB")
DB_TYPE_NUMBER = DbType(2010, "DB_TYPE_NUMBER")
DB_TYPE_NVARCHAR = DbType(2002, "DB_TYPE_NVARCHAR", 4000)
DB_TYPE_OBJECT = DbType(2023, "DB_TYPE_OBJECT")
DB_TYPE_RAW = DbType(2006, "DB_TYPE_RAW", 4000)
DB_TYPE_ROWID = DbType(2005, "DB_TYPE_ROWID")
DB_TYPE_TIMESTAMP = DbType(2012, "DB_TYPE_TIMESTAMP")
DB_TYPE_TIMESTAMP_LTZ = DbType(2014, "DB_TYPE_TIMESTAMP_LTZ")
DB_TYPE_TIMESTAMP_TZ = DbType(2013, "DB_TYPE_TIMESTAMP_TZ")
DB_TYPE_VARCHAR = DbType(2001, "DB_TYPE_VARCHAR", 4000)

# DB API types
BINARY = ApiType("BINARY", DB_TYPE_RAW, DB_TYPE_LONG_RAW)
DATETIME = ApiType("DATETIME", DB_TYPE_DATE, DB_TYPE_TIMESTAMP,
                   DB_TYPE_TIMESTAMP_LTZ, DB_TYPE_TIMESTAMP_TZ)
NUMBER = ApiType("NUMBER", DB_TYPE_NUMBER, DB_TYPE_BINARY_DOUBLE,
                 DB_TYPE_BINARY_FLOAT, DB_TYPE_BINARY_INTEGER)
ROWID = ApiType("ROWID", DB_TYPE_ROWID)
STRING = ApiType("STRING", DB_TYPE_VARCHAR, DB_TYPE_NVARCHAR, DB_TYPE_CHAR,
                 DB_TYPE_NCHAR, DB_TYPE_LONG)
