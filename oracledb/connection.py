#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#
# Licensed under BSD license (see LICENSE.txt).
#------------------------------------------------------------------------------

class Connection:

    def __init__(self, pool):
        self._pool = pool

    async def _close(self):
        await self._pool._run_task(self._handle.close)

    async def _commit(self):
        await self._pool._run_task(self._handle.commit)

    async def _connect(self, params):
        self._handle = await self._pool._run_task(self._pool._handle.acquire,
                user=params.user_name, password=params.password,
                cclass=params.connection_class, purity=params.purity,
                tag=params.tag, matchanytag=params.match_any_tag,
                shardingkey=params.sharding_key,
                supershardingkey=params.super_sharding_key)

    async def _execute(self, sql, params, fetch_array_size):
        cursor = self._handle.cursor()
        cursor.arraysize = fetch_array_size
        result = await self._pool._run_task(cursor.execute, sql, params or [])
        return_value = {}
        if result is None:
            return_value["row_count"] = cursor.rowcount
        else:
            return_value["rows"] = cursor.fetchall()
        return return_value

    async def _execute_many(self, sql, params, array_dml_row_counts=False,
            batch_errors=False):
        cursor = self._handle.cursor()
        await self._pool._run_task(cursor.executemany, sql, params,
                arraydmlrowcounts=array_dml_row_counts,
                batcherrors=batch_errors)
        return_value = {}
        if array_dml_row_counts:
            return_value["dml_row_counts"] = cursor.getarraydmlrowcounts()
        if batch_errors:
            return_value["batch_errors"] = cursor.getbatcherrors()
        return return_value

    async def _ping(self):
        await self._pool._run_task(self._handle.ping)

    async def _rollback(self):
        await self._pool._run_task(self._handle.rollback)
