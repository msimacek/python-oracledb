//-----------------------------------------------------------------------------
// Copyright (c) 2018, Oracle and/or its affiliates. All rights reserved.
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// pyoUtils.c
//   Utility functions used in oracledb.
//-----------------------------------------------------------------------------

#include "pyoModule.h"

//-----------------------------------------------------------------------------
// pyoUtils_formatString()
//   Return a Python string formatted using the given format string and
// arguments. The arguments have a reference taken from them after they have
// been used (which should mean that they are destroyed).
//-----------------------------------------------------------------------------
PyObject *pyoUtils_formatString(const char *format, PyObject *args)
{
    PyObject *formatObj, *result;

    // assume that a NULL value for arguments implies building the arguments
    // failed and a Python exception has already been raised
    if (!args)
        return NULL;

    // convert string format to Python object
    formatObj = PyUnicode_DecodeASCII(format, strlen(format), NULL);
    if (!formatObj) {
        Py_DECREF(args);
        return NULL;
    }

    // create formatted result
    result = PyUnicode_Format(formatObj, args);
    Py_DECREF(args);
    Py_DECREF(formatObj);
    return result;
}


//-----------------------------------------------------------------------------
// pyoUtils_getModuleAndName()
//   Return the module and name for the type.
//-----------------------------------------------------------------------------
int pyoUtils_getModuleAndName(PyTypeObject *type, PyObject **module,
        PyObject **name)
{
    *module = PyObject_GetAttrString( (PyObject*) type, "__module__");
    if (!*module)
        return -1;
    *name = PyObject_GetAttrString( (PyObject*) type, "__name__");
    if (!*name) {
        Py_DECREF(*module);
        return -1;
    }
    return 0;
}


//-----------------------------------------------------------------------------
// pyoUtils_initializeDPI()
//   Initialize the ODPI-C library. This is done when the first standalone
// connection or session pool is created, rather than when the module is first
// imported so that manipulating environment variables such as NLS_LANG will
// work as expected. It also has the additional benefit of reducing the number
// of errors that can take place when the module is imported.
//-----------------------------------------------------------------------------
int pyoUtils_initializeDPI(void)
{
    dpiErrorInfo errorInfo;
    dpiContext *context;

    if (!pyoDpiContext) {
        if (dpiContext_create(DPI_MAJOR_VERSION, DPI_MINOR_VERSION,
                &context, &errorInfo) < 0)
            return pyoError_raiseFromInfo(&errorInfo);
        if (dpiContext_getClientVersion(context, &pyoClientVersionInfo) < 0)
            return pyoError_raiseAndReturnInt();
        pyoDpiContext = context;
    }

    return 0;
}

