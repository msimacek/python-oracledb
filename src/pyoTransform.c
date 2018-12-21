//-----------------------------------------------------------------------------
// Copyright (c) 2018, Oracle and/or its affiliates. All rights reserved.
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// pyoTransform.c
//   Defines routines used to transform Python objects to database values and
// database values to Python objects.
//-----------------------------------------------------------------------------

#include "pyoModule.h"
#include "datetime.h"

// PyPy compatibility
#ifndef PyDateTime_DELTA_GET_DAYS
#define PyDateTime_DELTA_GET_DAYS(x) ((x)->days)
#endif

#ifndef PyDateTime_DELTA_GET_SECONDS
#define PyDateTime_DELTA_GET_SECONDS(x) ((x)->seconds)
#endif

#ifndef PyDateTime_DELTA_GET_MICROSECONDS
#define PyDateTime_DELTA_GET_MICROSECONDS(x) ((x)->microseconds)
#endif

//-----------------------------------------------------------------------------
// Types
//-----------------------------------------------------------------------------
typedef struct {
    pyoTransformNum transformNum;
    dpiOracleTypeNum oracleTypeNum;
    dpiNativeTypeNum nativeTypeNum;
} pyoTransform;


//-----------------------------------------------------------------------------
// Globals
//-----------------------------------------------------------------------------
PyTypeObject *pyoPyTypeDate;
PyTypeObject *pyoPyTypeDateTime;
static PyTypeObject *pyoPyTypeDecimal;
static const pyoTransform pyoAllTransforms[] = {
    {
        PYO_TRANSFORM_NONE,
        DPI_ORACLE_TYPE_VARCHAR,
        DPI_NATIVE_TYPE_BYTES
    },
    {
        PYO_TRANSFORM_BINARY,
        DPI_ORACLE_TYPE_RAW,
        DPI_NATIVE_TYPE_BYTES
    },
    {
        PYO_TRANSFORM_BFILE,
        DPI_ORACLE_TYPE_BFILE,
        DPI_NATIVE_TYPE_LOB
    },
    {
        PYO_TRANSFORM_BLOB,
        DPI_ORACLE_TYPE_BLOB,
        DPI_NATIVE_TYPE_LOB
    },
    {
        PYO_TRANSFORM_BOOLEAN,
        DPI_ORACLE_TYPE_BOOLEAN,
        DPI_NATIVE_TYPE_BOOLEAN
    },
    {
        PYO_TRANSFORM_CLOB,
        DPI_ORACLE_TYPE_CLOB,
        DPI_NATIVE_TYPE_LOB
    },
    {
        PYO_TRANSFORM_CURSOR,
        DPI_ORACLE_TYPE_STMT,
        DPI_NATIVE_TYPE_STMT
    },
    {
        PYO_TRANSFORM_DATE,
        DPI_ORACLE_TYPE_DATE,
        DPI_NATIVE_TYPE_TIMESTAMP
    },
    {
        PYO_TRANSFORM_DATETIME,
        DPI_ORACLE_TYPE_DATE,
        DPI_NATIVE_TYPE_TIMESTAMP
    },
    {
        PYO_TRANSFORM_DECIMAL,
        DPI_ORACLE_TYPE_NUMBER,
        DPI_NATIVE_TYPE_BYTES
    },
    {
        PYO_TRANSFORM_FIXED_CHAR,
        DPI_ORACLE_TYPE_CHAR,
        DPI_NATIVE_TYPE_BYTES
    },
    {
        PYO_TRANSFORM_FIXED_NCHAR,
        DPI_ORACLE_TYPE_NCHAR,
        DPI_NATIVE_TYPE_BYTES
    },
    {
        PYO_TRANSFORM_FLOAT,
        DPI_ORACLE_TYPE_NUMBER,
        DPI_NATIVE_TYPE_BYTES
    },
    {
        PYO_TRANSFORM_INT,
        DPI_ORACLE_TYPE_NUMBER,
        DPI_NATIVE_TYPE_BYTES
    },
    {
        PYO_TRANSFORM_LONG_BINARY,
        DPI_ORACLE_TYPE_LONG_RAW,
        DPI_NATIVE_TYPE_BYTES
    },
    {
        PYO_TRANSFORM_LONG_STRING,
        DPI_ORACLE_TYPE_LONG_VARCHAR,
        DPI_NATIVE_TYPE_BYTES
    },
    {
        PYO_TRANSFORM_NATIVE_DOUBLE,
        DPI_ORACLE_TYPE_NATIVE_DOUBLE,
        DPI_NATIVE_TYPE_DOUBLE
    },
    {
        PYO_TRANSFORM_NATIVE_FLOAT,
        DPI_ORACLE_TYPE_NATIVE_FLOAT,
        DPI_NATIVE_TYPE_FLOAT
    },
    {
        PYO_TRANSFORM_NATIVE_INT,
        DPI_ORACLE_TYPE_NATIVE_INT,
        DPI_NATIVE_TYPE_INT64
    },
    {
        PYO_TRANSFORM_NCLOB,
        DPI_ORACLE_TYPE_NCLOB,
        DPI_NATIVE_TYPE_LOB
    },
    {
        PYO_TRANSFORM_NSTRING,
        DPI_ORACLE_TYPE_NVARCHAR,
        DPI_NATIVE_TYPE_BYTES
    },
    {
        PYO_TRANSFORM_OBJECT,
        DPI_ORACLE_TYPE_OBJECT,
        DPI_NATIVE_TYPE_OBJECT
    },
    {
        PYO_TRANSFORM_ROWID,
        DPI_ORACLE_TYPE_ROWID,
        DPI_NATIVE_TYPE_ROWID
    },
    {
        PYO_TRANSFORM_STRING,
        DPI_ORACLE_TYPE_VARCHAR,
        DPI_NATIVE_TYPE_BYTES
    },
    {
        PYO_TRANSFORM_TIMEDELTA,
        DPI_ORACLE_TYPE_INTERVAL_DS,
        DPI_NATIVE_TYPE_INTERVAL_DS
    },
    {
        PYO_TRANSFORM_TIMESTAMP,
        DPI_ORACLE_TYPE_TIMESTAMP,
        DPI_NATIVE_TYPE_TIMESTAMP
    },
    {
        PYO_TRANSFORM_TIMESTAMP_LTZ,
        DPI_ORACLE_TYPE_TIMESTAMP_LTZ,
        DPI_NATIVE_TYPE_TIMESTAMP
    }
};


//-----------------------------------------------------------------------------
// pyoTransform_fromPython()
//   Transforms a Python object into its corresponding database value.
//-----------------------------------------------------------------------------
int pyoTransform_fromPython(pyoTransformNum transformNum, PyObject *pyValue,
        dpiDataBuffer *dbValue, pyoBuffer *buffer, pyoVar *var,
        uint32_t arrayPos)
{
    dpiIntervalDS *interval;
    PyDateTime_Delta *delta;
    int32_t deltaSeconds;
    PyObject *textValue;
    pyoObject *obj;
    pyoLob *lob;
    int status;

    switch (transformNum) {
        case PYO_TRANSFORM_BOOLEAN:
            dbValue->asBoolean = (pyValue == Py_True);
            return 0;
        case PYO_TRANSFORM_BINARY:
        case PYO_TRANSFORM_FIXED_CHAR:
        case PYO_TRANSFORM_LONG_BINARY:
        case PYO_TRANSFORM_LONG_STRING:
        case PYO_TRANSFORM_STRING:
            if (pyoBuffer_fromObject(buffer, pyValue) < 0)
                return -1;
            dbValue->asBytes.ptr = (char*) buffer->ptr;
            dbValue->asBytes.length = buffer->size;
            return 0;
        case PYO_TRANSFORM_FIXED_NCHAR:
        case PYO_TRANSFORM_NSTRING:
            if (pyoBuffer_fromObject(buffer, pyValue) < 0)
                return -1;
            dbValue->asBytes.ptr = (char*) buffer->ptr;
            dbValue->asBytes.length = buffer->size;
            return 0;
        case PYO_TRANSFORM_BLOB:
        case PYO_TRANSFORM_CLOB:
        case PYO_TRANSFORM_NCLOB:
            if (Py_TYPE(pyValue) == &pyoPyTypeLob) {
                lob = (pyoLob*) pyValue;
                if (var) {
                    if (dpiVar_setFromLob(var->handle, arrayPos,
                            lob->handle) < 0)
                        return pyoError_raiseAndReturnInt();
                } else dbValue->asLOB = lob->handle;
                return 0;
            }
            if (pyoBuffer_fromObject(buffer, pyValue) < 0)
                return -1;
            Py_BEGIN_ALLOW_THREADS
            status = dpiLob_setFromBytes(dbValue->asLOB, buffer->ptr,
                    buffer->size);
            Py_END_ALLOW_THREADS
            return status;
        case PYO_TRANSFORM_NATIVE_INT:
            if (PyBool_Check(pyValue)) {
                dbValue->asInt64 = (pyValue == Py_True);
                return 0;
            }
            dbValue->asInt64 = PyLong_AsLong(pyValue);
            if (PyErr_Occurred())
                return -1;
            return 0;
        case PYO_TRANSFORM_INT:
        case PYO_TRANSFORM_DECIMAL:
        case PYO_TRANSFORM_FLOAT:
            if (!PyFloat_Check(pyValue) &&
                    !PyLong_Check(pyValue) &&
                    !PyObject_TypeCheck(pyValue, pyoPyTypeDecimal)) {
                PyErr_SetString(PyExc_TypeError, "expecting number");
                return -1;
            }
            textValue = PyObject_Str(pyValue);
            if (!textValue)
                return -1;
            status = pyoBuffer_fromObject(buffer, textValue);
            Py_DECREF(textValue);
            if (status < 0)
                return -1;
            dbValue->asBytes.ptr = (char*) buffer->ptr;
            dbValue->asBytes.length = buffer->size;
            return 0;
        case PYO_TRANSFORM_NATIVE_DOUBLE:
        case PYO_TRANSFORM_NATIVE_FLOAT:
            if (!PyFloat_Check(pyValue) &&
                    !PyObject_TypeCheck(pyValue, pyoPyTypeDecimal) &&
                    !PyLong_Check(pyValue)) {
                PyErr_SetString(PyExc_TypeError, "expecting float");
                return -1;
            }
            if (transformNum == PYO_TRANSFORM_NATIVE_FLOAT)
                dbValue->asFloat = (float) PyFloat_AsDouble(pyValue);
            else dbValue->asDouble = PyFloat_AsDouble(pyValue);
            if (PyErr_Occurred())
                return -1;
            return 0;
        case PYO_TRANSFORM_OBJECT:
            if (Py_TYPE(pyValue) != &pyoPyTypeObject) {
                PyErr_SetString(PyExc_TypeError, "expecting cx_Oracle.Object");
                return -1;
            }
            obj = (pyoObject*) pyValue;
            if (var) {
                if (dpiVar_setFromObject(var->handle, arrayPos,
                        obj->handle) < 0)
                    return pyoError_raiseAndReturnInt();
            } else dbValue->asObject = obj->handle;
            return 0;
        case PYO_TRANSFORM_DATE:
        case PYO_TRANSFORM_DATETIME:
        case PYO_TRANSFORM_TIMESTAMP:
        case PYO_TRANSFORM_TIMESTAMP_LTZ:
            if (PyDateTime_Check(pyValue)) {
                memset(&dbValue->asTimestamp, 0, sizeof(dbValue->asTimestamp));
                dbValue->asTimestamp.year = PyDateTime_GET_YEAR(pyValue);
                dbValue->asTimestamp.month = PyDateTime_GET_MONTH(pyValue);
                dbValue->asTimestamp.day = PyDateTime_GET_DAY(pyValue);
                dbValue->asTimestamp.hour = PyDateTime_DATE_GET_HOUR(pyValue);
                dbValue->asTimestamp.minute =
                        PyDateTime_DATE_GET_MINUTE(pyValue);
                dbValue->asTimestamp.second =
                        PyDateTime_DATE_GET_SECOND(pyValue);
                dbValue->asTimestamp.fsecond =
                        PyDateTime_DATE_GET_MICROSECOND(pyValue) * 1000;
            } else if (PyDate_Check(pyValue)) {
                memset(&dbValue->asTimestamp, 0, sizeof(dbValue->asTimestamp));
                dbValue->asTimestamp.year = PyDateTime_GET_YEAR(pyValue);
                dbValue->asTimestamp.month = PyDateTime_GET_MONTH(pyValue);
                dbValue->asTimestamp.day = PyDateTime_GET_DAY(pyValue);
            } else {
                PyErr_SetString(PyExc_TypeError, "expecting date or datetime");
                return -1;
            }
            return 0;
        case PYO_TRANSFORM_TIMEDELTA:
            if (!PyDelta_Check(pyValue)) {
                PyErr_SetString(PyExc_TypeError, "expecting timedelta");
                return -1;
            }
            delta = (PyDateTime_Delta*) pyValue;
            interval = &dbValue->asIntervalDS;
            deltaSeconds = PyDateTime_DELTA_GET_SECONDS(delta);
            interval->days = PyDateTime_DELTA_GET_DAYS(delta);
            interval->hours = deltaSeconds / 3600;
            interval->seconds = deltaSeconds % 3600;
            interval->minutes = interval->seconds / 60;
            interval->seconds = interval->seconds % 60;
            interval->fseconds =
                    PyDateTime_DELTA_GET_MICROSECONDS(delta) * 1000;
            return 0;
        default:
            break;
    }

    pyoError_raiseFromString(pyoNotSupportedErrorException,
            "Python value cannot be converted to a database value");
    return -1;
}


//-----------------------------------------------------------------------------
// pyoTransform_getNumFromDataTypeInfo()
//   Get the default transformation to use for the specified data type.
//-----------------------------------------------------------------------------
pyoTransformNum pyoTransform_getNumFromDataTypeInfo(dpiDataTypeInfo *info)
{
    switch (info->oracleTypeNum) {
        case DPI_ORACLE_TYPE_VARCHAR:
            return PYO_TRANSFORM_STRING;
        case DPI_ORACLE_TYPE_NVARCHAR:
            return PYO_TRANSFORM_NSTRING;
        case DPI_ORACLE_TYPE_CHAR:
            return PYO_TRANSFORM_FIXED_CHAR;
        case DPI_ORACLE_TYPE_NCHAR:
            return PYO_TRANSFORM_FIXED_NCHAR;
        case DPI_ORACLE_TYPE_ROWID:
            return PYO_TRANSFORM_ROWID;
        case DPI_ORACLE_TYPE_RAW:
            return PYO_TRANSFORM_BINARY;
        case DPI_ORACLE_TYPE_NATIVE_DOUBLE:
            return PYO_TRANSFORM_NATIVE_DOUBLE;
        case DPI_ORACLE_TYPE_NATIVE_FLOAT:
            return PYO_TRANSFORM_NATIVE_FLOAT;
        case DPI_ORACLE_TYPE_NUMBER:
            if (info->scale == 0 ||
                    (info->scale == -127 && info->precision == 0))
                return PYO_TRANSFORM_INT;
            return PYO_TRANSFORM_FLOAT;
        case DPI_ORACLE_TYPE_NATIVE_INT:
            return PYO_TRANSFORM_NATIVE_INT;
        case DPI_ORACLE_TYPE_DATE:
            return PYO_TRANSFORM_DATETIME;
        case DPI_ORACLE_TYPE_TIMESTAMP:
            return PYO_TRANSFORM_TIMESTAMP;
        case DPI_ORACLE_TYPE_TIMESTAMP_TZ:
        case DPI_ORACLE_TYPE_TIMESTAMP_LTZ:
            return PYO_TRANSFORM_TIMESTAMP_LTZ;
        case DPI_ORACLE_TYPE_INTERVAL_DS:
            return PYO_TRANSFORM_TIMEDELTA;
        case DPI_ORACLE_TYPE_CLOB:
            return PYO_TRANSFORM_CLOB;
        case DPI_ORACLE_TYPE_NCLOB:
            return PYO_TRANSFORM_NCLOB;
        case DPI_ORACLE_TYPE_BLOB:
            return PYO_TRANSFORM_BLOB;
        case DPI_ORACLE_TYPE_BFILE:
            return PYO_TRANSFORM_BFILE;
        case DPI_ORACLE_TYPE_STMT: 
            return PYO_TRANSFORM_CURSOR;
        case DPI_ORACLE_TYPE_OBJECT:
            return PYO_TRANSFORM_OBJECT;
        case DPI_ORACLE_TYPE_LONG_VARCHAR:
            return PYO_TRANSFORM_LONG_STRING;
        case DPI_ORACLE_TYPE_LONG_RAW:
            return PYO_TRANSFORM_LONG_BINARY;
        case DPI_ORACLE_TYPE_BOOLEAN:
            return PYO_TRANSFORM_BOOLEAN;
        default:
            break;
    }
    return PYO_TRANSFORM_UNSUPPORTED;
}


//-----------------------------------------------------------------------------
// pyoTransform_getNumFromType()
//   Get the appropriate transformation to use for the specified Python type.
//-----------------------------------------------------------------------------
pyoTransformNum pyoTransform_getNumFromType(PyTypeObject *type)
{
    if (type == &PyUnicode_Type)
        return PYO_TRANSFORM_STRING;
    if (type == &pyoPyTypeStringVar)
        return PYO_TRANSFORM_STRING;
    if (type == &pyoPyTypeFixedCharVar)
        return PYO_TRANSFORM_FIXED_CHAR;
    if (type == &pyoPyTypeNcharVar)
        return PYO_TRANSFORM_NSTRING;
    if (type == &pyoPyTypeFixedNcharVar)
        return PYO_TRANSFORM_FIXED_NCHAR;
    if (type == &pyoPyTypeRowidVar)
        return PYO_TRANSFORM_ROWID;
    if (type == &PyBytes_Type)
        return PYO_TRANSFORM_BINARY;
    if (type == &pyoPyTypeBinaryVar)
        return PYO_TRANSFORM_BINARY;
    if (type == &PyFloat_Type)
        return PYO_TRANSFORM_FLOAT;
    if (type == &PyLong_Type)
        return PYO_TRANSFORM_INT;
    if (type == pyoPyTypeDecimal)
        return PYO_TRANSFORM_DECIMAL;
    if (type == &pyoPyTypeNumberVar)
        return PYO_TRANSFORM_FLOAT;
    if (type == &pyoPyTypeNativeFloatVar)
        return PYO_TRANSFORM_NATIVE_DOUBLE;
    if (type == &pyoPyTypeNativeIntVar)
        return PYO_TRANSFORM_NATIVE_INT;
    if (type == &PyBool_Type)
        return PYO_TRANSFORM_BOOLEAN;
    if (type == &pyoPyTypeBooleanVar)
        return PYO_TRANSFORM_BOOLEAN;
    if (type == PyDateTimeAPI->DateType)
        return PYO_TRANSFORM_DATE;
    if (type == PyDateTimeAPI->DateTimeType)
        return PYO_TRANSFORM_DATETIME;
    if (type == &pyoPyTypeDateTimeVar)
        return PYO_TRANSFORM_DATETIME;
    if (type == &pyoPyTypeTimestampVar)
        return PYO_TRANSFORM_TIMESTAMP;
    if (type == PyDateTimeAPI->DeltaType)
        return PYO_TRANSFORM_TIMEDELTA;
    if (type == &pyoPyTypeIntervalVar)
        return PYO_TRANSFORM_TIMEDELTA;
    if (type == &pyoPyTypeObject)
        return PYO_TRANSFORM_OBJECT;
    if (type == &pyoPyTypeObjectVar)
        return PYO_TRANSFORM_OBJECT;
    if (type == &pyoPyTypeClobVar)
        return PYO_TRANSFORM_CLOB;
    if (type == &pyoPyTypeNclobVar)
        return PYO_TRANSFORM_NCLOB;
    if (type == &pyoPyTypeBlobVar)
        return PYO_TRANSFORM_BLOB;
    if (type == &pyoPyTypeBfileVar)
        return PYO_TRANSFORM_BFILE;
    if (type == &pyoPyTypeCursorVar)
        return PYO_TRANSFORM_CURSOR;
    if (type == &pyoPyTypeLongStringVar)
        return PYO_TRANSFORM_LONG_STRING;
    if (type == &pyoPyTypeLongBinaryVar)
        return PYO_TRANSFORM_LONG_BINARY;

    return PYO_TRANSFORM_UNSUPPORTED;
}


//-----------------------------------------------------------------------------
// pyoTransform_getNumFromValue()
//   Get the appropriate transformation to use for the specified Python object.
//-----------------------------------------------------------------------------
pyoTransformNum pyoTransform_getNumFromValue(PyObject *value, int plsql)
{
    pyoLob *lob;

    if (value == Py_None)
        return PYO_TRANSFORM_NONE;
    if (PyBool_Check(value)) {
        if (pyoClientVersionInfo.versionNum < 12 || !plsql)
            return PYO_TRANSFORM_NATIVE_INT;
        return PYO_TRANSFORM_BOOLEAN;
    }
    if (PyUnicode_Check(value))
        return PYO_TRANSFORM_STRING;
    if (PyBytes_Check(value))
        return PYO_TRANSFORM_BINARY;
    if (PyLong_Check(value))
        return PYO_TRANSFORM_INT;
    if (PyFloat_Check(value))
        return PYO_TRANSFORM_FLOAT;
    if (PyDateTime_Check(value))
        return PYO_TRANSFORM_DATETIME;
    if (PyDate_Check(value))
        return PYO_TRANSFORM_DATE;
    if (PyDelta_Check(value))
        return PYO_TRANSFORM_TIMEDELTA;
    if (PyObject_TypeCheck(value, &pyoPyTypeCursor))
        return PYO_TRANSFORM_CURSOR;
    if (PyObject_TypeCheck(value, pyoPyTypeDecimal))
        return PYO_TRANSFORM_DECIMAL;
    if (PyObject_TypeCheck(value, &pyoPyTypeObject))
        return PYO_TRANSFORM_OBJECT;
    if (PyObject_TypeCheck(value, &pyoPyTypeLob)) {
        lob = (pyoLob*) value;
        if (lob->oracleTypeNum == DPI_ORACLE_TYPE_CLOB)
            return PYO_TRANSFORM_CLOB;
        if (lob->oracleTypeNum == DPI_ORACLE_TYPE_NCLOB)
            return PYO_TRANSFORM_NCLOB;
        if (lob->oracleTypeNum == DPI_ORACLE_TYPE_BLOB)
            return PYO_TRANSFORM_BLOB;
        if (lob->oracleTypeNum == DPI_ORACLE_TYPE_BFILE)
            return PYO_TRANSFORM_BFILE;
    }
    return PYO_TRANSFORM_UNSUPPORTED;
}


//-----------------------------------------------------------------------------
// pyoTransform_getTypeInfo()
//   Get type information for the specified transform. The transform number is
// assumed to be a valid value at this point (not PYO_TRANSFORM_UNSUPPORTED).
//-----------------------------------------------------------------------------
void pyoTransform_getTypeInfo(pyoTransformNum transformNum,
        dpiOracleTypeNum *oracleTypeNum, dpiNativeTypeNum *nativeTypeNum)
{
    const pyoTransform *transform;

    transform = &pyoAllTransforms[transformNum];
    *oracleTypeNum = transform->oracleTypeNum;
    *nativeTypeNum = transform->nativeTypeNum;
}


//-----------------------------------------------------------------------------
// pyoTransform_init()
//   Import the necessary modules for performing transformations.
//-----------------------------------------------------------------------------
int pyoTransform_init(void)
{
    PyObject *module;

    // import the datetime module for datetime support
    PyDateTime_IMPORT;
    if (PyErr_Occurred())
        return -1;
    pyoPyTypeDate = PyDateTimeAPI->DateType;
    pyoPyTypeDateTime = PyDateTimeAPI->DateTimeType;

    // import the decimal module for decimal support
    module = PyImport_ImportModule("decimal");
    if (!module)
        return -1;
    pyoPyTypeDecimal =
            (PyTypeObject*) PyObject_GetAttrString(module, "Decimal");
    Py_DECREF(module);
    if (!pyoPyTypeDecimal)
        return -1;

    return 0;
}


//-----------------------------------------------------------------------------
// pyoTransform_toPython()
//   Transforms a database value into its corresponding Python object.
//-----------------------------------------------------------------------------
PyObject *pyoTransform_toPython(pyoTransformNum transformNum,
        pyoConnection *connection, pyoObjectType *objType,
        dpiDataBuffer *dbValue, const char *encodingErrors)
{
    const pyoTransform *transform;
    PyObject *stringObj, *result;
    dpiIntervalDS *intervalDS;
    dpiTimestamp *timestamp;
    uint32_t rowidLength;
    const char *rowid;
    pyoCursor *cursor;
    dpiBytes *bytes;
    int32_t seconds;

    transform = &pyoAllTransforms[transformNum];
    switch (transformNum) {
        case PYO_TRANSFORM_BINARY:
        case PYO_TRANSFORM_LONG_BINARY:
            bytes = &dbValue->asBytes;
            return PyBytes_FromStringAndSize(bytes->ptr, bytes->length);
        case PYO_TRANSFORM_BFILE:
        case PYO_TRANSFORM_BLOB:
        case PYO_TRANSFORM_CLOB:
        case PYO_TRANSFORM_NCLOB:
            return pyoLob_new(connection, transform->oracleTypeNum,
                    dbValue->asLOB);
        case PYO_TRANSFORM_BOOLEAN:
            if (dbValue->asBoolean)
                Py_RETURN_TRUE;
            Py_RETURN_FALSE;
        case PYO_TRANSFORM_CURSOR:
            cursor = (pyoCursor*) PyObject_CallMethod((PyObject*) connection,
                    "cursor", NULL);
            if (!cursor)
                return NULL;
            cursor->handle = dbValue->asStmt;
            dpiStmt_addRef(cursor->handle);
            cursor->fixupRefCursor = 1;
            return (PyObject*) cursor;
        case PYO_TRANSFORM_DATE:
            timestamp = &dbValue->asTimestamp;
            return PyDate_FromDate(timestamp->year, timestamp->month,
                    timestamp->day);
        case PYO_TRANSFORM_DATETIME:
        case PYO_TRANSFORM_TIMESTAMP:
        case PYO_TRANSFORM_TIMESTAMP_LTZ:
            timestamp = &dbValue->asTimestamp;
            return PyDateTime_FromDateAndTime(timestamp->year,
                    timestamp->month, timestamp->day, timestamp->hour,
                    timestamp->minute, timestamp->second,
                    timestamp->fsecond / 1000);
        case PYO_TRANSFORM_FIXED_NCHAR:
        case PYO_TRANSFORM_NSTRING:
            bytes = &dbValue->asBytes;
            return PyUnicode_Decode(bytes->ptr, bytes->length, bytes->encoding,
                    encodingErrors);
        case PYO_TRANSFORM_NATIVE_DOUBLE:
            return PyFloat_FromDouble(dbValue->asDouble);
        case PYO_TRANSFORM_NATIVE_FLOAT:
            return PyFloat_FromDouble(dbValue->asFloat);
        case PYO_TRANSFORM_NATIVE_INT:
            return PyLong_FromLongLong((long long) dbValue->asInt64);
        case PYO_TRANSFORM_DECIMAL:
        case PYO_TRANSFORM_INT:
        case PYO_TRANSFORM_FLOAT:
            bytes = &dbValue->asBytes;
            stringObj = PyUnicode_Decode(bytes->ptr, bytes->length,
                    bytes->encoding, encodingErrors);
            if (!stringObj)
                return NULL;
            if (transformNum == PYO_TRANSFORM_INT &&
                    memchr(bytes->ptr, '.', bytes->length) == NULL) {
                result = PyNumber_Long(stringObj);
                Py_DECREF(stringObj);
                return result;
            } else if (transformNum != PYO_TRANSFORM_DECIMAL &&
                    bytes->length <= 15) {
                result = PyNumber_Float(stringObj);
                Py_DECREF(stringObj);
                return result;
            }
            result = PyObject_CallFunctionObjArgs(
                    (PyObject*) pyoPyTypeDecimal, stringObj, NULL);
            Py_DECREF(stringObj);
            return result;
        case PYO_TRANSFORM_OBJECT:
            return pyoObject_new(objType, dbValue->asObject);
        case PYO_TRANSFORM_ROWID:
            if (dpiRowid_getStringValue(dbValue->asRowid, &rowid,
                    &rowidLength) < 0)
                return pyoError_raiseAndReturnNull();
            return PyUnicode_Decode(rowid, rowidLength, PYO_ENCODING, NULL);
        case PYO_TRANSFORM_FIXED_CHAR:
        case PYO_TRANSFORM_STRING:
        case PYO_TRANSFORM_LONG_STRING:
            bytes = &dbValue->asBytes;
            return PyUnicode_Decode(bytes->ptr, bytes->length, bytes->encoding,
                    encodingErrors);
        case PYO_TRANSFORM_TIMEDELTA:
            intervalDS = &dbValue->asIntervalDS; 
            seconds = intervalDS->hours * 60 * 60 + intervalDS->minutes * 60 +
                    intervalDS->seconds;
            return PyDelta_FromDSU(intervalDS->days, seconds,
                    intervalDS->fseconds / 1000);
        default:
            break;
    }

    return pyoError_raiseFromString(pyoNotSupportedErrorException,
            "Database value cannot be converted to a Python value");
}

