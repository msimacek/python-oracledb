#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#
# Licensed under BSD license (see LICENSE.txt).
#------------------------------------------------------------------------------

import asyncio
import concurrent.futures

import cx_Oracle as _oracledb

from .connection import *
from .exceptions import *
from .cursor import *
from .constants import *
from .params import *
from .transaction import *

class Pool:

    def __init__(self):
        self._defaultParams = ConnectionParams()

    async def _create(self, params):
        self._executor = concurrent.futures.ThreadPoolExecutor()
        homogeneous = not params.heterogeneous
        self._handle = await self._run_task(_oracledb.SessionPool,
                user=params.user_name, password=params.password,
                dsn=params.dsn, min=params.min_sessions,
                max=params.max_sessions, threaded=params.threaded,
                getmode=params.get_mode, events=params.events,
                homogeneous=homogeneous, externalauth=params.external_auth,
                encoding=params.encoding, nencoding=params.nencoding,
                edition=params.edition, timeout=params.idle_timeout,
                waitTimeout=params.wait_timeout,
                maxLifetimeSession=params.max_session_lifetime,
                sessionCallback=params.session_callback)

    async def _get_connection(self, params):
        if params is None:
            params = self._defaultParams
        conn = Connection(self)
        await conn._connect(params)
        return conn

    async def _run_task(self, fn, *args, **kwargs):
        fut = self._executor.submit(fn, *args, **kwargs)
        return await asyncio.wrap_future(fut)

    async def cursor(self, sql, params=None, connection_params=None,
            fetch_array_size=100):
        """
        Acquire a connection from the pool and then execute a query. If the
        statement specified is not a query an exception is raised. A cursor
        object is returned from which rows can be fetched. Once all of the rows
        have been fetched or the cursor is directly closed, the connection is
        returned back to the pool.
        """
        conn = await self._get_connection(connection_params)
        cursor = conn._handle.cursor()
        cursor.arraysize = fetch_array_size
        result = await self._run_task(cursor.execute, sql, params or [])
        if result is None:
            cursor.close()
            await conn._close()
            raise InterfaceError("SQL is not a query")
        return Cursor(conn, cursor)

    async def execute(self, sql, params=None, connection_params=None,
            fetch_array_size=100):
        """
        Acquire a connection from the pool and then execute a SQL statement. If
        the SQL statement is executed successfully any changes made are
        committed; otherwise, they are rolled back. When this function
        completes the connection is automatically returned back to the pool.
        """
        conn = await self._get_connection(connection_params)
        conn._handle.autocommit = True
        result = await conn._execute(sql, params, fetch_array_size)
        await conn._close()
        return result

    async def execute_many(self, sql, params, connection_params=None):
        """
        Acquire a connection from the pool and then execute a SQL statement
        with multiple rows of input. If the SQL statement is executed
        successfully, any changes made are committed; otherwise, they are
        rolled back. When this function completes, the connection is
        automatically returned back to the pool.
        """
        conn = await self._get_connection(connection_params)
        conn._handle.autocommit = True
        result = await conn._execute_many(sql, params)
        await conn._close()
        return result

    async def ping(self, connection_params=None):
        """
        Acquire a connection from the pool and then ping the connection to
        ensure that the database is accessible.
        """
        conn = await self._get_connection(connection_params)
        await conn._ping()
        await conn._close()

    def transaction(self, connection_params=None):
        """
        Return a transaction object which can be used to execute multiple SQL
        statements with a connection acquired from the pool. When the
        transaction is committed or rolled back, the connection is returned
        back to the pool.
        """
        return Transaction(self, connection_params)
