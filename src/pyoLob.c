//-----------------------------------------------------------------------------
// Copyright (c) 2018, Oracle and/or its affiliates. All rights reserved.
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// pyoLob.c
//   Defines the routines for handling LOB values.
//-----------------------------------------------------------------------------

#include "pyoModule.h"

//-----------------------------------------------------------------------------
// Declaration of external LOB functions.
//-----------------------------------------------------------------------------
static void pyoLob_free(pyoLob*);
// static PyObject *pyoLob_str(pyoLob*);
// static PyObject *pyoLob_size(pyoLob*, PyObject*);
// static PyObject *pyoLob_open(pyoLob*, PyObject*);
// static PyObject *pyoLob_close(pyoLob*, PyObject*);
// static PyObject *pyoLob_read(pyoLob*, PyObject*, PyObject*);
// static PyObject *pyoLob_write(pyoLob*, PyObject*, PyObject*);
// static PyObject *pyoLob_trim(pyoLob*, PyObject*, PyObject*);
// static PyObject *pyoLob_getChunkSize(pyoLob*, PyObject*);
// static PyObject *pyoLob_isOpen(pyoLob*, PyObject*);
// static PyObject *pyoLob_getFileName(pyoLob*, PyObject*);
// static PyObject *pyoLob_setFileName(pyoLob*, PyObject*);
// static PyObject *pyoLob_fileExists(pyoLob*, PyObject*);
// static PyObject *pyoLob_reduce(pyoLob*);


//-----------------------------------------------------------------------------
// declaration of methods for Python type "LOB"
//-----------------------------------------------------------------------------
static PyMethodDef pyoMethods[] = {
//    { "size", (PyCFunction) pyoLob_size, METH_NOARGS },
//    { "open", (PyCFunction) pyoLob_open, METH_NOARGS },
//    { "close", (PyCFunction) pyoLob_close, METH_NOARGS },
//    { "read", (PyCFunction) pyoLob_read, METH_VARARGS | METH_KEYWORDS },
//    { "write", (PyCFunction) pyoLob_write, METH_VARARGS | METH_KEYWORDS },
//    { "trim", (PyCFunction) pyoLob_trim, METH_VARARGS | METH_KEYWORDS },
//    { "getchunksize", (PyCFunction) pyoLob_getChunkSize, METH_NOARGS },
//    { "isopen", (PyCFunction) pyoLob_isOpen, METH_NOARGS },
//    { "getfilename", (PyCFunction) pyoLob_getFileName, METH_NOARGS },
//    { "setfilename", (PyCFunction) pyoLob_setFileName, METH_VARARGS },
//    { "fileexists", (PyCFunction) pyoLob_fileExists, METH_NOARGS },
//    { "__reduce__", (PyCFunction) pyoLob_reduce, METH_NOARGS },
    { NULL, NULL }
};


//-----------------------------------------------------------------------------
// declaration of the Python type "LOB"
//-----------------------------------------------------------------------------
PyTypeObject pyoPyTypeLob = {
    PyVarObject_HEAD_INIT(NULL, 0)
    .tp_name = "oracledb.LOB",
    .tp_basicsize = sizeof(pyoLob),
    .tp_dealloc = (destructor) pyoLob_free,
//    .tp_str = (reprfunc) pyoLob_str,
    .tp_flags = Py_TPFLAGS_DEFAULT,
    .tp_methods = pyoMethods
};


//-----------------------------------------------------------------------------
// pyoLob_free()
//   Free a LOB.
//-----------------------------------------------------------------------------
static void pyoLob_free(pyoLob *lob)
{
    if (lob->handle) {
        dpiLob_release(lob->handle);
        lob->handle = NULL;
    }
    Py_CLEAR(lob->connection);
    Py_TYPE(lob)->tp_free((PyObject*) lob);
}


//-----------------------------------------------------------------------------
// pyoLob_new()
//   Create a new LOB.
//-----------------------------------------------------------------------------
PyObject *pyoLob_new(pyoConnection *connection, dpiOracleTypeNum oracleTypeNum,
        dpiLob *handle)
{
    pyoLob *lob;

    lob = (pyoLob*) pyoPyTypeLob.tp_alloc(&pyoPyTypeLob, 0);
    if (!lob)
        return NULL;
    lob->handle = handle;
    lob->oracleTypeNum = oracleTypeNum;
    Py_INCREF(connection);
    lob->connection = connection;
    return (PyObject*) lob;
}

