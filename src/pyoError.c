//-----------------------------------------------------------------------------
// Copyright (c) 2018, Oracle and/or its affiliates. All rights reserved.
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// pyoError.c
//   Error handling.
//-----------------------------------------------------------------------------

#include "pyoModule.h"

//-----------------------------------------------------------------------------
// forward declarations
//-----------------------------------------------------------------------------
static void pyoError_free(pyoError *error);
static PyObject *pyoError_str(pyoError *error);
static PyObject *pyoError_new(PyTypeObject *type, PyObject *args,
        PyObject *keywordArgs);
static PyObject *pyoError_reduce(pyoError*);


//-----------------------------------------------------------------------------
// declaration of methods
//-----------------------------------------------------------------------------
static PyMethodDef pyoMethods[] = {
    { "__reduce__", (PyCFunction) pyoError_reduce, METH_NOARGS },
    { NULL, NULL }
};


//-----------------------------------------------------------------------------
// declaration of members
//-----------------------------------------------------------------------------
static PyMemberDef pyoStaticMembers[] = {
    { "code", T_LONG, offsetof(pyoError, code), READONLY },
    { "offset", T_UINT, offsetof(pyoError, offset), READONLY },
    { "message", T_OBJECT, offsetof(pyoError, message), READONLY },
    { "context", T_OBJECT, offsetof(pyoError, context), READONLY },
    { "isrecoverable", T_BOOL, offsetof(pyoError, isRecoverable), READONLY },
    { NULL }
};


//-----------------------------------------------------------------------------
// declaration of Python "_Error"
//-----------------------------------------------------------------------------
PyTypeObject pyoPyTypeError = {
    PyVarObject_HEAD_INIT(NULL, 0)
    .tp_name = "_oracledb._Error",
    .tp_basicsize = sizeof(pyoError),
    .tp_dealloc = (destructor) pyoError_free,
    .tp_str = (reprfunc) pyoError_str,
    .tp_flags = Py_TPFLAGS_DEFAULT,
    .tp_methods = pyoMethods,
    .tp_members = pyoStaticMembers,
    .tp_new = (newfunc) pyoError_new
};


//-----------------------------------------------------------------------------
// pyoError_free()
//   Deallocate the error.
//-----------------------------------------------------------------------------
static void pyoError_free(pyoError *error)
{
    Py_CLEAR(error->message);
    Py_CLEAR(error->context);
    PyObject_Del(error);
}


//-----------------------------------------------------------------------------
// pyoError_new()
//   Create a new error object. This is intended to only be used by the
// unpickling routine, and not by direct creation!
//-----------------------------------------------------------------------------
static PyObject *pyoError_new(PyTypeObject *type, PyObject *args,
        PyObject *keywordArgs)
{
    PyObject *message, *context;
    int isRecoverable, code;
    pyoError *error;
    unsigned offset;

    isRecoverable = 0;
    if (!PyArg_ParseTuple(args, "OiIO|i", &message, &code, &offset, &context,
            &isRecoverable))
        return NULL;
    error = (pyoError*) type->tp_alloc(type, 0);
    if (!error)
        return NULL;

    error->code = code;
    error->offset = offset;
    error->isRecoverable = (char) isRecoverable;
    Py_INCREF(message);
    error->message = message;
    Py_INCREF(context);
    error->context = context;

    return (PyObject*) error;
}


//-----------------------------------------------------------------------------
// pyoError_newFromInfo()
//   Internal method for creating an error object from the DPI error
// information.
//-----------------------------------------------------------------------------
pyoError *pyoError_newFromInfo(dpiErrorInfo *errorInfo)
{
    pyoError *error;

    // create error object and initialize it
    error = (pyoError*) pyoPyTypeError.tp_alloc(&pyoPyTypeError, 0);
    if (!error)
        return NULL;
    error->code = errorInfo->code;
    error->offset = errorInfo->offset;
    error->isRecoverable = (char) errorInfo->isRecoverable;

    // create message
    error->message = PyUnicode_Decode(errorInfo->message,
            errorInfo->messageLength, errorInfo->encoding, NULL);
    if (!error->message) {
        Py_DECREF(error);
        return NULL;
    }

    // create context composed of function name and action
#if PY_MAJOR_VERSION >= 3
    error->context = PyUnicode_FromFormat("%s: %s", errorInfo->fnName,
            errorInfo->action);
#else
    error->context = PyString_FromFormat("%s: %s", errorInfo->fnName,
            errorInfo->action);
#endif
    if (!error->context) {
        Py_DECREF(error);
        return NULL;
    }

    return error;
}


//-----------------------------------------------------------------------------
// pyoError_newFromString()
//   Internal method for creating an error object from the DPI error
// information.
//-----------------------------------------------------------------------------
static pyoError *pyoError_newFromString(const char *message)
{
    pyoError *error;

    error = (pyoError*) pyoPyTypeError.tp_alloc(&pyoPyTypeError, 0);
    if (!error)
        return NULL;
    Py_INCREF(Py_None);
    error->context = Py_None;
    error->message = PyUnicode_DecodeASCII(message, strlen(message), NULL);
    if (!error->message) {
        Py_DECREF(error);
        return NULL;
    }

    return error;
}


//-----------------------------------------------------------------------------
// pyoError_raiseAndReturnInt()
//   Internal method for raising an exception from an error generated from
// ODPI-C.  Returns -1 as a convenience to the caller.
//-----------------------------------------------------------------------------
int pyoError_raiseAndReturnInt(void)
{
    dpiErrorInfo errorInfo;

    dpiContext_getError(pyoDpiContext, &errorInfo);
    return pyoError_raiseFromInfo(&errorInfo);
}


//-----------------------------------------------------------------------------
// pyoError_raiseAndReturnNull()
//   Internal method for raising an exception from an error generated from
// ODPI-C.  Returns NULL as a convenience to the caller.
//-----------------------------------------------------------------------------
PyObject *pyoError_raiseAndReturnNull(void)
{
    pyoError_raiseAndReturnInt();
    return NULL;
}


//-----------------------------------------------------------------------------
// pyoError_raiseFromInfo()
//   Internal method for raising an exception given an error information
// structure from ODPI-C. Returns -1 as a convenience to the caller.
//-----------------------------------------------------------------------------
int pyoError_raiseFromInfo(dpiErrorInfo *errorInfo)
{
    PyObject *exceptionType;
    pyoError *error;

    error = pyoError_newFromInfo(errorInfo);
    if (!error)
        return -1;
    switch (errorInfo->code) {
        case 1:
        case 1400:
        case 2290:
        case 2291:
        case 2292:
            exceptionType = pyoIntegrityErrorException;
            break;
        case 22:
        case 378:
        case 602:
        case 603:
        case 604:
        case 609:
        case 1012:
        case 1013:
        case 1033:
        case 1034:
        case 1041:
        case 1043:
        case 1089:
        case 1090:
        case 1092:
        case 3113:
        case 3114:
        case 3122:
        case 3135:
        case 12153:
        case 12203:
        case 12500:
        case 12571:
        case 27146:
        case 28511:
            exceptionType = pyoOperationalErrorException;
            break;
        default:
            exceptionType = pyoDatabaseErrorException;
            break;
    }
    PyErr_SetObject(exceptionType, (PyObject*) error);
    Py_DECREF(error);
    return -1;
}


//-----------------------------------------------------------------------------
// pyoError_raiseFromString()
//   Internal method for raising an exception given a string. Returns -1 as a
// convenience to the caller.
//-----------------------------------------------------------------------------
PyObject *pyoError_raiseFromString(PyObject *exceptionType,
        const char *message)
{
    pyoError *error;

    error = pyoError_newFromString(message);
    if (!error)
        return NULL;
    PyErr_SetObject(exceptionType, (PyObject*) error);
    Py_DECREF(error);
    return NULL;
}


//-----------------------------------------------------------------------------
// pyoError_reduce()
//   Method provided for pickling/unpickling of error objects.
//-----------------------------------------------------------------------------
static PyObject *pyoError_reduce(pyoError *error)
{
    return Py_BuildValue("(O(OiIO))", Py_TYPE(error), error->message,
            error->code, error->offset, error->context);
}


//-----------------------------------------------------------------------------
// pyoError_str()
//   Return a string representation of the error object.
//-----------------------------------------------------------------------------
static PyObject *pyoError_str(pyoError *error)
{
    Py_INCREF(error->message);
    return error->message;
}

