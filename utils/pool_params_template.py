#------------------------------------------------------------------------------
# Copyright (c) 2022, Oracle and/or its affiliates.
# This program is free software: you can modify it and/or redistribute it
# under the terms of:
#
# (i)  the Universal Permissive License v 1.0 or at your option, any
#      later version (http://oss.oracle.com/licenses/upl); and/or
#
# (ii) the Apache License v 2.0. (http://www.apache.org/licenses/LICENSE-2.0)
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# pool_params.py
#
# Contains the PoolParams class used for managing the parameters required to
# create a connection pool.
#
#{{ generated_notice }}
#------------------------------------------------------------------------------

from typing import Callable, Type, Union

import oracledb

from . import base_impl, constants, errors, utils
from . import connection as connection_module
from .connect_params import ConnectParams

class PoolParams(ConnectParams):
    """
    Contains all parameters used for creating a connection pool.
    """
    __module__ = constants.MODULE_NAME
    __slots__ = ["_impl"]
    _impl_class = base_impl.PoolParamsImpl

#{{ __init__ }}

#{{ __repr__ }}

#{{ properties }}

    def copy(self) -> Type["PoolParams"]:
        """
        Creates a copy of the parameters and returns it.
        """
        params = PoolParams.__new__(PoolParams)
        params._impl = self._impl.copy()
        return params

#{{ set }}
