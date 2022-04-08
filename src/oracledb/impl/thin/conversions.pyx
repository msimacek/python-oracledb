#------------------------------------------------------------------------------
# Copyright (c) 2021, 2022, Oracle and/or its affiliates.
# This program is free software: you can modify it and/or redistribute it
# under the terms of:
#
# (i)  the Universal Permissive License v 1.0 or at your option, any
#      later version (http://oss.oracle.com/licenses/upl); and/or
#
# (ii) the Apache License v 2.0. (http://www.apache.org/licenses/LICENSE-2.0)
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# conversions.pyx
#
# Cython file defining the conversions between data types that are supported by
# the thin client (embedded in thin_impl.pyx).
#------------------------------------------------------------------------------

cdef converter_dict = {
    (TNS_DATA_TYPE_CHAR, TNS_DATA_TYPE_NUMBER): float,
    (TNS_DATA_TYPE_VARCHAR, TNS_DATA_TYPE_NUMBER): float,
    (TNS_DATA_TYPE_LONG, TNS_DATA_TYPE_NUMBER): float,
    (TNS_DATA_TYPE_BINARY_INTEGER, TNS_DATA_TYPE_NUMBER):float,
    (TNS_DATA_TYPE_CHAR, TNS_DATA_TYPE_BINARY_INTEGER):_to_binary_int,
    (TNS_DATA_TYPE_VARCHAR, TNS_DATA_TYPE_BINARY_INTEGER): _to_binary_int,
    (TNS_DATA_TYPE_LONG, TNS_DATA_TYPE_BINARY_INTEGER): _to_binary_int,
    (TNS_DATA_TYPE_NUMBER, TNS_DATA_TYPE_BINARY_INTEGER): _to_binary_int,
    (TNS_DATA_TYPE_BINARY_FLOAT, TNS_DATA_TYPE_BINARY_INTEGER):
            _to_binary_int,
    (TNS_DATA_TYPE_BINARY_DOUBLE, TNS_DATA_TYPE_BINARY_INTEGER):
            _to_binary_int,
    (TNS_DATA_TYPE_DATE, TNS_DATA_TYPE_CHAR): str,
    (TNS_DATA_TYPE_DATE, TNS_DATA_TYPE_VARCHAR): str,
    (TNS_DATA_TYPE_DATE, TNS_DATA_TYPE_LONG): str,
    (TNS_DATA_TYPE_NUMBER, TNS_DATA_TYPE_VARCHAR): NUM_TYPE_STR,
    (TNS_DATA_TYPE_NUMBER, TNS_DATA_TYPE_CHAR): NUM_TYPE_STR,
    (TNS_DATA_TYPE_NUMBER, TNS_DATA_TYPE_LONG): NUM_TYPE_STR,
    (TNS_DATA_TYPE_BINARY_DOUBLE, TNS_DATA_TYPE_VARCHAR): str,
    (TNS_DATA_TYPE_BINARY_FLOAT, TNS_DATA_TYPE_VARCHAR): str,
    (TNS_DATA_TYPE_BINARY_DOUBLE, TNS_DATA_TYPE_CHAR): str,
    (TNS_DATA_TYPE_BINARY_FLOAT, TNS_DATA_TYPE_CHAR): str,
    (TNS_DATA_TYPE_BINARY_DOUBLE, TNS_DATA_TYPE_LONG): str,
    (TNS_DATA_TYPE_BINARY_FLOAT, TNS_DATA_TYPE_LONG): str,
    (TNS_DATA_TYPE_TIMESTAMP, TNS_DATA_TYPE_VARCHAR): str,
    (TNS_DATA_TYPE_TIMESTAMP, TNS_DATA_TYPE_CHAR): str,
    (TNS_DATA_TYPE_TIMESTAMP, TNS_DATA_TYPE_LONG): str,
    (TNS_DATA_TYPE_TIMESTAMP_TZ, TNS_DATA_TYPE_VARCHAR): str,
    (TNS_DATA_TYPE_TIMESTAMP_TZ, TNS_DATA_TYPE_CHAR): str,
    (TNS_DATA_TYPE_TIMESTAMP_TZ, TNS_DATA_TYPE_LONG): str,
    (TNS_DATA_TYPE_TIMESTAMP_LTZ, TNS_DATA_TYPE_VARCHAR): str,
    (TNS_DATA_TYPE_TIMESTAMP_LTZ, TNS_DATA_TYPE_CHAR): str,
    (TNS_DATA_TYPE_TIMESTAMP_LTZ, TNS_DATA_TYPE_LONG): str,
    (TNS_DATA_TYPE_ROWID, TNS_DATA_TYPE_VARCHAR): str,
    (TNS_DATA_TYPE_ROWID, TNS_DATA_TYPE_CHAR): str,
    (TNS_DATA_TYPE_ROWID, TNS_DATA_TYPE_LONG): str,
    (TNS_DATA_TYPE_INTERVAL_DS, TNS_DATA_TYPE_VARCHAR): str,
    (TNS_DATA_TYPE_INTERVAL_DS, TNS_DATA_TYPE_CHAR): str,
    (TNS_DATA_TYPE_INTERVAL_DS, TNS_DATA_TYPE_LONG): str,
    (TNS_DATA_TYPE_BINARY_INTEGER, TNS_DATA_TYPE_VARCHAR): str,
    (TNS_DATA_TYPE_BINARY_INTEGER, TNS_DATA_TYPE_CHAR): str,
    (TNS_DATA_TYPE_BINARY_INTEGER, TNS_DATA_TYPE_LONG): str,
    (TNS_DATA_TYPE_TIMESTAMP, TNS_DATA_TYPE_DATE): _tstamp_to_date,
    (TNS_DATA_TYPE_TIMESTAMP_TZ, TNS_DATA_TYPE_DATE): _tstamp_to_date,
    (TNS_DATA_TYPE_TIMESTAMP_LTZ, TNS_DATA_TYPE_DATE): _tstamp_to_date,
    (TNS_DATA_TYPE_NUMBER, TNS_DATA_TYPE_BINARY_DOUBLE): NUM_TYPE_FLOAT,
    (TNS_DATA_TYPE_BINARY_FLOAT, TNS_DATA_TYPE_BINARY_DOUBLE): float,
    (TNS_DATA_TYPE_CHAR, TNS_DATA_TYPE_BINARY_DOUBLE): float,
    (TNS_DATA_TYPE_VARCHAR, TNS_DATA_TYPE_BINARY_DOUBLE): float,
    (TNS_DATA_TYPE_LONG, TNS_DATA_TYPE_BINARY_DOUBLE): float,
    (TNS_DATA_TYPE_NUMBER, TNS_DATA_TYPE_BINARY_FLOAT): NUM_TYPE_FLOAT,
    (TNS_DATA_TYPE_BINARY_DOUBLE, TNS_DATA_TYPE_BINARY_FLOAT): float,
    (TNS_DATA_TYPE_CHAR, TNS_DATA_TYPE_BINARY_FLOAT): float,
    (TNS_DATA_TYPE_VARCHAR, TNS_DATA_TYPE_BINARY_FLOAT): float,
    (TNS_DATA_TYPE_LONG, TNS_DATA_TYPE_BINARY_FLOAT): float,
    (TNS_DATA_TYPE_BINARY_FLOAT, TNS_DATA_TYPE_NUMBER): float,
    (TNS_DATA_TYPE_BINARY_DOUBLE, TNS_DATA_TYPE_NUMBER): float,
    (TNS_DATA_TYPE_BLOB, TNS_DATA_TYPE_LONG_RAW): TNS_DATA_TYPE_LONG_RAW,
    (TNS_DATA_TYPE_BLOB, TNS_DATA_TYPE_RAW): TNS_DATA_TYPE_LONG_RAW,
    (TNS_DATA_TYPE_CLOB, TNS_DATA_TYPE_CHAR): TNS_DATA_TYPE_LONG,
    (TNS_DATA_TYPE_CLOB, TNS_DATA_TYPE_VARCHAR): TNS_DATA_TYPE_LONG,
    (TNS_DATA_TYPE_CLOB, TNS_DATA_TYPE_LONG): TNS_DATA_TYPE_LONG,
    (TNS_DATA_TYPE_JSON, TNS_DATA_TYPE_VARCHAR): TNS_DATA_TYPE_LONG,
    (TNS_DATA_TYPE_JSON, TNS_DATA_TYPE_CHAR): TNS_DATA_TYPE_LONG,
    (TNS_DATA_TYPE_JSON, TNS_DATA_TYPE_RAW): TNS_DATA_TYPE_LONG_RAW,
    (TNS_DATA_TYPE_TIMESTAMP_TZ, TNS_DATA_TYPE_TIMESTAMP_LTZ): None,
    (TNS_DATA_TYPE_TIMESTAMP_TZ, TNS_DATA_TYPE_TIMESTAMP): None,
    (TNS_DATA_TYPE_TIMESTAMP_LTZ, TNS_DATA_TYPE_TIMESTAMP_TZ): None,
    (TNS_DATA_TYPE_TIMESTAMP_LTZ, TNS_DATA_TYPE_TIMESTAMP): None,
    (TNS_DATA_TYPE_TIMESTAMP, TNS_DATA_TYPE_TIMESTAMP_LTZ): None,
    (TNS_DATA_TYPE_TIMESTAMP, TNS_DATA_TYPE_TIMESTAMP_TZ): None,
    (TNS_DATA_TYPE_DATE, TNS_DATA_TYPE_TIMESTAMP_LTZ): None,
    (TNS_DATA_TYPE_DATE, TNS_DATA_TYPE_TIMESTAMP): None,
    (TNS_DATA_TYPE_DATE, TNS_DATA_TYPE_TIMESTAMP_TZ): None,
    (TNS_DATA_TYPE_CHAR, TNS_DATA_TYPE_VARCHAR): None,
    (TNS_DATA_TYPE_VARCHAR, TNS_DATA_TYPE_CHAR): None,
    (TNS_DATA_TYPE_LONG, TNS_DATA_TYPE_VARCHAR): None,
    (TNS_DATA_TYPE_LONG, TNS_DATA_TYPE_CHAR): None,
    (TNS_DATA_TYPE_VARCHAR, TNS_DATA_TYPE_LONG): None,
    (TNS_DATA_TYPE_CHAR, TNS_DATA_TYPE_LONG): None,
}

cdef object _to_binary_int(object fetch_value):
    return int(decimal.Decimal(fetch_value))

cdef object _tstamp_to_date(object fetch_value):
    return fetch_value.replace(microsecond=0)

cdef int conversion_helper(ThinVarImpl output_var, FetchInfo fetch_info,
                           bint *requires_define) except -1:
    cdef:
        uint8_t fetch_ora_type_num, output_ora_type_num, csfrm
        object key, value

    fetch_ora_type_num = fetch_info._dbtype._ora_type_num
    output_ora_type_num = output_var.dbtype._ora_type_num

    key = (fetch_ora_type_num, output_ora_type_num)
    try:
        value = converter_dict[key]
        if isinstance(value, int):
            if fetch_ora_type_num == TNS_DATA_TYPE_NUMBER:
                output_var._preferred_num_type = value
            else:
                requires_define[0] = True
                csfrm = output_var.dbtype._csfrm
                fetch_info._dbtype = DbType._from_ora_type_and_csfrm(value,
                                                                     csfrm)
        else:
            output_var._conv_func = value
    except:
        errors._raise_err(errors.ERR_INCONSISTENT_DATATYPES,
                          input_type=fetch_info._dbtype.name,
                          output_type=output_var.dbtype.name)
