//-----------------------------------------------------------------------------
// Copyright (c) 2018, Oracle and/or its affiliates. All rights reserved.
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// pyoCursor.c
//   Definition of the Python type Cursor.
//-----------------------------------------------------------------------------

#include "pyoModule.h"

//-----------------------------------------------------------------------------
// functions for the Python type "Cursor"
//-----------------------------------------------------------------------------
static void pyoCursor_free(pyoCursor*);
// static PyObject *pyoCursor_getIter(pyoCursor*);
// static PyObject *pyoCursor_getNext(pyoCursor*);
// static PyObject *pyoCursor_close(pyoCursor*, PyObject*);
// static PyObject *pyoCursor_callFunc(pyoCursor*, PyObject*, PyObject*);
// static PyObject *pyoCursor_callProc(pyoCursor*, PyObject*, PyObject*);
// static PyObject *pyoCursor_execute(pyoCursor*, PyObject*, PyObject*);
// static PyObject *pyoCursor_executeMany(pyoCursor*, PyObject*, PyObject*);
// static PyObject *pyoCursor_fetchOne(pyoCursor*, PyObject*);
// static PyObject *pyoCursor_fetchMany(pyoCursor*, PyObject*, PyObject*);
// static PyObject *pyoCursor_fetchAll(pyoCursor*, PyObject*);
// static PyObject *pyoCursor_fetchRaw(pyoCursor*, PyObject*, PyObject*);
// static PyObject *pyoCursor_parse(pyoCursor*, PyObject*);
// static PyObject *pyoCursor_prepare(pyoCursor*, PyObject*);
// static PyObject *pyoCursor_scroll(pyoCursor*, PyObject*, PyObject*);
// static PyObject *pyoCursor_setInputSizes(pyoCursor*, PyObject*, PyObject*);
// static PyObject *pyoCursor_setOutputSize(pyoCursor*, PyObject*);
// static PyObject *pyoCursor_var(pyoCursor*, PyObject*, PyObject*);
// static PyObject *pyoCursor_arrayVar(pyoCursor*, PyObject*);
// static PyObject *pyoCursor_bindNames(pyoCursor*, PyObject*);
// static PyObject *pyoCursor_getDescription(pyoCursor*, void*);
static PyObject *pyoCursor_new(PyTypeObject*, PyObject*, PyObject*);
// static int pyoCursor_init(pyoCursor*, PyObject*, PyObject*);
static PyObject *pyoCursor_repr(pyoCursor*);
// static PyObject* pyoCursor_getBatchErrors(pyoCursor*);
// static PyObject *pyoCursor_getArrayDMLRowCounts(pyoCursor*);
// static PyObject *pyoCursor_getImplicitResults(pyoCursor*);
// static PyObject *pyoCursor_contextManagerEnter(pyoCursor*, PyObject*);
// static PyObject *pyoCursor_contextManagerExit(pyoCursor*, PyObject*);
// static int pyoCursor_performDefine(pyoCursor*, uint32_t);

//-----------------------------------------------------------------------------
// declaration of methods for Python type "Cursor"
//-----------------------------------------------------------------------------
static PyMethodDef pyoMethods[] = {
//    { "execute", (PyCFunction) pyoCursor_execute,
//            METH_VARARGS | METH_KEYWORDS },
//    { "fetchall", (PyCFunction) pyoCursor_fetchAll, METH_NOARGS },
//    { "fetchone", (PyCFunction) pyoCursor_fetchOne, METH_NOARGS },
//    { "fetchmany", (PyCFunction) pyoCursor_fetchMany,
//              METH_VARARGS | METH_KEYWORDS },
//    { "fetchraw", (PyCFunction) pyoCursor_fetchRaw,
//              METH_VARARGS | METH_KEYWORDS },
//    { "prepare", (PyCFunction) pyoCursor_prepare, METH_VARARGS },
//    { "parse", (PyCFunction) pyoCursor_parse, METH_O },
//    { "setinputsizes", (PyCFunction) pyoCursor_setInputSizes,
//              METH_VARARGS | METH_KEYWORDS },
//    { "executemany", (PyCFunction) pyoCursor_executeMany,
//              METH_VARARGS | METH_KEYWORDS },
//    { "callproc", (PyCFunction) pyoCursor_callProc,
//              METH_VARARGS  | METH_KEYWORDS },
//    { "callfunc", (PyCFunction) pyoCursor_callFunc,
//              METH_VARARGS  | METH_KEYWORDS },
//    { "setoutputsize", (PyCFunction) pyoCursor_setOutputSize, METH_VARARGS },
//    { "scroll", (PyCFunction) pyoCursor_scroll, METH_VARARGS | METH_KEYWORDS },
//    { "var", (PyCFunction) pyoCursor_var, METH_VARARGS | METH_KEYWORDS },
//    { "arrayvar", (PyCFunction) pyoCursor_arrayVar, METH_VARARGS },
//    { "bindnames", (PyCFunction) pyoCursor_bindNames, METH_NOARGS },
//    { "close", (PyCFunction) pyoCursor_close, METH_NOARGS },
//    { "getbatcherrors", (PyCFunction) pyoCursor_getBatchErrors, METH_NOARGS },
//    { "getarraydmlrowcounts", (PyCFunction) pyoCursor_getArrayDMLRowCounts,
//              METH_NOARGS },
//    { "getimplicitresults", (PyCFunction) pyoCursor_getImplicitResults,
//              METH_NOARGS },
//    { "__enter__", (PyCFunction) pyoCursor_contextManagerEnter, METH_NOARGS },
//    { "__exit__", (PyCFunction) pyoCursor_contextManagerExit, METH_VARARGS },
    { NULL, NULL }
};


//-----------------------------------------------------------------------------
// declaration of static members for Python type "Cursor"
//-----------------------------------------------------------------------------
static PyMemberDef pyoStaticMembers[] = {
    { "arraysize", T_UINT, offsetof(pyoCursor, arraySize), 0 },
    { "bindarraysize", T_UINT, offsetof(pyoCursor, bindArraySize), 0 },
    { "rowcount", T_ULONGLONG, offsetof(pyoCursor, rowCount), READONLY },
    { "statement", T_OBJECT, offsetof(pyoCursor, statement), READONLY },
    { "connection", T_OBJECT_EX, offsetof(pyoCursor, connection), READONLY },
    { "rowfactory", T_OBJECT, offsetof(pyoCursor, rowFactory), 0 },
    { "bindvars", T_OBJECT, offsetof(pyoCursor, bindVariables), READONLY },
    { "fetchvars", T_OBJECT, offsetof(pyoCursor, fetchVariables), READONLY },
    { "inputtypehandler", T_OBJECT, offsetof(pyoCursor, inputTypeHandler),
            0 },
    { "outputtypehandler", T_OBJECT, offsetof(pyoCursor, outputTypeHandler),
            0 },
    { "scrollable", T_BOOL, offsetof(pyoCursor, isScrollable), 0 },
    { NULL }
};


//-----------------------------------------------------------------------------
// declaration of dynamic members for Python type "Cursor"
//-----------------------------------------------------------------------------
static PyGetSetDef pyoDynamicMembers[] = {
//    { "description", (getter) pyoCursor_getDescription, 0, 0, 0 },
    { NULL }
};


//-----------------------------------------------------------------------------
// declaration of Python type "Cursor"
//-----------------------------------------------------------------------------
PyTypeObject pyoPyTypeCursor = {
    PyVarObject_HEAD_INIT(NULL, 0)
    .tp_name = "oracledb.Cursor",
    .tp_basicsize = sizeof(pyoCursor),
    .tp_dealloc = (destructor) pyoCursor_free,
    .tp_repr = (reprfunc) pyoCursor_repr,
    .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
//    .tp_iter = (getiterfunc) pyoCursor_getIter,
//    .tp_iternext = (iternextfunc) pyoCursor_getNext,
    .tp_methods = pyoMethods,
    .tp_members = pyoStaticMembers,
    .tp_getset = pyoDynamicMembers,
//    .tp_init = (initproc) pyoCursor_init,
    .tp_new = (newfunc) pyoCursor_new
};


//-----------------------------------------------------------------------------
// pyoCursor_new()
//   Create a new cursor object.
//-----------------------------------------------------------------------------
static PyObject *pyoCursor_new(PyTypeObject *type, PyObject *args,
        PyObject *keywordArgs)
{
    return type->tp_alloc(type, 0);
}


//-----------------------------------------------------------------------------
// pyoCursor_repr()
//   Return a string representation of the cursor.
//-----------------------------------------------------------------------------
static PyObject *pyoCursor_repr(pyoCursor *cursor)
{
    PyObject *connectionRepr, *module, *name, *result;

    connectionRepr = PyObject_Repr((PyObject*) cursor->connection);
    if (!connectionRepr)
        return NULL;
    if (pyoUtils_getModuleAndName(Py_TYPE(cursor), &module, &name) < 0) {
        Py_DECREF(connectionRepr);
        return NULL;
    }
    result = pyoUtils_formatString("<%s.%s on %s>",
            PyTuple_Pack(3, module, name, connectionRepr));
    Py_DECREF(module);
    Py_DECREF(name);
    Py_DECREF(connectionRepr);
    return result;
}


//-----------------------------------------------------------------------------
// pyoCursor_free()
//   Deallocate the cursor.
//-----------------------------------------------------------------------------
static void pyoCursor_free(pyoCursor *cursor)
{
    Py_CLEAR(cursor->statement);
    Py_CLEAR(cursor->statementTag);
    Py_CLEAR(cursor->bindVariables);
    Py_CLEAR(cursor->fetchVariables);
    if (cursor->handle) {
        dpiStmt_release(cursor->handle);
        cursor->handle = NULL;
    }
    Py_CLEAR(cursor->connection);
    Py_CLEAR(cursor->rowFactory);
    Py_CLEAR(cursor->inputTypeHandler);
    Py_CLEAR(cursor->outputTypeHandler);
    Py_TYPE(cursor)->tp_free((PyObject*) cursor);
}

