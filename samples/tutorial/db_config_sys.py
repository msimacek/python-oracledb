# ------------------------------------------------------------------------------
# Copyright (c) 2022, Oracle and/or its affiliates.
# ------------------------------------------------------------------------------

import oracledb
import os
import getpass

#
# Tutorial credentials and connection string for the SYSTEM (ADMIN) user.
# Environment variable values are used, if they are defined.
#

sysuser = os.environ.get("PYTHON_SYSUSER", "SYSTEM")

dsn = os.environ.get("PYTHON_SYS_CONNECT_STRING", "localhost/orclpdb")

syspw = os.environ.get("PYTHON_SYSPASSWORD")
if syspw is None:
    syspw = getpass.getpass("Enter password for %s: " % sysuser)
