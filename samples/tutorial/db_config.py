# ------------------------------------------------------------------------------
# Copyright (c) 2022, Oracle and/or its affiliates.
# ------------------------------------------------------------------------------

import oracledb
import os
import getpass

#
# Tutorial credentials and connection string.
# Environment variable values are used, if they are defined.
#

user = os.environ.get("PYTHON_USER", "pythondemo")

dsn = os.environ.get("PYTHON_CONNECT_STRING", "localhost/orclpdb")

pw = os.environ.get("PYTHON_PASSWORD")
if pw is None:
    pw = getpass.getpass("Enter password for %s: " % user)
