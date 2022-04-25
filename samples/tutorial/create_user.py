# ------------------------------------------------------------------------------
# create_user.py (Setup Section)
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Copyright (c) 2022, Oracle and/or its affiliates.
# ------------------------------------------------------------------------------
import oracledb
import db_config_sys
import run_sql_script
import getpass
import os

# default values
PYTHON_USER = "pythondemo"
PYTHON_CONNECT_STRING = "localhost/orclpdb"
PYTHON_DRCP_CONNECT_STRING = "localhost/orclpdb:pooled"

# dictionary containing all parameters; these are acquired as needed by the
# methods below (which should be used instead of consulting this dictionary
# directly) and then stored so that a value is not requested more than once
PARAMETERS = {}


def get_value(name, label, default_value=""):
    value = PARAMETERS.get(name)
    if value is not None:
        return value
    value = os.environ.get(name)
    if value is None:
        if default_value:
            label += " [%s]" % default_value
        label += ": "
        if default_value:
            value = input(label).strip()
        else:
            value = getpass.getpass(label)
        if not value:
            value = default_value
    PARAMETERS[name] = value
    return value


def get_main_user():
    return get_value("user", "Enter the User to be created", PYTHON_USER)


def get_main_password():
    return get_value("pw", "Enter the Password for %s" % get_main_user())


# Connect using the System User ID and password
con = oracledb.connect(user=db_config_sys.sysuser,
                       password=db_config_sys.syspw, dsn=db_config_sys.dsn)

# create sample user and schema
print("Creating user...")
run_sql_script.run_sql_script(con, "create_user", user=get_main_user(),
                              pw=get_main_password())
print("Done.")
