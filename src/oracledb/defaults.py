#------------------------------------------------------------------------------
# Copyright (c) 2021, 2022, Oracle and/or its affiliates. All rights reserved.
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
