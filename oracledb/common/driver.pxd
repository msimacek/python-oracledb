#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

from libc.stdint cimport int32_t

cdef class Connection:
    cdef readonly str user
    cdef readonly str dsn

cdef object get_exception_class(int32_t code)
