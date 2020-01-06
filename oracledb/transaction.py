#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#
# Licensed under BSD license (see LICENSE.txt).
#------------------------------------------------------------------------------

from .exceptions import *
from .cursor import *

class Transaction:

    def __init__(self, pool, connection_params):
        self._pool = pool
        self._connection_params = connection_params
        self._conn = None

    async def _ensure_conn(self):
        if self._conn is None:
            self._conn = \
                    await self._pool._get_connection(self._connection_params)
        return self._conn

    async def __aenter__(self):
        return self

    async def __aexit__(self, exc_type, exc_value, traceback):
        if self._conn is not None:
            if exc_type is None:
                await self._conn._commit()
            await self._conn._close()
            self._conn = None

    async def commit(self):
        """
        Commit any pending transaction and return the connection back to the
        pool.
        """
        if self._conn is not None:
            await self._conn._commit()
            await self._conn._close()
            self._conn = None

    async def cursor(self, sql, params=None, fetch_array_size=100):
        """
        Execute a query and return a cursor that can be used to fetch rows. If
        the statement specified is not a query, an exception is raised.
        """
        conn = await self._ensure_conn()
        cursor = conn._handle.cursor()
        cursor.arraysize = fetch_array_size
        result = await conn._pool._run_task(cursor.execute, sql, params or [])
        if result is None:
            cursor.close()
            raise InterfaceError("SQL is not a query")
        return Cursor(conn, cursor, close_after_fetch=False)

    async def execute(self, sql, params=None, fetch_array_size=100):
        """
        Execute a SQL statement using a connection acquired from the pool
        specifically for this transaction.
        """
        conn = await self._ensure_conn()
        return await conn._execute(sql, params, fetch_array_size)

    async def execute_many(self, sql, params):
        """
        Execute a SQL statement with multiple rows of input using a connection
        acquired from the pool specifically for this transaction.
        """
        conn = await self._ensure_conn()
        return await conn._execute_many(sql, params)

    async def rollback(self):
        """
        Roll back any pending transaction and return the connection back to the
        pool.
        """
        if self._conn is not None:
            await self._conn._close()
            self._conn = None
