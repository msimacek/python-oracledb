//-----------------------------------------------------------------------------
// Copyright (c) 2018, Oracle and/or its affiliates. All rights reserved.
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// pyoObject.c
//   Defines the routines for handling objects in Oracle.
//-----------------------------------------------------------------------------

#include "pyoModule.h"

//-----------------------------------------------------------------------------
// functions for the Python type "Object"
//-----------------------------------------------------------------------------
static void pyoObject_free(pyoObject*);
// static PyObject *pyoObject_getAttr(pyoObject*, PyObject*);
static PyObject *pyoObject_repr(pyoObject*);
// static int pyoObject_setAttr(pyoObject*, PyObject*, PyObject*);
// static PyObject *pyoObject_append(pyoObject*, PyObject*);
// static PyObject *pyoObject_asDict(pyoObject*, PyObject*);
// static PyObject *pyoObject_asList(pyoObject*, PyObject*);
// static PyObject *pyoObject_copy(pyoObject*, PyObject*);
// static PyObject *pyoObject_delete(pyoObject*, PyObject*);
// static PyObject *pyoObject_exists(pyoObject*, PyObject*);
// static PyObject *pyoObject_extend(pyoObject*, PyObject*);
// static PyObject *pyoObject_getElement(pyoObject*, PyObject*);
// static PyObject *pyoObject_getFirstIndex(pyoObject*, PyObject*);
// static PyObject *pyoObject_getLastIndex(pyoObject*, PyObject*);
// static PyObject *pyoObject_getNextIndex(pyoObject*, PyObject*);
// static PyObject *pyoObject_getPrevIndex(pyoObject*, PyObject*);
// static PyObject *pyoObject_getSize(pyoObject*, PyObject*);
// static PyObject *pyoObject_setElement(pyoObject*, PyObject*);
// static PyObject *pyoObject_trim(pyoObject*, PyObject*);


//-----------------------------------------------------------------------------
// declaration of methods for Python type "Object"
//-----------------------------------------------------------------------------
static PyMethodDef pyoMethods[] = {
//    { "append", (PyCFunction) pyoObject_append, METH_O },
//    { "asdict", (PyCFunction) pyoObject_asDict, METH_NOARGS },
//    { "aslist", (PyCFunction) pyoObject_asList, METH_NOARGS },
//    { "copy", (PyCFunction) pyoObject_copy, METH_NOARGS },
//    { "delete", (PyCFunction) pyoObject_delete, METH_VARARGS },
//    { "exists", (PyCFunction) pyoObject_exists, METH_VARARGS },
//    { "extend", (PyCFunction) pyoObject_extend, METH_O },
//    { "first", (PyCFunction) pyoObject_getFirstIndex, METH_NOARGS },
//    { "getelement", (PyCFunction) pyoObject_getElement, METH_VARARGS },
//    { "last", (PyCFunction) pyoObject_getLastIndex, METH_NOARGS },
//    { "next", (PyCFunction) pyoObject_getNextIndex, METH_VARARGS },
//    { "prev", (PyCFunction) pyoObject_getPrevIndex, METH_VARARGS },
//    { "setelement", (PyCFunction) pyoObject_setElement, METH_VARARGS },
//    { "size", (PyCFunction) pyoObject_getSize, METH_NOARGS },
//    { "trim", (PyCFunction) pyoObject_trim, METH_VARARGS },
    { NULL, NULL }
};


//-----------------------------------------------------------------------------
// declaration of static members for Python type "Object".
//-----------------------------------------------------------------------------
static PyMemberDef pyoStaticMembers[] = {
    { "type", T_OBJECT, offsetof(pyoObject, objectType), READONLY },
    { NULL }
};


//-----------------------------------------------------------------------------
// declaration of the Python type "Object"
//-----------------------------------------------------------------------------
PyTypeObject pyoPyTypeObject = {
    PyVarObject_HEAD_INIT(NULL, 0)
    .tp_name = "oracledb.Object",
    .tp_basicsize = sizeof(pyoObject),
    .tp_dealloc = (destructor) pyoObject_free,
    .tp_repr = (reprfunc) pyoObject_repr,
//    .tp_getattro = (getattrofunc) pyoObject_getAttr,
//    .tp_setattro = (setattrofunc) pyoObject_setAttr,
    .tp_flags = Py_TPFLAGS_DEFAULT,
    .tp_methods = pyoMethods,
    .tp_members = pyoStaticMembers
};


//-----------------------------------------------------------------------------
// pyoObject_free()
//   Free an object.
//-----------------------------------------------------------------------------
static void pyoObject_free(pyoObject *obj)
{
    if (obj->handle) {
        dpiObject_release(obj->handle);
        obj->handle = NULL;
    }
    Py_CLEAR(obj->objectType);
    Py_TYPE(obj)->tp_free((PyObject*) obj);
}


//-----------------------------------------------------------------------------
// pyoObject_repr()
//   Return a string representation of the object.
//-----------------------------------------------------------------------------
static PyObject *pyoObject_repr(pyoObject *obj)
{
    PyObject *module, *name, *result;

    if (pyoUtils_getModuleAndName(Py_TYPE(obj), &module, &name) < 0)
        return NULL;
    result = pyoUtils_formatString("<%s.%s %s.%s at %#x>",
            Py_BuildValue("(OOOOl)", module, name, obj->objectType->schema,
                    obj->objectType->name, obj));
    Py_DECREF(module);
    Py_DECREF(name);
    return result;
}


//-----------------------------------------------------------------------------
// pyoObject_new()
//   Create a new object.
//-----------------------------------------------------------------------------
PyObject *pyoObject_new(pyoObjectType *objectType, dpiObject *handle)
{
    pyoObject *obj;

    obj = (pyoObject*) pyoPyTypeObject.tp_alloc(&pyoPyTypeObject, 0);
    if (!obj)
        return NULL;
    Py_INCREF(objectType);
    obj->objectType = objectType;
    obj->handle = handle;
    return (PyObject*) obj;
}

