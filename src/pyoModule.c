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
// PyInit__oracledb()
//   Initialization routine for the module.
//-----------------------------------------------------------------------------
PyMODINIT_FUNC PyInit__oracledb(void)
{
    // this function no longer needs to be called once Python 3.7 is the
    // minimum version supported
    PyEval_InitThreads();

    // create module object
    return PyModule_Create(&pyoModuleDef);
}

