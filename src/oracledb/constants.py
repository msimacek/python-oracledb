#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

from . import __version__ as VERSION

# mandated DB API constants
apilevel = "2.0"
threadsafety = 2
paramstyle = "named"

# basic configuration constants
DRIVER_NAME = "oracledb : " + VERSION
INSTALLATION_URL = "https://oracledb.readthedocs.io/en/" \
        "latest/user_guide/installation.html"
ENCODING = "UTF-8"
