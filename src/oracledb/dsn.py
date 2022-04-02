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

from . import errors

def _check_arg(name: str, value: str) -> None:
    """
    Checks the argument to ensure that it does not contain (, ) or = as these
    characters are not permitted within connect strings.
    """
    if "(" in value or ")" in value or "=" in value:
        errors._raise_err(errors.ERR_INVALID_MAKEDSN_ARG, name=name)


def makedsn(host: str, port: int, sid: str=None, service_name: str=None,
            region:str=None, sharding_key: str=None,
            super_sharding_key: str=None) -> str:
    """
    Return a string suitable for use as the dsn parameter for connect(). This
    string is identical to the strings that are defined in the tnsnames.ora
    file.
    """
    connect_data_parts = []
    _check_arg("host", host)
    if sid is not None:
        _check_arg("sid", sid)
        connect_data_parts.append(f"(SID={sid})")
    if service_name is not None:
        _check_arg("service_name", service_name)
        connect_data_parts.append(f"(SERVICE_NAME={service_name})")
    if region is not None:
        _check_arg("region", region)
        connect_data_parts.append(f"(REGION={region})")
    if sharding_key is not None:
        _check_arg("sharding_key", sharding_key)
        connect_data_parts.append(f"(SHARDING_KEY={sharding_key})")
    if super_sharding_key is not None:
        _check_arg("super_sharding_key", super_sharding_key)
        connect_data_parts.append(f"(SUPER_SHARDING_KEY={super_sharding_key})")
    connect_data = "".join(connect_data_parts)
    return f"(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST={host})" \
           f"(PORT={port}))(CONNECT_DATA={connect_data}))"
