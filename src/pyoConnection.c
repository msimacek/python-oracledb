//-----------------------------------------------------------------------------
// Copyright (c) 2018, Oracle and/or its affiliates. All rights reserved.
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// pyoConnection.c
//   Definition of the Python type "Connection".
//-----------------------------------------------------------------------------

#include "pyoModule.h"

//-----------------------------------------------------------------------------
// forward declaration of functions for the Python type "Connection"
//-----------------------------------------------------------------------------
static void pyoConnection_free(pyoConnection*);
static PyObject *pyoConnection_new(PyTypeObject*, PyObject*, PyObject*);
static int pyoConnection_init(pyoConnection*, PyObject*, PyObject*);
static PyObject *pyoConnection_repr(pyoConnection*);

//-----------------------------------------------------------------------------
// declaration of methods for the Python type "Connection"
//-----------------------------------------------------------------------------
static PyMethodDef pyoMethods[] = {
    { NULL }
};


//-----------------------------------------------------------------------------
// declaration of static members for the Python type "Connection"
//-----------------------------------------------------------------------------
static PyMemberDef pyoStaticMembers[] = {
    { "username", T_OBJECT, offsetof(pyoConnection, username), READONLY },
    { "dsn", T_OBJECT, offsetof(pyoConnection, dsn), READONLY },
    { "autocommit", T_INT, offsetof(pyoConnection, autocommit), 0 },
    { NULL }
};


//-----------------------------------------------------------------------------
// declaration of dynamic members for the Python type "Connection"
//-----------------------------------------------------------------------------
static PyGetSetDef pyoDynamicMembers[] = {
    { NULL }
};


//-----------------------------------------------------------------------------
// declaration of the Python type "Connection"
//-----------------------------------------------------------------------------
PyTypeObject pyoPyTypeConnection = {
    PyVarObject_HEAD_INIT(NULL, 0)
    .tp_name = "oracledb.Connection",
    .tp_basicsize = sizeof(pyoConnection),
    .tp_dealloc = (destructor) pyoConnection_free,
    .tp_repr = (reprfunc) pyoConnection_repr,
    .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
    .tp_methods = pyoMethods,
    .tp_members = pyoStaticMembers,
    .tp_getset = pyoDynamicMembers,
    .tp_init = (initproc) pyoConnection_init,
    .tp_new = (newfunc) pyoConnection_new
};


//-----------------------------------------------------------------------------
// structure used to help in establishing a connection
//-----------------------------------------------------------------------------
typedef struct {
    const char *encoding;
    const char *nencoding;
    pyoBuffer userNameBuffer;
    pyoBuffer passwordBuffer;
    pyoBuffer newPasswordBuffer;
    pyoBuffer dsnBuffer;
    pyoBuffer connectionClassBuffer;
    pyoBuffer editionBuffer;
    pyoBuffer tagBuffer;
    uint32_t numAppContext;
    dpiAppContext *appContext;
    pyoBuffer *ctxNamespaceBuffers;
    pyoBuffer *ctxNameBuffers;
    pyoBuffer *ctxValueBuffers;
    dpiShardingKeyColumn *shardingKeyColumns;
    pyoBuffer *shardingKeyBuffers;
    uint32_t numShardingKeyColumns;
    dpiShardingKeyColumn *superShardingKeyColumns;
    uint32_t numSuperShardingKeyColumns;
    pyoBuffer *superShardingKeyBuffers;
} pyoConnectionParams;


//-----------------------------------------------------------------------------
// pyoConnectionParams_initialize()
//   Initialize the parameters to default values.
//-----------------------------------------------------------------------------
static void pyoConnectionParams_initialize(pyoConnectionParams *params)
{
    pyoBuffer_init(&params->userNameBuffer);
    pyoBuffer_init(&params->passwordBuffer);
    pyoBuffer_init(&params->newPasswordBuffer);
    pyoBuffer_init(&params->dsnBuffer);
    pyoBuffer_init(&params->connectionClassBuffer);
    pyoBuffer_init(&params->editionBuffer);
    pyoBuffer_init(&params->tagBuffer);
    params->numAppContext = 0;
    params->appContext = NULL;
    params->ctxNamespaceBuffers = NULL;
    params->ctxNameBuffers = NULL;
    params->ctxValueBuffers = NULL;
    params->numShardingKeyColumns = 0;
    params->shardingKeyColumns = NULL;
    params->shardingKeyBuffers = NULL;
    params->numSuperShardingKeyColumns = 0;
    params->superShardingKeyColumns = NULL;
    params->superShardingKeyBuffers = NULL;
}


//-----------------------------------------------------------------------------
// pyoConnectionParams_ProcessContext()
//   Process context for the connection parameters. This validates that the
// context passed in is a list of 3-tuples (namespace, name, value) and
// populates the parametrs with buffers for each of these.
//-----------------------------------------------------------------------------
static int pyoConnectionParams_processContext(pyoConnectionParams *params,
        PyObject *context)
{
    uint32_t numEntries, i;
    dpiAppContext *entry;
    PyObject *entryObj;
    size_t memorySize;

    // validate context is a list with at least one entry in it
    if (!context)
        return 0;
    if (!PyList_Check(context)) {
        PyErr_SetString(PyExc_TypeError,
                "appcontext should be a list of 3-tuples");
        return -1;
    }
    numEntries = (uint32_t) PyList_GET_SIZE(context);
    if (numEntries == 0)
        return 0;

    // allocate memory for the buffers used to communicate with DPI
    params->appContext = PyMem_Malloc(numEntries * sizeof(dpiAppContext));
    memorySize = numEntries * sizeof(pyoBuffer);
    params->ctxNamespaceBuffers = PyMem_Malloc(memorySize);
    params->ctxNameBuffers = PyMem_Malloc(memorySize);
    params->ctxValueBuffers = PyMem_Malloc(memorySize);
    if (!params->appContext || !params->ctxNamespaceBuffers ||
            !params->ctxNameBuffers || !params->ctxValueBuffers) {
        PyErr_NoMemory();
        return -1;
    }

    // initialize buffers
    for (i = 0; i < numEntries; i++) {
        pyoBuffer_init(&params->ctxNamespaceBuffers[i]);
        pyoBuffer_init(&params->ctxNameBuffers[i]);
        pyoBuffer_init(&params->ctxValueBuffers[i]);
    }
    params->numAppContext = numEntries;

    // process each entry
    for (i = 0; i < numEntries; i++) {
        entryObj = PyList_GET_ITEM(context, i);
        if (!PyTuple_Check(entryObj) || PyTuple_GET_SIZE(entryObj) != 3) {
            PyErr_SetString(PyExc_TypeError,
                    "appcontext should be a list of 3-tuples");
            return -1;
        }
        if (pyoBuffer_fromObject(&params->ctxNamespaceBuffers[i],
                PyTuple_GET_ITEM(entryObj, 0), params->encoding) < 0)
            return -1;
        if (pyoBuffer_fromObject(&params->ctxNameBuffers[i],
                PyTuple_GET_ITEM(entryObj, 1), params->encoding) < 0)
            return -1;
        if (pyoBuffer_fromObject(&params->ctxValueBuffers[i],
                PyTuple_GET_ITEM(entryObj, 2), params->encoding) < 0)
            return -1;
        entry = &params->appContext[i];
        entry->namespaceName = params->ctxNamespaceBuffers[i].ptr;
        entry->namespaceNameLength = params->ctxNamespaceBuffers[i].size;
        entry->name = params->ctxNameBuffers[i].ptr;
        entry->nameLength = params->ctxNameBuffers[i].size;
        entry->value = params->ctxValueBuffers[i].ptr;
        entry->valueLength = params->ctxValueBuffers[i].size;
    }

    return 0;
}


//-----------------------------------------------------------------------------
// pyoConnectionParams_processShardingKeyValue()
//   Process a single sharding key value.
//-----------------------------------------------------------------------------
static int pyoConnectionParams_processShardingKeyValue(
        pyoConnectionParams *params, PyObject *value,
        dpiShardingKeyColumn *column, pyoBuffer *buffer)
{
    pyoTransformNum transformNum;

    transformNum = pyoTransform_getNumFromValue(value, 0);
    if (pyoTransform_fromPython(transformNum, value, &column->value, buffer,
            params->encoding, params->nencoding, NULL, 0) < 0)
        return -1;
    pyoTransform_getTypeInfo(transformNum, &column->oracleTypeNum,
            &column->nativeTypeNum);
    return 0;
}


//-----------------------------------------------------------------------------
// pyoConnectionParams_processShardingKey()
//   Process either the sharding key or the super sharding key. A sharding key
// is expected to be a sequence of values. A null value or a sequence of size
// 0 is ignored.
//-----------------------------------------------------------------------------
static int pyoConnectionParams_processShardingKey(pyoConnectionParams *params,
        PyObject *shardingKeyObj, int isSuperShardingKey)
{
    dpiShardingKeyColumn *columns;
    uint32_t i, numColumns;
    pyoBuffer *buffers;
    PyObject *value;

    // validate sharding key
    if (!shardingKeyObj || shardingKeyObj == Py_None)
        return 0;
    if (!PySequence_Check(shardingKeyObj)) {
        PyErr_SetString(PyExc_TypeError, "expecting a sequence");
        return -1;
    }
    numColumns = (uint32_t) PySequence_Size(shardingKeyObj);
    if (numColumns == 0)
        return 0;

    // allocate memory for the sharding key values
    columns = PyMem_Malloc(numColumns * sizeof(dpiShardingKeyColumn));
    buffers = PyMem_Malloc(numColumns * sizeof(pyoBuffer));
    if (isSuperShardingKey) {
        params->superShardingKeyColumns = columns;
        params->superShardingKeyBuffers = buffers;
        params->numSuperShardingKeyColumns = numColumns;
    } else {
        params->shardingKeyColumns = columns;
        params->shardingKeyBuffers = buffers;
        params->numShardingKeyColumns = numColumns;
    }
    if (!columns || !buffers) {
        PyErr_NoMemory();
        return -1;
    }

    // process each value
    for (i = 0; i < numColumns; i++) {
        pyoBuffer_init(&buffers[i]);
        value = PySequence_GetItem(shardingKeyObj, i);
        if (!value)
            return -1;
        if (pyoConnectionParams_processShardingKeyValue(params, value,
                &columns[i], &buffers[i]) < 0)
            return -1;
    }

    return 0;
}


//-----------------------------------------------------------------------------
// pyoConnectionParams_finalize()
//   Finalize the parameters, freeing any resources that were allocated. The
// return value is a convenience to the caller.
//-----------------------------------------------------------------------------
static int pyoConnectionParams_finalize(pyoConnectionParams *params)
{
    uint32_t i;

    pyoBuffer_clear(&params->userNameBuffer);
    pyoBuffer_clear(&params->passwordBuffer);
    pyoBuffer_clear(&params->newPasswordBuffer);
    pyoBuffer_clear(&params->dsnBuffer);
    pyoBuffer_clear(&params->connectionClassBuffer);
    pyoBuffer_clear(&params->editionBuffer);
    pyoBuffer_clear(&params->tagBuffer);
    for (i = 0; i < params->numAppContext; i++) {
        pyoBuffer_clear(&params->ctxNamespaceBuffers[i]);
        pyoBuffer_clear(&params->ctxNameBuffers[i]);
        pyoBuffer_clear(&params->ctxValueBuffers[i]);
    }
    params->numAppContext = 0;
    if (params->appContext) {
        PyMem_Free(params->appContext);
        params->appContext = NULL;
    }
    if (params->ctxNamespaceBuffers) {
        PyMem_Free(params->ctxNamespaceBuffers);
        params->ctxNamespaceBuffers = NULL;
    }
    if (params->ctxNameBuffers) {
        PyMem_Free(params->ctxNameBuffers);
        params->ctxNameBuffers = NULL;
    }
    if (params->ctxValueBuffers) {
        PyMem_Free(params->ctxValueBuffers);
        params->ctxValueBuffers = NULL;
    }
    for (i = 0; i < params->numShardingKeyColumns; i++)
        pyoBuffer_clear(&params->shardingKeyBuffers[i]);
    if (params->shardingKeyColumns) {
        PyMem_Free(params->shardingKeyColumns);
        params->shardingKeyColumns = NULL;
    }
    if (params->shardingKeyBuffers) {
        PyMem_Free(params->shardingKeyBuffers);
        params->shardingKeyBuffers = NULL;
    }
    for (i = 0; i < params->numSuperShardingKeyColumns; i++)
        pyoBuffer_clear(&params->superShardingKeyBuffers[i]);
    if (params->superShardingKeyColumns) {
        PyMem_Free(params->superShardingKeyColumns);
        params->superShardingKeyColumns = NULL;
    }
    if (params->superShardingKeyBuffers) {
        PyMem_Free(params->superShardingKeyBuffers);
        params->superShardingKeyBuffers = NULL;
    }
    return -1;
}


//-----------------------------------------------------------------------------
// pyoConnection_new()
//   Create a new connection object and return it.
//-----------------------------------------------------------------------------
static PyObject *pyoConnection_new(PyTypeObject *type, PyObject *args,
        PyObject *keywordArgs)
{
    return type->tp_alloc(type, 0);
}


//-----------------------------------------------------------------------------
// pyoConnection_init()
//   Initialize the connection members.
//-----------------------------------------------------------------------------
static int pyoConnection_init(pyoConnection *conn, PyObject *args,
        PyObject *keywordArgs)
{
    PyObject *usernameObj, *passwordObj, *dsnObj, *cclassObj, *editionObj;
    PyObject *shardingKeyObj, *superShardingKeyObj;
    dpiCommonCreateParams dpiCommonParams;
    dpiConnCreateParams dpiCreateParams;
    unsigned long long externalHandle;
    PyObject *tagObj, *contextObj;
    pyoConnectionParams params;
    PyObject *newPasswordObj;
    int status, events, temp;
    pyoSessionPool *pool;

    // parse arguments
    pool = NULL;
    events = 0;
    externalHandle = 0;
    newPasswordObj = usernameObj = NULL;
    passwordObj = dsnObj = cclassObj = editionObj = tagObj = NULL;
    contextObj = shardingKeyObj = superShardingKeyObj = NULL;
    if (pyoUtils_initializeDPI() < 0)
        return -1;
    if (dpiContext_initCommonCreateParams(pyoDpiContext, &dpiCommonParams) < 0)
        return pyoError_raiseAndReturnInt();
    dpiCommonParams.driverName = PYO_DRIVER_NAME;
    dpiCommonParams.driverNameLength =
            (uint32_t) strlen(dpiCommonParams.driverName);
    if (dpiContext_initConnCreateParams(pyoDpiContext, &dpiCreateParams) < 0)
        return pyoError_raiseAndReturnInt();
    if (!PyArg_ParseTuple(args, "|OOOiKpOOiOssOOOOOO", &usernameObj,
            &passwordObj, &dsnObj, &dpiCreateParams.authMode, &externalHandle,
            &events, &cclassObj, &dpiCreateParams.purity, &newPasswordObj,
            &dpiCommonParams.encoding, &dpiCommonParams.nencoding, &editionObj,
            &contextObj, &tagObj, &dpiCreateParams.matchAnyTag,
            &shardingKeyObj, &superShardingKeyObj))
        return -1;
    dpiCreateParams.externalHandle = (void*) externalHandle;
    dpiCommonParams.createMode |= DPI_MODE_CREATE_THREADED;
    if (events)
        dpiCommonParams.createMode |= DPI_MODE_CREATE_EVENTS;

    // keep a copy of the user name and connect string (DSN)
    Py_XINCREF(usernameObj);
    conn->username = usernameObj;
    Py_XINCREF(dsnObj);
    conn->dsn = dsnObj;

    // setup parameters
    pyoConnectionParams_initialize(&params);
    if (pool) {
        dpiCreateParams.pool = pool->handle;
        params.encoding = pool->encodingInfo.encoding;
        params.nencoding = pool->encodingInfo.nencoding;
    } else {
        params.encoding =
                pyoUtils_getAdjustedEncoding(dpiCommonParams.encoding);
        params.nencoding =
                pyoUtils_getAdjustedEncoding(dpiCommonParams.nencoding);
    }
    if (pyoConnectionParams_processContext(&params, contextObj) < 0)
        return pyoConnectionParams_finalize(&params);
    if (pyoConnectionParams_processShardingKey(&params, shardingKeyObj, 0) < 0)
        return pyoConnectionParams_finalize(&params);
    if (pyoConnectionParams_processShardingKey(&params, superShardingKeyObj,
            1) < 0)
        return pyoConnectionParams_finalize(&params);
    if (pyoBuffer_fromObject(&params.userNameBuffer, conn->username,
                    params.encoding) < 0 ||
            pyoBuffer_fromObject(&params.passwordBuffer, passwordObj,
                    params.encoding) < 0 ||
            pyoBuffer_fromObject(&params.dsnBuffer, conn->dsn,
                    params.encoding) < 0 ||
            pyoBuffer_fromObject(&params.connectionClassBuffer, cclassObj,
                    params.encoding) < 0 ||
            pyoBuffer_fromObject(&params.newPasswordBuffer, newPasswordObj,
                    params.encoding) < 0 ||
            pyoBuffer_fromObject(&params.editionBuffer, editionObj,
                    params.encoding) < 0 ||
            pyoBuffer_fromObject(&params.tagBuffer, tagObj,
                    params.encoding) < 0)
        return pyoConnectionParams_finalize(&params);
    if (params.userNameBuffer.size == 0 && params.passwordBuffer.size == 0)
        dpiCreateParams.externalAuth = 1;
    dpiCreateParams.connectionClass = params.connectionClassBuffer.ptr;
    dpiCreateParams.connectionClassLength = params.connectionClassBuffer.size;
    dpiCreateParams.newPassword = params.newPasswordBuffer.ptr;
    dpiCreateParams.newPasswordLength = params.newPasswordBuffer.size;
    dpiCommonParams.edition = params.editionBuffer.ptr;
    dpiCommonParams.editionLength = params.editionBuffer.size;
    dpiCreateParams.tag = params.tagBuffer.ptr;
    dpiCreateParams.tagLength = params.tagBuffer.size;
    dpiCreateParams.appContext = params.appContext;
    dpiCreateParams.numAppContext = params.numAppContext;
    dpiCreateParams.shardingKeyColumns = params.shardingKeyColumns;
    dpiCreateParams.numShardingKeyColumns = params.numShardingKeyColumns;
    dpiCreateParams.superShardingKeyColumns = params.superShardingKeyColumns;
    dpiCreateParams.numSuperShardingKeyColumns =
            params.numSuperShardingKeyColumns;
    if (pool && !pool->homogeneous && pool->username && conn->username) {
        temp = PyObject_RichCompareBool(conn->username, pool->username, Py_EQ);
        if (temp < 0)
            return pyoConnectionParams_finalize(&params);
        if (temp)
            params.userNameBuffer.size = 0;
    }

    // create connection
    Py_BEGIN_ALLOW_THREADS
    status = dpiConn_create(pyoDpiContext, params.userNameBuffer.ptr,
            params.userNameBuffer.size, params.passwordBuffer.ptr,
            params.passwordBuffer.size, params.dsnBuffer.ptr,
            params.dsnBuffer.size, &dpiCommonParams, &dpiCreateParams,
            &conn->handle);
    Py_END_ALLOW_THREADS
    pyoConnectionParams_finalize(&params);
    if (status < 0)
        return pyoError_raiseAndReturnInt();

    // determine encodings to use
    if (pool)
        conn->encodingInfo = pool->encodingInfo;
    else {
        if (dpiConn_getEncodingInfo(conn->handle, &conn->encodingInfo) < 0)
            return pyoError_raiseAndReturnInt();
        conn->encodingInfo.encoding =
                pyoUtils_getAdjustedEncoding(conn->encodingInfo.encoding);
        conn->encodingInfo.nencoding =
                pyoUtils_getAdjustedEncoding(conn->encodingInfo.nencoding);
    }

    return 0;
}


//-----------------------------------------------------------------------------
// pyoConnection_free()
//   Deallocate the connection, disconnecting from the database if necessary.
//-----------------------------------------------------------------------------
static void pyoConnection_free(pyoConnection *conn)
{
    if (conn->handle) {
        Py_BEGIN_ALLOW_THREADS
        dpiConn_release(conn->handle);
        Py_END_ALLOW_THREADS
        conn->handle = NULL;
    }
    Py_CLEAR(conn->sessionPool);
    Py_CLEAR(conn->username);
    Py_CLEAR(conn->dsn);
    Py_CLEAR(conn->version);
    Py_CLEAR(conn->inputTypeHandler);
    Py_CLEAR(conn->outputTypeHandler);
    Py_TYPE(conn)->tp_free((PyObject*) conn);
}


//-----------------------------------------------------------------------------
// pyoConnection_repr()
//   Return a string representation of the connection.
//-----------------------------------------------------------------------------
static PyObject *pyoConnection_repr(pyoConnection *connection)
{
    PyObject *module, *name, *result;

    if (pyoUtils_getModuleAndName(Py_TYPE(connection), &module, &name) < 0)
        return NULL;
    if (connection->username && connection->username != Py_None &&
            connection->dsn && connection->dsn != Py_None) {
        result = pyoUtils_formatString("<%s.%s to %s@%s>",
                PyTuple_Pack(4, module, name, connection->username,
                        connection->dsn));
    } else if (connection->username && connection->username != Py_None) {
        result = pyoUtils_formatString("<%s.%s to user %s@local>",
                PyTuple_Pack(3, module, name, connection->username));
    } else {
        result = pyoUtils_formatString("<%s.%s to externally identified user>",
                PyTuple_Pack(2, module, name));
    }
    Py_DECREF(module);
    Py_DECREF(name);
    return result;
}

