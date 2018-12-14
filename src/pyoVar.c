//-----------------------------------------------------------------------------
// Copyright (c) 2018, Oracle and/or its affiliates. All rights reserved.
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// pyoVar.c
//   Defines Python types for Oracle variables.
//-----------------------------------------------------------------------------

#include "pyoModule.h"

//-----------------------------------------------------------------------------
// Declaration of common variable functions.
//-----------------------------------------------------------------------------
static void pyoVar_free(pyoVar*);
static PyObject *pyoVar_repr(pyoVar*);
// static PyObject *pyoVar_externalCopy(pyoVar*, PyObject*);
// static PyObject *pyoVar_externalSetValue(pyoVar*, PyObject*);
// static PyObject *pyoVar_externalGetValue(pyoVar*, PyObject*, PyObject*);
// static PyObject *pyoVar_externalGetActualElements(pyoVar*, void*);
// static PyObject *pyoVar_externalGetValues(pyoVar*, void*);


//-----------------------------------------------------------------------------
// declaration of methods for variables
//-----------------------------------------------------------------------------
static PyMethodDef pyoMethods[] = {
//    { "copy", (PyCFunction) pyoVar_externalCopy, METH_VARARGS },
//    { "setvalue", (PyCFunction) pyoVar_externalSetValue, METH_VARARGS },
//    { "getvalue", (PyCFunction) pyoVar_externalGetValue,
//              METH_VARARGS  | METH_KEYWORDS },
    { NULL }
};


//-----------------------------------------------------------------------------
// declaration of members for variables
//-----------------------------------------------------------------------------
static PyMemberDef pyoStaticMembers[] = {
    { "bufferSize", T_INT, offsetof(pyoVar, bufferSize), READONLY },
    { "inconverter", T_OBJECT, offsetof(pyoVar, inConverter), 0 },
    { "numElements", T_INT, offsetof(pyoVar, allocatedElements),
            READONLY },
    { "outconverter", T_OBJECT, offsetof(pyoVar, outConverter), 0 },
    { "size", T_INT, offsetof(pyoVar, size), READONLY },
    { "type", T_OBJECT, offsetof(pyoVar, objectType), READONLY },
    { NULL }
};


//-----------------------------------------------------------------------------
// declaration of calculated members for variables
//-----------------------------------------------------------------------------
static PyGetSetDef pyoDynamicMembers[] = {
//    { "actualElements", (getter) pyoVar_externalGetActualElements, 0, 0, 0 },
//    { "values", (getter) pyoVar_externalGetValues, 0, 0, 0 },
    { NULL }
};

//-----------------------------------------------------------------------------
// declaration of all variable types
//-----------------------------------------------------------------------------
#define DECLARE_VARIABLE_TYPE(INTERNAL_NAME, EXTERNAL_NAME) \
    PyTypeObject INTERNAL_NAME = { \
        PyVarObject_HEAD_INIT(NULL, 0) \
        .tp_name = "oracledb." #EXTERNAL_NAME, \
        .tp_basicsize = sizeof(pyoVar), \
        .tp_dealloc = (destructor) pyoVar_free, \
        .tp_repr = (reprfunc) pyoVar_repr, \
        .tp_flags = Py_TPFLAGS_DEFAULT, \
        .tp_methods = pyoMethods, \
        .tp_members = pyoStaticMembers, \
        .tp_getset = pyoDynamicMembers \
    };

DECLARE_VARIABLE_TYPE(pyoPyTypeBfileVar, BFILE)
DECLARE_VARIABLE_TYPE(pyoPyTypeBinaryVar, BINARY)
DECLARE_VARIABLE_TYPE(pyoPyTypeBlobVar, BLOB)
DECLARE_VARIABLE_TYPE(pyoPyTypeBooleanVar, BOOLEAN)
DECLARE_VARIABLE_TYPE(pyoPyTypeClobVar, CLOB)
DECLARE_VARIABLE_TYPE(pyoPyTypeCursorVar, CURSOR)
DECLARE_VARIABLE_TYPE(pyoPyTypeDateTimeVar, DATETIME)
DECLARE_VARIABLE_TYPE(pyoPyTypeFixedCharVar, FIXED_CHAR)
DECLARE_VARIABLE_TYPE(pyoPyTypeFixedNcharVar, FIXED_NCHAR)
DECLARE_VARIABLE_TYPE(pyoPyTypeIntervalVar, INTERVAL)
DECLARE_VARIABLE_TYPE(pyoPyTypeLongBinaryVar, LONG_BINARY)
DECLARE_VARIABLE_TYPE(pyoPyTypeLongStringVar, LONG_STRING)
DECLARE_VARIABLE_TYPE(pyoPyTypeNativeFloatVar, NATIVE_FLOAT)
DECLARE_VARIABLE_TYPE(pyoPyTypeNativeIntVar, NATIVE_INT)
DECLARE_VARIABLE_TYPE(pyoPyTypeNcharVar, NCHAR)
DECLARE_VARIABLE_TYPE(pyoPyTypeNclobVar, NCLOB)
DECLARE_VARIABLE_TYPE(pyoPyTypeNumberVar, NUMBER)
DECLARE_VARIABLE_TYPE(pyoPyTypeObjectVar, OBJECT)
DECLARE_VARIABLE_TYPE(pyoPyTypeRowidVar, ROWID)
DECLARE_VARIABLE_TYPE(pyoPyTypeStringVar, STRING)
DECLARE_VARIABLE_TYPE(pyoPyTypeTimestampVar, TIMESTAMP)


//-----------------------------------------------------------------------------
// pyoVar_free()
//   Free an existing variable.
//-----------------------------------------------------------------------------
static void pyoVar_free(pyoVar *var)
{
    if (var->handle) {
        Py_BEGIN_ALLOW_THREADS
        dpiVar_release(var->handle);
        Py_END_ALLOW_THREADS
        var->handle = NULL;
    }
    if (var->encodingErrors)
        PyMem_Free((void*) var->encodingErrors);
    Py_CLEAR(var->connection);
    Py_CLEAR(var->inConverter);
    Py_CLEAR(var->outConverter);
    Py_CLEAR(var->objectType);
    Py_TYPE(var)->tp_free((PyObject*) var);
}

//-----------------------------------------------------------------------------
// pyoVar_repr()
//   Return a string representation of the variable.
//-----------------------------------------------------------------------------
static PyObject *pyoVar_repr(pyoVar *var)
{
    PyObject *value, *module, *name, *result;
//    uint32_t numElements;

#if 0
    if (var->isArray) {
        if (dpiVar_getNumElementsInArray(var->handle, &numElements) < 0)
            return pyoError_raiseAndReturnNull();
        value = pyoVar_getArrayValue(var, numElements, var->data);
    } else if (var->allocatedElements == 1)
        value = pyoVar_getSingleValue(var, NULL, 0);
    else value = pyoVar_getArrayValue(var, var->allocatedElements, NULL);
    if (!value)
        return NULL;
#endif
    value = Py_None;
    Py_INCREF(value);
    if (pyoUtils_getModuleAndName(Py_TYPE(var), &module, &name) < 0) {
        Py_DECREF(value);
        return NULL;
    }
    result = pyoUtils_formatString("<%s.%s with value %r>",
            PyTuple_Pack(3, module, name, value));
    Py_DECREF(module);
    Py_DECREF(name);
    Py_DECREF(value);
    return result;
}

