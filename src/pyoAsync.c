//-----------------------------------------------------------------------------
// Copyright (c) 2018, Oracle and/or its affiliates. All rights reserved.
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// pyoAsync.c
//   Defines structures for performing asynchronous methods.
//-----------------------------------------------------------------------------

#include "pyoModule.h"

//-----------------------------------------------------------------------------
// pyoAsync_allocateData()
//   Allocate data for asynchronous operations.
//-----------------------------------------------------------------------------
int pyoAsync_allocateData(pyoAsyncDataType *dataType, PyObject *loopObj,
        PyObject *futureObj, void **data)
{
    pyoAsyncBaseData *baseData;

    baseData = PyMem_Calloc(1, dataType->structSize);
    if (!baseData) {
        PyErr_NoMemory();
        return -1;
    }
    baseData->loopObj = loopObj;
    baseData->futureObj = futureObj;
    baseData->dataType = dataType;
    *data = baseData;
    return 0;
}


//-----------------------------------------------------------------------------
// pyoAsync_callback()
//   Callback that is executed when the asynchronous function completes. After
// the future has been marked complete, the data is freed.
//-----------------------------------------------------------------------------
void pyoAsync_callback(void *arg, int status, dpiErrorInfo *errorInfo)
{
    PyObject *result, *excType, *excValue, *excTraceback, *temp, *callable;
    pyoAsyncBaseData *data = (pyoAsyncBaseData*) arg;

#ifdef WITH_THREAD
    PyGILState_STATE gstate = PyGILState_Ensure();
#endif

    // if successful, call the associated function to get the result value, if
    // one has been specified
    if (status == DPI_SUCCESS) {
        if (data->dataType->getResultProc) {
            result = (*data->dataType->getResultProc)(arg);
        } else {
            Py_INCREF(Py_None);
            result = Py_None;
        }

    // otherwise, raise an exception
    } else {
        result = NULL;
        pyoError_raiseFromInfo(errorInfo);
    }

    // if successful, set the future result
    if (result) {
        callable = PyObject_GetAttr(data->futureObj, pyoSetResultName);
        if (callable) {
            temp = PyObject_CallMethodObjArgs(data->loopObj,
                    pyoCallSoonThreadsafeName, callable, result, NULL);
            Py_CLEAR(callable);
            Py_CLEAR(temp);
        }
        Py_CLEAR(result);
    }

    // if an error occurred, set the future exception
    // if that fails (which should never happen), print error as otherwise it
    // will be silently swallowed
    if (PyErr_Occurred()) {
        PyErr_Fetch(&excType, &excValue, &excTraceback);
        PyErr_NormalizeException(&excType, &excValue, &excTraceback);
        callable = PyObject_GetAttr(data->futureObj, pyoSetExceptionName);
        if (!callable) {
            PyErr_Print();
        } else {
            temp = PyObject_CallMethodObjArgs(data->loopObj,
                    pyoCallSoonThreadsafeName, callable, excValue, NULL);
            if (!temp)
                PyErr_Print();
            Py_CLEAR(callable);
            Py_CLEAR(temp);
        }
        Py_CLEAR(excType);
        Py_CLEAR(excValue);
        Py_CLEAR(excTraceback);
    }

    // free the data associated with the asynchronous function
    pyoAsync_freeData(arg);

#ifdef WITH_THREAD
    PyGILState_Release(gstate);
#endif
}


//-----------------------------------------------------------------------------
// pyoAsync_freeData()
//   Frees the asynchronous data structure. This is called automatically by the
// callback registered for the asynchronous function but may also be called
// when initialization of the structure fails for some reason. NULL is returned
// as a convenience to the caller.
//-----------------------------------------------------------------------------
PyObject *pyoAsync_freeData(void *arg)
{
    pyoAsyncBaseData *data = (pyoAsyncBaseData*) arg;

    if (data->dataType->freeDataProc)
        (*data->dataType->freeDataProc)(arg);
    PyMem_Free(arg);
    return NULL;
}


//-----------------------------------------------------------------------------
// pyoAsync_run()
//   Runs the asynchronous procedure.
//-----------------------------------------------------------------------------
int pyoAsync_run(void *arg)
{
    pyoAsyncBaseData *data = (pyoAsyncBaseData*) arg;

    if (dpiContext_runAsync(pyoDpiContext, data->dataType->runProc,
            pyoAsync_callback, arg, DPI_MODE_ASYNC_CPU_BOUND, 0,
            &data->handle) < 0) {
        pyoAsync_freeData(arg);
        pyoError_raiseAndReturnInt();
        return -1;
    }

    return 0;
}

