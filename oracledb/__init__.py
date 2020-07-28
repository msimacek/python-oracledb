#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

__version__ = "0.0.1"

from .constants import *
from .connection import connect

from .thick.driver import init_oracle_client
