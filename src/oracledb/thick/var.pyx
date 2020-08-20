#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# var.pyx
#   Cython file defining the variable class (embedded in driver.pyx).
#------------------------------------------------------------------------------

cdef class Variable:
    cdef:
        dpiVar *_handle
        dpiData *_data
        Connection connection
        object inconverter
        object outconverter
        uint32_t allocated_elements
        uint32_t size
        uint32_t buffer_size
        bint is_array
        bint is_value_set
        bint get_returned_data
        uint32_t native_type_num
