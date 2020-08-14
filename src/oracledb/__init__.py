#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

from .version import __version__
from .constants import *
from .exceptions import *
from .connection import connect

from .thick.driver import init_oracle_client
