//-----------------------------------------------------------------------------
// Copyright (c) 2018, Oracle and/or its affiliates. All rights reserved.
//
// Portions Copyright 2007-2015, Anthony Tuininga. All rights reserved.
//
// Portions Copyright 2001-2007, Computronix (Canada) Ltd., Edmonton, Alberta,
// Canada. All rights reserved.
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// pyoSessionPool.c
//   Handles session pooling.
//-----------------------------------------------------------------------------

#include "pyoModule.h"

//-----------------------------------------------------------------------------
// functions for the Python type "SessionPool"
//-----------------------------------------------------------------------------
static PyObject *pyoSessionPool_new(PyTypeObject*, PyObject*, PyObject*);
static void pyoSessionPool_free(pyoSessionPool*);


//-----------------------------------------------------------------------------
// declaration of methods for Python type "SessionPool"
//-----------------------------------------------------------------------------
static PyMethodDef pyoMethods[] = {
    { NULL }
};


//-----------------------------------------------------------------------------
// declaration of static members for Python type "SessionPool"
//-----------------------------------------------------------------------------
static PyMemberDef pyoStaticMembers[] = {
    { "username", T_OBJECT, offsetof(pyoSessionPool, username), READONLY },
    { "dsn", T_OBJECT, offsetof(pyoSessionPool, dsn), READONLY },
    { "name", T_OBJECT, offsetof(pyoSessionPool, name), READONLY },
    { "max", T_INT, offsetof(pyoSessionPool, maxSessions), READONLY },
    { "min", T_INT, offsetof(pyoSessionPool, minSessions), READONLY },
    { "increment", T_INT, offsetof(pyoSessionPool, sessionIncrement),
            READONLY },
    { "homogeneous", T_INT, offsetof(pyoSessionPool, homogeneous), READONLY },
    { NULL }
};


//-----------------------------------------------------------------------------
// declaration of dynamic members for Python type "SessionPool"
//-----------------------------------------------------------------------------
static PyGetSetDef pyoDynamicMembers[] = {
    { NULL }
};


//-----------------------------------------------------------------------------
// declaration of Python type "SessionPool"
//-----------------------------------------------------------------------------
PyTypeObject pyoPyTypeSessionPool = {
    PyVarObject_HEAD_INIT(NULL, 0)
    .tp_name = "oracledb.SessionPool",
    .tp_basicsize = sizeof(pyoSessionPool),
    .tp_dealloc = (destructor) pyoSessionPool_free,
    .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
    .tp_methods = pyoMethods,
    .tp_members = pyoStaticMembers,
    .tp_getset = pyoDynamicMembers,
    .tp_new = (newfunc) pyoSessionPool_new
};


//-----------------------------------------------------------------------------
// pyoSessionPool_new()
//   Create a new session pool object.
//-----------------------------------------------------------------------------
static PyObject *pyoSessionPool_new(PyTypeObject *type, PyObject *args,
        PyObject *keywordArgs)
{
    return type->tp_alloc(type, 0);
}


//-----------------------------------------------------------------------------
// pyoSessionPool_free()
//   Deallocate the session pool.
//-----------------------------------------------------------------------------
static void pyoSessionPool_free(pyoSessionPool *pool)
{
    if (pool->handle) {
        dpiPool_release(pool->handle);
        pool->handle = NULL;
    }
    Py_CLEAR(pool->username);
    Py_CLEAR(pool->dsn);
    Py_CLEAR(pool->name);
    Py_TYPE(pool)->tp_free((PyObject*) pool);
}

