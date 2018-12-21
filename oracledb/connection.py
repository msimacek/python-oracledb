#------------------------------------------------------------------------------
# Copyright (c) 2018, Oracle and/or its affiliates. All rights reserved.
#
# Licensed under BSD license (see LICENSE.txt).
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# connection.py
#   Contains definitions for connecting to the database.
#------------------------------------------------------------------------------

import asyncio
import _oracledb
import oracledb

__all__ = ["connect"]

async def connect(user=None, password=None, dsn=None, mode=0, handle=0,
        events=False, cclass=None, purity=0, new_password=None, edition=None,
        app_context=[], tag=None, match_any_tag=False, sharding_key=[],
        super_sharding_key=[], loop=None):
    """Create a standalone connection to the database."""

    # split dsn and password from user if they are present and no dsn and
    # password have been specified
    if isinstance(user, str):
        if not dsn:
            pos = user.find("@")
            if pos >= 0:
                dsn = user[pos + 1:]
                user = user[:pos]
        if not password:
            pos = user.find("/")
            if pos >= 0:
                password = user[pos + 1:]
                user = user[:pos]

    # create future which will be awaited (marked done by _oracledb)
    if loop is None:
        loop = asyncio.get_event_loop()
    future = loop.create_future()

    # call C function to perform actual connection; this is run asynchronously
    # so we await on the future for it to be completed
    conn = Connection()
    conn._connect(loop, future, oracledb.DRIVER_NAME, user=user,
            password=password, dsn=dsn, handle=handle, events=events,
            cclass=cclass, purity=purity, new_password=new_password,
            edition=edition, app_context=app_context, tag=tag,
            match_any_tag=match_any_tag, sharding_key=sharding_key,
            super_sharding_key=super_sharding_key)
    await future
    return conn


class Connection(_oracledb.Connection):
    pass

