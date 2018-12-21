//-----------------------------------------------------------------------------
// Copyright (c) 2018, Oracle and/or its affiliates. All rights reserved.
//
// Licensed under BSD license (see LICENSE.txt).
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// pyoModule.c
//   Implementation of oracledb module.
//-----------------------------------------------------------------------------

#include "pyoModule.h"

// define macro for adding type objects
#define PYO_ADD_TYPE_OBJECT(name, type) \
    if (PyType_Ready(type) < 0) \
        return NULL; \
    Py_INCREF(type); \
    if (PyModule_AddObject(module, name, (PyObject*) type) < 0) \
        return NULL;


//-----------------------------------------------------------------------------
// Globals
//-----------------------------------------------------------------------------
PyObject *pyoWarningException = NULL;
PyObject *pyoErrorException = NULL;
PyObject *pyoInterfaceErrorException = NULL;
PyObject *pyoDatabaseErrorException = NULL;
PyObject *pyoDataErrorException = NULL;
PyObject *pyoOperationalErrorException = NULL;
PyObject *pyoIntegrityErrorException = NULL;
PyObject *pyoInternalErrorException = NULL;
PyObject *pyoProgrammingErrorException = NULL;
PyObject *pyoNotSupportedErrorException = NULL;
PyObject *pyoJsonDumpFunction = NULL;
PyObject *pyoJsonLoadFunction = NULL;
PyObject *pyoSetResultName = NULL;
PyObject *pyoSetExceptionName = NULL;
PyObject *pyoCallSoonThreadsafeName = NULL;
dpiContext *pyoDpiContext = NULL;
dpiVersionInfo pyoClientVersionInfo;


//-----------------------------------------------------------------------------
// Declaration of module definition.
//-----------------------------------------------------------------------------
static struct PyModuleDef pyoModuleDef = {
    PyModuleDef_HEAD_INIT,
    "_oracledb",
    NULL,
    -1,
    NULL,                               // methods
    NULL,                               // m_reload
    NULL,                               // traverse
    NULL,                               // clear
    NULL                                // free
};


//-----------------------------------------------------------------------------
// pyoModule_setException()
//   Create an exception and set it in the provided dictionary.
//-----------------------------------------------------------------------------
static int pyoModule_setException(PyObject *module, PyObject **exception,
        char *name, PyObject *baseException)
{
    char buffer[100];

    sprintf(buffer, "oracledb.%s", name);
    *exception = PyErr_NewException(buffer, baseException, NULL);
    if (!*exception)
        return -1;
    return PyModule_AddObject(module, name, *exception);
}


//-----------------------------------------------------------------------------
// PyInit__oracledb()
//   Initialization routine for the module.
//-----------------------------------------------------------------------------
PyMODINIT_FUNC PyInit__oracledb(void)
{
    PyObject *module;

    // this function no longer needs to be called once Python 3.7 is the
    // minimum version supported
    PyEval_InitThreads();

    // create module object
    module = PyModule_Create(&pyoModuleDef);
    if (!module)
        return NULL;

    // create method names used for completing futures
    pyoSetResultName = PyUnicode_DecodeASCII("set_result",
            strlen("set_result"), NULL);
    if (!pyoSetResultName)
        return NULL;
    pyoSetExceptionName = PyUnicode_DecodeASCII("set_exception",
            strlen("set_exception"), NULL);
    if (!pyoSetExceptionName)
        return NULL;
    pyoCallSoonThreadsafeName = PyUnicode_DecodeASCII("call_soon_threadsafe",
            strlen("call_soon_threadsafe"), NULL);
    if (!pyoCallSoonThreadsafeName)
        return NULL;

    // create exception objects
    if (pyoModule_setException(module, &pyoWarningException, "Warning",
            NULL) < 0)
        return NULL;
    if (pyoModule_setException(module, &pyoErrorException, "Error", NULL) < 0)
        return NULL;
    if (pyoModule_setException(module, &pyoInterfaceErrorException,
            "InterfaceError", pyoErrorException) < 0)
        return NULL;
    if (pyoModule_setException(module, &pyoDatabaseErrorException,
            "DatabaseError", pyoErrorException) < 0)
        return NULL;
    if (pyoModule_setException(module, &pyoDataErrorException,
            "DataError", pyoDatabaseErrorException) < 0)
        return NULL;
    if (pyoModule_setException(module, &pyoOperationalErrorException,
            "OperationalError", pyoDatabaseErrorException) < 0)
        return NULL;
    if (pyoModule_setException(module, &pyoIntegrityErrorException,
            "IntegrityError", pyoDatabaseErrorException) < 0)
        return NULL;
    if (pyoModule_setException(module, &pyoInternalErrorException,
            "InternalError", pyoDatabaseErrorException) < 0)
        return NULL;
    if (pyoModule_setException(module, &pyoProgrammingErrorException,
            "ProgrammingError", pyoDatabaseErrorException) < 0)
        return NULL;
    if (pyoModule_setException(module, &pyoNotSupportedErrorException,
            "NotSupportedError", pyoDatabaseErrorException) < 0)
        return NULL;

    // add types
    PYO_ADD_TYPE_OBJECT("Connection", &pyoPyTypeConnection)
    PYO_ADD_TYPE_OBJECT("SessionPool", &pyoPyTypeSessionPool)
    PYO_ADD_TYPE_OBJECT("Error", &pyoPyTypeError)

    return module;
}

