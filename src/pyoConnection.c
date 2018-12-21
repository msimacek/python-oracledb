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
static PyObject *pyoConnection_connect(pyoConnection*, PyObject*, PyObject*);
static PyObject *pyoConnection_repr(pyoConnection*);
static void pyoAsyncDataConnect_free(void *arg);
static int pyoAsyncDataConnect_run(void *arg, dpiAsync *async,
        dpiAsyncState *state);

//-----------------------------------------------------------------------------
// declaration of methods for the Python type "Connection"
//-----------------------------------------------------------------------------
static PyMethodDef pyoMethods[] = {
    { "_connect", (PyCFunction) pyoConnection_connect,
            METH_VARARGS | METH_KEYWORDS },
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
    .tp_new = (newfunc) pyoConnection_new
};


//-----------------------------------------------------------------------------
// structures used for asynchronously connecting to the database
//-----------------------------------------------------------------------------
typedef struct {
    pyoAsyncData_HEAD
    pyoConnection *conn;
    dpiCommonCreateParams commonParams;
    dpiConnCreateParams createParams;
    pyoBuffer driverNameBuffer;
    pyoBuffer userBuffer;
    pyoBuffer passwordBuffer;
    pyoBuffer newPasswordBuffer;
    pyoBuffer dsnBuffer;
    pyoBuffer cclassBuffer;
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
} pyoAsyncDataConnect;

static pyoAsyncDataType pyoAsyncDataTypeConnect = {
    .structSize = sizeof(pyoAsyncDataConnect),
    .freeDataProc = pyoAsyncDataConnect_free,
    .runProc = pyoAsyncDataConnect_run
};


//-----------------------------------------------------------------------------
// pyoAsyncDataConnect_run()
//   Function that runs asynchronously in ODPI-C. No Python API calls may be
// made in this function.
//-----------------------------------------------------------------------------
static int pyoAsyncDataConnect_run(void *arg, dpiAsync *async,
        dpiAsyncState *state)
{
    pyoAsyncDataConnect *data = (pyoAsyncDataConnect*) arg;

    return dpiConn_create(pyoDpiContext, data->userBuffer.ptr,
            data->userBuffer.size, data->passwordBuffer.ptr,
            data->passwordBuffer.size, data->dsnBuffer.ptr,
            data->dsnBuffer.size, &data->commonParams, &data->createParams,
            &data->conn->handle);
}


//-----------------------------------------------------------------------------
// pyoAsyncDataConnect_free()
//   Free data associated with asynchronous connection function.
//-----------------------------------------------------------------------------
static void pyoAsyncDataConnect_free(void *arg)
{
    pyoAsyncDataConnect *data = (pyoAsyncDataConnect*) arg;
    uint32_t i;

    pyoBuffer_clear(&data->driverNameBuffer);
    pyoBuffer_clear(&data->userBuffer);
    pyoBuffer_clear(&data->passwordBuffer);
    pyoBuffer_clear(&data->newPasswordBuffer);
    pyoBuffer_clear(&data->dsnBuffer);
    pyoBuffer_clear(&data->cclassBuffer);
    pyoBuffer_clear(&data->editionBuffer);
    pyoBuffer_clear(&data->tagBuffer);
    for (i = 0; i < data->numAppContext; i++) {
        pyoBuffer_clear(&data->ctxNamespaceBuffers[i]);
        pyoBuffer_clear(&data->ctxNameBuffers[i]);
        pyoBuffer_clear(&data->ctxValueBuffers[i]);
    }
    data->numAppContext = 0;
    if (data->appContext) {
        PyMem_Free(data->appContext);
        data->appContext = NULL;
    }
    if (data->ctxNamespaceBuffers) {
        PyMem_Free(data->ctxNamespaceBuffers);
        data->ctxNamespaceBuffers = NULL;
    }
    if (data->ctxNameBuffers) {
        PyMem_Free(data->ctxNameBuffers);
        data->ctxNameBuffers = NULL;
    }
    if (data->ctxValueBuffers) {
        PyMem_Free(data->ctxValueBuffers);
        data->ctxValueBuffers = NULL;
    }
    for (i = 0; i < data->numShardingKeyColumns; i++)
        pyoBuffer_clear(&data->shardingKeyBuffers[i]);
    if (data->shardingKeyColumns) {
        PyMem_Free(data->shardingKeyColumns);
        data->shardingKeyColumns = NULL;
    }
    if (data->shardingKeyBuffers) {
        PyMem_Free(data->shardingKeyBuffers);
        data->shardingKeyBuffers = NULL;
    }
    for (i = 0; i < data->numSuperShardingKeyColumns; i++)
        pyoBuffer_clear(&data->superShardingKeyBuffers[i]);
    if (data->superShardingKeyColumns) {
        PyMem_Free(data->superShardingKeyColumns);
        data->superShardingKeyColumns = NULL;
    }
    if (data->superShardingKeyBuffers) {
        PyMem_Free(data->superShardingKeyBuffers);
        data->superShardingKeyBuffers = NULL;
    }
}


//-----------------------------------------------------------------------------
// pyoAsyncDataConnect_processContext()
//   Process context for the connection parameters. This validates that the
// context passed in is a list of 3-tuples (namespace, name, value) and
// populates the parametrs with buffers for each of these.
//-----------------------------------------------------------------------------
static int pyoAsyncDataConnect_processContext(pyoAsyncDataConnect *data,
        PyObject *contextObj)
{
    uint32_t numEntries, i;
    dpiAppContext *entry;
    PyObject *entryObj;
    size_t memorySize;

    // validate context is a list with at least one entry in it
    if (!contextObj)
        return 0;
    if (!PyList_Check(contextObj)) {
        PyErr_SetString(PyExc_TypeError,
                "app_context should be a list of 3-tuples");
        return -1;
    }
    numEntries = (uint32_t) PyList_GET_SIZE(contextObj);
    if (numEntries == 0)
        return 0;

    // allocate memory for the buffers used to communicate with DPI
    data->appContext = PyMem_Malloc(numEntries * sizeof(dpiAppContext));
    memorySize = numEntries * sizeof(pyoBuffer);
    data->ctxNamespaceBuffers = PyMem_Malloc(memorySize);
    data->ctxNameBuffers = PyMem_Malloc(memorySize);
    data->ctxValueBuffers = PyMem_Malloc(memorySize);
    if (!data->appContext || !data->ctxNamespaceBuffers ||
            !data->ctxNameBuffers || !data->ctxValueBuffers) {
        PyErr_NoMemory();
        return -1;
    }

    // initialize buffers
    for (i = 0; i < numEntries; i++) {
        pyoBuffer_init(&data->ctxNamespaceBuffers[i]);
        pyoBuffer_init(&data->ctxNameBuffers[i]);
        pyoBuffer_init(&data->ctxValueBuffers[i]);
    }
    data->numAppContext = numEntries;

    // process each entry
    for (i = 0; i < numEntries; i++) {
        entryObj = PyList_GET_ITEM(contextObj, i);
        if (!PyTuple_Check(entryObj) || PyTuple_GET_SIZE(entryObj) != 3) {
            PyErr_SetString(PyExc_TypeError,
                    "app_context should be a list of 3-tuples");
            return -1;
        }
        if (pyoBuffer_fromObject(&data->ctxNamespaceBuffers[i],
                PyTuple_GET_ITEM(entryObj, 0)) < 0)
            return -1;
        if (pyoBuffer_fromObject(&data->ctxNameBuffers[i],
                PyTuple_GET_ITEM(entryObj, 1)) < 0)
            return -1;
        if (pyoBuffer_fromObject(&data->ctxValueBuffers[i],
                PyTuple_GET_ITEM(entryObj, 2)) < 0)
            return -1;
        entry = &data->appContext[i];
        entry->namespaceName = data->ctxNamespaceBuffers[i].ptr;
        entry->namespaceNameLength = data->ctxNamespaceBuffers[i].size;
        entry->name = data->ctxNameBuffers[i].ptr;
        entry->nameLength = data->ctxNameBuffers[i].size;
        entry->value = data->ctxValueBuffers[i].ptr;
        entry->valueLength = data->ctxValueBuffers[i].size;
    }

    return 0;
}


//-----------------------------------------------------------------------------
// pyoAsyncDataConnect_processShardingKeyValue()
//   Process a single sharding key value.
//-----------------------------------------------------------------------------
static int pyoAsyncDataConnect_processShardingKeyValue(
        pyoAsyncDataConnect *data, PyObject *value,
        dpiShardingKeyColumn *column, pyoBuffer *buffer)
{
    pyoTransformNum transformNum;

    transformNum = pyoTransform_getNumFromValue(value, 0);
    if (pyoTransform_fromPython(transformNum, value, &column->value, buffer,
            NULL, 0) < 0)
        return -1;
    pyoTransform_getTypeInfo(transformNum, &column->oracleTypeNum,
            &column->nativeTypeNum);
    return 0;
}


//-----------------------------------------------------------------------------
// pyoAsyncDataConnect_processShardingKey()
//   Process either the sharding key or the super sharding key. A sharding key
// is expected to be a sequence of values. A null value or a sequence of size
// 0 is ignored.
//-----------------------------------------------------------------------------
static int pyoAsyncDataConnect_processShardingKey(pyoAsyncDataConnect *data,
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
        data->superShardingKeyColumns = columns;
        data->superShardingKeyBuffers = buffers;
        data->numSuperShardingKeyColumns = numColumns;
    } else {
        data->shardingKeyColumns = columns;
        data->shardingKeyBuffers = buffers;
        data->numShardingKeyColumns = numColumns;
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
        if (pyoAsyncDataConnect_processShardingKeyValue(data, value,
                &columns[i], &buffers[i]) < 0)
            return -1;
    }

    return 0;
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
// pyoConnection_connect()
//   Initialize the connection members.
//-----------------------------------------------------------------------------
static PyObject *pyoConnection_connect(pyoConnection *conn, PyObject *args,
        PyObject *keywordArgs)
{
    PyObject *cclassObj, *newPasswordObj, *editionObj, *appContextObj, *tagObj;
    PyObject *futureObj, *driverNameObj, *userObj, *passwordObj, *dsnObj;
    PyObject *shardingKeyObj, *superShardingKeyObj, *loopObj;
    int temp, events, purity, matchAnyTag;
    unsigned long long externalHandle;
    pyoAsyncDataConnect *data;
    pyoSessionPool *pool;

    // keyword arguments
    static char *keywordList[] = { "loop", "future", "driver_name", "user",
            "password", "dsn", "handle", "events", "cclass", "purity",
            "new_password", "edition", "app_context", "tag", "match_any_tag",
            "sharding_key", "super_sharding_key", "pool", NULL };

    // initialize ODPI-C, if necessary
    if (pyoUtils_initializeDPI() < 0)
        return NULL;

    // parse arguments
    pool = NULL;
    externalHandle = 0;
    superShardingKeyObj = NULL;
    events = purity = matchAnyTag = 0;
    userObj = passwordObj = dsnObj = cclassObj = newPasswordObj = NULL;
    editionObj = appContextObj = tagObj = shardingKeyObj = NULL;
    if (!PyArg_ParseTupleAndKeywords(args, keywordArgs, "OOO|OOOKpOiOOOOpOOO!",
            keywordList, &loopObj, &futureObj, &driverNameObj, &userObj,
            &passwordObj, &dsnObj, &externalHandle, &events, &cclassObj,
            &purity, &newPasswordObj, &editionObj, &appContextObj, &tagObj,
            &matchAnyTag, &shardingKeyObj, &superShardingKeyObj,
            &pyoPyTypeSessionPool, &pool))
        return NULL;

    // keep a copy of the user name and connect string (DSN)
    Py_XINCREF(userObj);
    conn->username = userObj;
    Py_XINCREF(dsnObj);
    conn->dsn = dsnObj;

    // create aysnchronous data
    if (pyoAsync_allocateData(&pyoAsyncDataTypeConnect, loopObj, futureObj,
            (void**) &data) < 0)
        return NULL;
    data->conn = conn;
    if (dpiContext_initCommonCreateParams(pyoDpiContext,
            &data->commonParams) < 0) {
        pyoError_raiseAndReturnNull();
        return pyoAsync_freeData(data);
    }
    if (dpiContext_initConnCreateParams(pyoDpiContext,
            &data->createParams) < 0) {
        pyoError_raiseAndReturnNull();
        return pyoAsync_freeData(data);
    }
    if (pyoAsyncDataConnect_processContext(data, appContextObj) < 0)
        return pyoAsync_freeData(data);
    if (pyoAsyncDataConnect_processShardingKey(data, shardingKeyObj, 0) < 0)
        return pyoAsync_freeData(data);
    if (pyoAsyncDataConnect_processShardingKey(data, superShardingKeyObj,
            1) < 0)
        return pyoAsync_freeData(data);
    if (pyoBuffer_fromObject(&data->userBuffer, userObj) < 0 ||
            pyoBuffer_fromObject(&data->passwordBuffer, passwordObj) < 0 ||
            pyoBuffer_fromObject(&data->dsnBuffer, conn->dsn) < 0 ||
            pyoBuffer_fromObject(&data->cclassBuffer, cclassObj) < 0 ||
            pyoBuffer_fromObject(&data->newPasswordBuffer,
                    newPasswordObj) < 0 ||
            pyoBuffer_fromObject(&data->driverNameBuffer, driverNameObj) < 0 ||
            pyoBuffer_fromObject(&data->editionBuffer, editionObj) < 0 ||
            pyoBuffer_fromObject(&data->tagBuffer, tagObj) < 0)
        return pyoAsync_freeData(data);

    // transfer to ODPI-C common creation parameters
    data->commonParams.createMode |= DPI_MODE_CREATE_THREADED;
    if (events)
        data->commonParams.createMode |= DPI_MODE_CREATE_EVENTS;
    data->commonParams.driverName = data->driverNameBuffer.ptr;
    data->commonParams.driverNameLength = data->driverNameBuffer.size;
    data->commonParams.edition = data->editionBuffer.ptr;
    data->commonParams.editionLength = data->editionBuffer.size;

    // transfer to ODPI-C connection creation parameters
    data->createParams.externalHandle = (void*) externalHandle;
    if (pool)
        data->createParams.pool = pool->handle;
    if (data->userBuffer.size == 0 && data->passwordBuffer.size == 0)
        data->createParams.externalAuth = 1;
    data->createParams.connectionClass = data->cclassBuffer.ptr;
    data->createParams.connectionClassLength = data->cclassBuffer.size;
    data->createParams.newPassword = data->newPasswordBuffer.ptr;
    data->createParams.newPasswordLength = data->newPasswordBuffer.size;
    data->createParams.tag = data->tagBuffer.ptr;
    data->createParams.tagLength = data->tagBuffer.size;
    data->createParams.appContext = data->appContext;
    data->createParams.numAppContext = data->numAppContext;
    data->createParams.shardingKeyColumns = data->shardingKeyColumns;
    data->createParams.numShardingKeyColumns = data->numShardingKeyColumns;
    data->createParams.superShardingKeyColumns = data->superShardingKeyColumns;
    data->createParams.numSuperShardingKeyColumns =
            data->numSuperShardingKeyColumns;

    // for heterogeneous pools, clear user
    if (pool && !pool->homogeneous && pool->username && userObj) {
        temp = PyObject_RichCompareBool(userObj, pool->username, Py_EQ);
        if (temp < 0)
            return pyoAsync_freeData(data);
        if (temp) {
            data->userBuffer.ptr = NULL;
            data->userBuffer.size = 0;
        }
    }

    // run asynchronous function
    if (pyoAsync_run(data) < 0)
        return NULL;

    Py_RETURN_NONE;
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

