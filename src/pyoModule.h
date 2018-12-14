//-----------------------------------------------------------------------------
// Copyright (c) 2018, Oracle and/or its affiliates. All rights reserved.
//
// Licensed under BSD license (see LICENSE.txt).
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// pyoModule.h
//   Include file for all oracledb source files.
//-----------------------------------------------------------------------------

#include <Python.h>
#include <structmember.h>
#include <dpi.h>

// define macro for driver name
#define PYO_DRIVER_NAME                 "py-oracledb : 0.0.1"

// define macro for clearing buffers
#define pyoBuffer_clear(buf)            Py_CLEAR((buf)->obj)


//-----------------------------------------------------------------------------
// Forward Declarations
//-----------------------------------------------------------------------------

typedef struct pyoBuffer pyoBuffer;
typedef struct pyoConnection pyoConnection;
typedef struct pyoCursor pyoCursor;
typedef struct pyoError pyoError;
typedef struct pyoLob pyoLob;
typedef struct pyoObject pyoObject;
typedef struct pyoObjectAttr pyoObjectAttr;
typedef struct pyoObjectType pyoObjectType;
typedef struct pyoSessionPool pyoSessionPool;
typedef struct pyoVar pyoVar;
typedef struct pyoVarType pyoVarType;


//-----------------------------------------------------------------------------
// Globals
//-----------------------------------------------------------------------------

// exception objects
extern PyObject *pyoWarningException;
extern PyObject *pyoErrorException;
extern PyObject *pyoInterfaceErrorException;
extern PyObject *pyoDatabaseErrorException;
extern PyObject *pyoDataErrorException;
extern PyObject *pyoOperationalErrorException;
extern PyObject *pyoIntegrityErrorException;
extern PyObject *pyoInternalErrorException;
extern PyObject *pyoProgrammingErrorException;
extern PyObject *pyoNotSupportedErrorException;

// type objects
extern PyTypeObject pyoPyTypeBfileVar;
extern PyTypeObject pyoPyTypeBinaryVar;
extern PyTypeObject pyoPyTypeBlobVar;
extern PyTypeObject pyoPyTypeBooleanVar;
extern PyTypeObject pyoPyTypeClobVar;
extern PyTypeObject pyoPyTypeConnection;
extern PyTypeObject pyoPyTypeCursor;
extern PyTypeObject pyoPyTypeCursorVar;
extern PyTypeObject pyoPyTypeDateTimeVar;
extern PyTypeObject pyoPyTypeDeqOptions;
extern PyTypeObject pyoPyTypeEnqOptions;
extern PyTypeObject pyoPyTypeError;
extern PyTypeObject pyoPyTypeFixedCharVar;
extern PyTypeObject pyoPyTypeFixedNcharVar;
extern PyTypeObject pyoPyTypeFuture;
extern PyTypeObject pyoPyTypeIntervalVar;
extern PyTypeObject pyoPyTypeLob;
extern PyTypeObject pyoPyTypeLongBinaryVar;
extern PyTypeObject pyoPyTypeLongStringVar;
extern PyTypeObject pyoPyTypeMsgProps;
extern PyTypeObject pyoPyTypeMessage;
extern PyTypeObject pyoPyTypeMessageQuery;
extern PyTypeObject pyoPyTypeMessageRow;
extern PyTypeObject pyoPyTypeMessageTable;
extern PyTypeObject pyoPyTypeNativeFloatVar;
extern PyTypeObject pyoPyTypeNativeIntVar;
extern PyTypeObject pyoPyTypeNcharVar;
extern PyTypeObject pyoPyTypeNclobVar;
extern PyTypeObject pyoPyTypeNumberVar;
extern PyTypeObject pyoPyTypeObject;
extern PyTypeObject pyoPyTypeObjectAttr;
extern PyTypeObject pyoPyTypeObjectType;
extern PyTypeObject pyoPyTypeObjectVar;
extern PyTypeObject pyoPyTypeRowidVar;
extern PyTypeObject pyoPyTypeSessionPool;
extern PyTypeObject pyoPyTypeSodaCollection;
extern PyTypeObject pyoPyTypeSodaDatabase;
extern PyTypeObject pyoPyTypeSodaDoc;
extern PyTypeObject pyoPyTypeSodaDocCursor;
extern PyTypeObject pyoPyTypeSodaOperation;
extern PyTypeObject pyoPyTypeStringVar;
extern PyTypeObject pyoPyTypeSubscr;
extern PyTypeObject pyoPyTypeTimestampVar;

// datetime types
extern PyTypeObject *pyoPyTypeDate;
extern PyTypeObject *pyoPyTypeDateTime;

// JSON dump and load functions for use with SODA
extern PyObject *pyoJsonDumpFunction;
extern PyObject *pyoJsonLoadFunction;

// ODPI-C context and version information
extern dpiContext *pyoDpiContext;
extern dpiVersionInfo pyoClientVersionInfo;


//-----------------------------------------------------------------------------
// Transforms
//-----------------------------------------------------------------------------

typedef enum {
    PYO_TRANSFORM_NONE = 0,
    PYO_TRANSFORM_BINARY,
    PYO_TRANSFORM_BFILE,
    PYO_TRANSFORM_BLOB,
    PYO_TRANSFORM_BOOLEAN,
    PYO_TRANSFORM_CLOB,
    PYO_TRANSFORM_CURSOR,
    PYO_TRANSFORM_DATE,
    PYO_TRANSFORM_DATETIME,
    PYO_TRANSFORM_DECIMAL,
    PYO_TRANSFORM_FIXED_CHAR,
    PYO_TRANSFORM_FIXED_NCHAR,
    PYO_TRANSFORM_FLOAT,
    PYO_TRANSFORM_INT,
    PYO_TRANSFORM_LONG_BINARY,
    PYO_TRANSFORM_LONG_STRING,
    PYO_TRANSFORM_NATIVE_DOUBLE,
    PYO_TRANSFORM_NATIVE_FLOAT,
    PYO_TRANSFORM_NATIVE_INT,
    PYO_TRANSFORM_NCLOB,
    PYO_TRANSFORM_NSTRING,
    PYO_TRANSFORM_OBJECT,
    PYO_TRANSFORM_ROWID,
    PYO_TRANSFORM_STRING,
    PYO_TRANSFORM_TIMEDELTA,
    PYO_TRANSFORM_TIMESTAMP,
    PYO_TRANSFORM_TIMESTAMP_LTZ,
    PYO_TRANSFORM_UNSUPPORTED
} pyoTransformNum;


//-----------------------------------------------------------------------------
// Structures
//-----------------------------------------------------------------------------

struct pyoBuffer {
    const char *ptr;
    uint32_t numCharacters;
    uint32_t size;
    PyObject *obj;
};

struct pyoConnection {
    PyObject_HEAD
    dpiConn *handle;
    pyoSessionPool *sessionPool;
    PyObject *inputTypeHandler;
    PyObject *outputTypeHandler;
    PyObject *username;
    PyObject *dsn;
    PyObject *version;
    PyObject *tag;
    dpiEncodingInfo encodingInfo;
    int autocommit;
    int tagFound;
};

struct pyoCursor {
    PyObject_HEAD
    dpiStmt *handle;
    dpiStmtInfo stmtInfo;
    pyoConnection *connection;
    PyObject *statement;
    PyObject *statementTag;
    PyObject *bindVariables;
    PyObject *fetchVariables;
    PyObject *rowFactory;
    PyObject *inputTypeHandler;
    PyObject *outputTypeHandler;
    uint32_t arraySize;
    uint32_t bindArraySize;
    uint32_t fetchArraySize;
    int setInputSizes;
    uint64_t rowCount;
    uint32_t fetchBufferRowIndex;
    uint32_t numRowsInFetchBuffer;
    int moreRowsToFetch;
    int isScrollable;
    int fixupRefCursor;
    int isOpen;
};

struct pyoError {
    PyObject_HEAD
    long code;
    unsigned offset;
    PyObject *message;
    PyObject *context;
    char isRecoverable;
};

struct pyoLob {
    PyObject_HEAD
    pyoConnection *connection;
    dpiOracleTypeNum oracleTypeNum;
    dpiLob *handle;
};

struct pyoObject {
    PyObject_HEAD
    pyoObjectType *objectType;
    dpiObject *handle;
};

struct pyoObjectAttr {
    PyObject_HEAD
    PyObject *name;
    dpiObjectAttr *handle;
    dpiOracleTypeNum oracleTypeNum;
    pyoTransformNum transformNum;
    pyoObjectType *type;
};

struct pyoObjectType {
    PyObject_HEAD
    dpiObjectType *handle;
    PyObject *schema;
    PyObject *name;
    PyObject *attributes;
    PyObject *attributesByName;
    pyoConnection *connection;
    dpiOracleTypeNum elementOracleTypeNum;
    pyoTransformNum elementTransformNum;
    PyObject *elementType;
    char isCollection;
};

struct pyoSessionPool {
    PyObject_HEAD
    dpiPool *handle;
    uint32_t minSessions;
    uint32_t maxSessions;
    uint32_t sessionIncrement;
    uint32_t cacheSize;
    dpiEncodingInfo encodingInfo;
    int homogeneous;
    int externalAuth;
    PyObject *username;
    PyObject *dsn;
    PyObject *name;
    PyTypeObject *connectionType;
};

struct pyoVar {
    PyObject_HEAD
    dpiVar *handle;
    dpiData *data;
    pyoConnection *connection;
    PyObject *inConverter;
    PyObject *outConverter;
    pyoObjectType *objectType;
    const char *encodingErrors;
    uint32_t allocatedElements;
    uint32_t size;
    uint32_t bufferSize;
    int isArray;
    int isValueSet;
    int getReturnedData;
    pyoVarType *type;
};

struct pyoVarType {
    pyoTransformNum transformNum;
    PyTypeObject *pythonType;
    uint32_t size;
};


//-----------------------------------------------------------------------------
// Functions
//-----------------------------------------------------------------------------

int pyoBuffer_fromObject(pyoBuffer *buf, PyObject *obj, const char *encoding);
void pyoBuffer_init(pyoBuffer *buf);

pyoError *pyoError_newFromInfo(dpiErrorInfo *errorInfo);
int pyoError_raiseAndReturnInt(void);
PyObject *pyoError_raiseAndReturnNull(void);
int pyoError_raiseFromInfo(dpiErrorInfo *errorInfo);
PyObject *pyoError_raiseFromString(PyObject *exceptionType,
        const char *message);

PyObject *pyoLob_new(pyoConnection *connection, dpiOracleTypeNum oracleTypeNum,
        dpiLob *handle);

PyObject *pyoObject_new(pyoObjectType *objectType, dpiObject *handle);

int pyoTransform_fromPython(pyoTransformNum transformNum, PyObject *pyValue,
        dpiDataBuffer *dbValue, pyoBuffer *buffer, const char *encoding,
        const char *nencoding, pyoVar *var, uint32_t arrayPos);
pyoTransformNum pyoTransform_getNumFromDataTypeInfo(dpiDataTypeInfo *info);
pyoTransformNum pyoTransform_getNumFromType(PyTypeObject *type);
pyoTransformNum pyoTransform_getNumFromValue(PyObject *value, int plsql);
void pyoTransform_getTypeInfo(pyoTransformNum transformNum,
        dpiOracleTypeNum *oracleTypeNum, dpiNativeTypeNum *nativeTypeNum);
int pyoTransform_init(void);
PyObject *pyoTransform_toPython(pyoTransformNum transformNum,
        pyoConnection *connection, pyoObjectType *objType,
        dpiDataBuffer *dbValue, const char *encodingErrors);

PyObject *pyoUtils_formatString(const char *format, PyObject *args);
const char *pyoUtils_getAdjustedEncoding(const char *encoding);
int pyoUtils_getModuleAndName(PyTypeObject *type, PyObject **module,
        PyObject **name);
int pyoUtils_initializeDPI(void);

