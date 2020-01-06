#------------------------------------------------------------------------------
# Copyright (c) 2017, 2019, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Sets the environment used by most of the samples. Production applications
# should consider using External Authentication to avoid hard coded
# credentials.
#
# You can set values in environment variables to bypass the sample requesting
# the information it requires.
#
#     PY_ORACLEDB_SAMPLES_MAIN_USER: user used for most samples
#     PY_ORACLEDB_SAMPLES_MAIN_PASSWORD: password of user used for most samples
#     PY_ORACLEDB_SAMPLES_EDITION_USER: user for editioning
#     PY_ORACLEDB_SAMPLES_EDITION_PASSWORD: password of user for editioning
#     PY_ORACLEDB_SAMPLES_EDITION_NAME: name of edition for editioning
#     PY_ORACLEDB_SAMPLES_CONNECT_STRING: connect string
#     PY_ORACLEDB_SAMPLES_DRCP_CONNECT_STRING: DRCP connect string
#     PY_ORACLEDB_SAMPLES_ADMIN_USER: admin user for setting up samples
#     PY_ORACLEDB_SAMPLES_ADMIN_PASSWORD: admin password for setting up samples
#
# PY_ORACLEDB_SAMPLES_CONNECT_STRING can be set to an Easy Connect string, or a
# Net Service Name from a tnsnames.ora file or external naming service,
# or it can be the name of a local Oracle database instance.
#
# If oracledb is using Instant Client, then an Easy Connect string is generally
# appropriate. The syntax is:
#
#   [//]host_name[:port][/service_name][:server_type][/instance_name]
#
# Commonly just the host_name and service_name are needed
# e.g. "localhost/orclpdb1" or "localhost/XEPDB1"
#
# If using a tnsnames.ora file, the file can be in a default
# location such as $ORACLE_HOME/network/admin/tnsnames.ora or
# /etc/tnsnames.ora.  Alternatively set the TNS_ADMIN environment
# variable and put the file in $TNS_ADMIN/tnsnames.ora.
#
# The administrative user for cloud databases is ADMIN and the administrative
# user for on premises databases is SYSTEM.
#------------------------------------------------------------------------------

import getpass
import oracledb
import os
import sys

# default values
DEFAULT_MAIN_USER = "pythondemo"
DEFAULT_EDITION_USER = "pythoneditions"
DEFAULT_EDITION_NAME = "python_e1"
DEFAULT_CONNECT_STRING = "localhost/orclpdb1"
DEFAULT_DRCP_CONNECT_STRING = "localhost/orclpdb1:pooled"

# dictionary containing all parameters; these are acquired as needed by the
# methods below (which should be used instead of consulting this dictionary
# directly) and then stored so that a value is not requested more than once
PARAMETERS = {}

async def create_samples():
    pool = await get_admin_pool()
    await drop_samples(pool)
    print("Creating sample schemas and edition...")
    async with pool.transaction() as transaction:
        await run_sql_script(pool, "SetupSamples",
                main_user=get_main_user(),
                main_password=get_main_password(),
                edition_user=get_edition_user(),
                edition_password=get_edition_password(),
                edition_name=get_edition_name())

async def drop_samples(pool=None):
    if pool is None:
        pool = await get_admin_pool()
    print("Dropping sample schemas and edition...")
    async with pool.transaction() as transaction:
        await run_sql_script(transaction, "DropSamples",
                main_user=get_main_user(),
                edition_user=get_edition_user(),
                edition_name=get_edition_name())

async def get_admin_pool():
    user_name = get_value("ADMIN_USER", "Administrative user", "admin")
    password = get_value("ADMIN_PASSWORD", "Password for %s" % user_name)
    params = oracledb.PoolParams(user_name=user_name, password=password,
            dsn=get_connect_string())
    return await oracledb.create_pool(params)

def get_connect_string():
    return get_value("CONNECT_STRING", "Connect String", DEFAULT_CONNECT_STRING)

def get_drcp_connect_string():
    connect_string = get_value("DRCP_CONNECT_STRING", "DRCP Connect String",
            DEFAULT_DRCP_CONNECT_STRING)
    return "%s/%s@%s" % (get_main_user(), get_main_password(), connect_string)

def get_edition_connect_string():
    return "%s/%s@%s" % \
            (get_edition_user(), get_edition_password(), get_connect_string())

def get_edition_name():
    return get_value("EDITION_NAME", "Edition Name", DEFAULT_EDITION_NAME)

def get_edition_password():
    return get_value("EDITION_PASSWORD",
            "Password for %s" % get_edition_user())

def get_edition_user():
    return get_value("EDITION_USER", "Edition User Name", DEFAULT_EDITION_USER)

def get_main_params(password=None):
    if password is None:
        password = get_main_password()
    return oracledb.PoolParams(user_name=get_main_user(), password=password,
            dsn=get_connect_string())

def get_main_password():
    return get_value("MAIN_PASSWORD", "Password for %s" % get_main_user())

def get_main_user():
    return get_value("MAIN_USER", "Main User Name", DEFAULT_MAIN_USER)

def get_value(name, label, default_value=""):
    value = PARAMETERS.get(name)
    if value is not None:
        return value
    env_name = "PY_ORACLEDB_SAMPLES_" + name
    value = os.environ.get(env_name)
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

async def run_sql_script(transaction, script_name, **kwargs):
    statement_parts = []
    replace_values = [("&" + k + ".", v) for k, v in kwargs.items()] + \
            [("&" + k, v) for k, v in kwargs.items()]
    script_dir = os.path.dirname(os.path.abspath(sys.argv[0]))
    file_name = os.path.join(script_dir, "sql", script_name + "Exec.sql")
    for line in open(file_name):
        if line.strip() == "/":
            statement = "".join(statement_parts).strip()
            if statement:
                for search_value, replace_value in replace_values:
                    statement = statement.replace(search_value, replace_value)
                try:
                    await transaction.execute(statement)
                except:
                    print("Failed to execute SQL:", statement)
                    raise
            statement_parts = []
        else:
            statement_parts.append(line)
    result = await transaction.execute("""
            select name, type, line, position, text
            from dba_errors
            where owner = upper(:owner)
            order by name, type, line, position""",
            dict(owner=get_main_user()))
    prev_name = prev_obj_type = None
    for name, obj_type, line_num, position, text in result["rows"]:
        if name != prev_name or obj_type != prev_obj_type:
            print("%s (%s)" % (name, obj_type))
            prev_name = name
            prev_obj_type = obj_type
        print("    %s/%s %s" % (line_num, position, text))
