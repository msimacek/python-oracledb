#------------------------------------------------------------------------------
# Copyright (c) 2021, 2022, Oracle and/or its affiliates.
# This program is free software: you can modify it and/or redistribute it
# under the terms of:
#
# (i)  the Universal Permissive License v 1.0 or at your option, any
#      later version (http://oss.oracle.com/licenses/upl); and/or
#
# (ii) the Apache License v 2.0. (http://www.apache.org/licenses/LICENSE-2.0)
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# connect_params.py
#
# Contains the ConnectParams class used for managing the parameters required to
# establish a connection to the database.
#
#{{ generated_notice }}
#------------------------------------------------------------------------------

from typing import Type, Union

import oracledb

from . import base_impl, constants, errors, utils

class ConnectParams:
    """
    Contains all parameters used for establishing a connection to the
    database.
    """
    __module__ = constants.MODULE_NAME
    __slots__ = ["_impl"]
    _impl_class = base_impl.ConnectParamsImpl

#{{ __init__ }}

#{{ __repr__ }}

    def _address_attr(f):
        """
        Helper function used to get address level attributes.
        """
        def wrapped_func(self):
            output = []
            for description in self._impl.description_list.descriptions:
                for address_list in description.address_lists:
                    for address in address_list.addresses:
                        output.append(getattr(address, f.__name__))
            return output if len(output) > 1 else output[0]
        return wrapped_func

    def _description_attr(f):
        """
        Helper function used to get description level attributes.
        """
        def wrapped_func(self):
            output = []
            for description in self._impl.description_list.descriptions:
                output.append(getattr(description, f.__name__))
            return output if len(output) > 1 else output[0]
        return wrapped_func

#{{ properties }}

    def copy(self) -> Type["ConnectParams"]:
        """
        Creates a copy of the parameters and returns it.
        """
        params = ConnectParams.__new__(ConnectParams)
        params._impl = self._impl.copy()
        return params

    def get_connect_string(self) -> str:
        """
        Returns a connect string generated from the parameters.
        """
        return self._impl.get_connect_string()

    def parse_connect_string(self, connect_string: str) -> None:
        """
        Parses the connect string into its components and stores the
        parameters.  The connect string could be an Easy Connect string,
        name-value pairs or a simple alias which is looked up in tnsnames.ora.
        Any parameters found in the connect string override any currently
        stored values.
        """
        self._impl.parse_connect_string(connect_string)

#{{ set }}
