#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#
# Licensed under BSD license (see LICENSE.txt).
#------------------------------------------------------------------------------

class Cursor:

    def __init__(self, conn, cursor, close_after_fetch=True):
        self._conn = conn
        self._handle = cursor
        self._cached_rows = []
        self._fetch_array_size = cursor.arraysize
        self._close_after_fetch = close_after_fetch

    def __aiter__(self):
        return self

    async def __anext__(self):
        if not self._cached_rows and self._conn is not None:
            self._cached_rows = \
                    await self._conn._pool._run_task(self._handle.fetchmany)
        if self._cached_rows:
            return self._cached_rows.pop(0)
        raise StopAsyncIteration

    async def close(self):
        if self._conn is not None:
            self._handle.close()
            if self._close_after_fetch:
                await self._conn._close()
            self._conn = None

    async def fetch(self, num_rows=None):
        if num_rows is None:
            num_rows = self._fetch_array_size
        fetched_rows = self._cached_rows[:num_rows]
        if fetched_rows:
            self._cached_rows = self._cached_rows[num_rows:]
        while self._conn is not None and len(fetched_rows) < num_rows:
            num_rows_remaining = num_rows - len(fetched_rows)
            rows = await self._conn._pool._run_task(self._handle.fetchmany)
            if rows:
                fetched_rows.extend(rows[:num_rows_remaining])
                self._cached_rows = rows[num_rows_remaining:]
            if len(rows) < self._fetch_array_size:
                await self.close()
        return fetched_rows
