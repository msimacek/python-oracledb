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

import os

from . import constants

class Defaults:
    """
    Identifies the default values used by the driver.
    """
    __module__ = constants.MODULE_NAME

    def __init__(self) -> None:
        self.arraysize = 100
        self.stmtcachesize = 20
        self.config_dir = os.environ.get("TNS_ADMIN")
        self.fetch_lobs = True
        self.fetch_decimals = False
        self.prefetchrows = 2

defaults = Defaults()
