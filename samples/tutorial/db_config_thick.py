# ------------------------------------------------------------------------------
# Copyright (c) 2022, Oracle and/or its affiliates.
# ------------------------------------------------------------------------------

import oracledb
import platform
import os
import getpass

######################################################################

#
# Oracle Client library configuration
#

# On Linux this must be None.
# Instead, the Oracle environment must be set before Python starts.
instant_client_dir = None

# On Windows, if your database is on the same machine, comment these lines out
# and let instant_client_dir be None.  Otherwise, set this to your Instant
# Client directory.  Note the use of the raw string r"..."  so backslashes can
# be used as directory separators.
if platform.system() == "Windows":
    instant_client_dir = r"C:\Oracle\instantclient_19_14"

# On macOS (Intel x86) set the directory to your Instant Client directory
if platform.system() == "Darwin":
    instant_client_dir = os.environ.get("HOME")+"/Downloads/instantclient_19_8"

# You must always call init_oracle_client() to use thick mode in any platform
# For Linux and UNIX systems
if instant_client_dir is None:
    oracledb.init_oracle_client()
# For Windows and macOS(Intel x86) platforms
else:
    oracledb.init_oracle_client(lib_dir=instant_client_dir)

######################################################################

#
# Tutorial credentials and connection string.
# Environment variable values are used, if they are defined.
#

user = os.environ.get("PYTHON_USER", "pythondemo")

dsn = os.environ.get("PYTHON_CONNECT_STRING", "localhost/orclpdb")

pw = os.environ.get("PYTHON_PASSWORD")
if pw is None:
    pw = getpass.getpass("Enter password for %s: " % user)
