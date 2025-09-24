# -----------------------------------------------------------------------------
# Copyright (c) 2025, Oracle and/or its affiliates.
#
# This software is dual-licensed to you under the Universal Permissive License
# (UPL) 1.0 as shown at https://oss.oracle.com/licenses/upl and Apache License
# 2.0 as shown at http://www.apache.org/licenses/LICENSE-2.0. You may choose
# either license.
#
# If you elect to accept the software under the Apache License, Version 2.0,
# the following applies:
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# -----------------------------------------------------------------------------

"""
Module for testing user requested schema in fetch_df APIs using asyncio.
"""

import pyarrow
import pytest


@pytest.fixture(autouse=True)
def module_checks(anyio_backend, skip_unless_thin_mode):
    pass


@pytest.mark.parametrize(
    "dtype",
    [
        pyarrow.int8(),
        pyarrow.int16(),
        pyarrow.int32(),
        pyarrow.int64(),
        pyarrow.uint8(),
        pyarrow.uint16(),
        pyarrow.uint32(),
        pyarrow.uint64(),
    ],
)
async def test_9400(dtype, async_conn, test_env):
    "9400 - fetch_df_all() with fixed width integer types"
    statement = "select 1 from dual"
    requested_schema = pyarrow.schema([("INT_COL", dtype)])
    ora_df = await async_conn.fetch_df_all(
        statement, requested_schema=requested_schema
    )
    tab = pyarrow.table(ora_df)
    assert tab.field("INT_COL").type == dtype
    assert tab["INT_COL"][0].as_py() == 1


@pytest.mark.parametrize(
    "dtype",
    [
        pyarrow.int8(),
        pyarrow.int16(),
        pyarrow.int32(),
        pyarrow.int64(),
        pyarrow.uint8(),
        pyarrow.uint16(),
        pyarrow.uint32(),
        pyarrow.uint64(),
    ],
)
async def test_9401(dtype, async_conn, test_env):
    "9401 - fetch_df_all() with duplicate fixed width integer types"
    requested_schema = pyarrow.schema([("INT_COL", dtype)])
    ora_df = await async_conn.fetch_df_all(
        """
        select 99 from dual
        union all
        select 99 from dual
        union all
        select 99 from dual
        union all
        select 99 from dual
        union all
        select 99 from dual
        union all
        select 99 from dual
        """,
        requested_schema=requested_schema,
    )
    tab = pyarrow.table(ora_df)
    assert len(tab) == 6
    assert tab.field("INT_COL").type == dtype
    for value in tab["INT_COL"]:
        assert value.as_py() == 99


async def test_9402(async_conn, test_env):
    "9302 - fetch_df_all() requested_schema honored for repeated execution"
    statement = "select 1 as int_col from dual"
    ora_df = await async_conn.fetch_df_all(statement)
    tab = pyarrow.table(ora_df)
    assert tab.field("INT_COL").type == pyarrow.float64()
    requested_schema = pyarrow.schema([("INT_COL", pyarrow.int8())])
    ora_df = await async_conn.fetch_df_all(
        statement, requested_schema=requested_schema
    )
    tab = pyarrow.table(ora_df)
    assert tab.field("INT_COL").type == pyarrow.int8()
    ora_df = await async_conn.fetch_df_all(statement)
    tab = pyarrow.table(ora_df)
    assert tab.field("INT_COL").type == pyarrow.float64()


@pytest.mark.parametrize(
    "dtype",
    [
        pyarrow.int8(),
        pyarrow.int16(),
        pyarrow.int32(),
        pyarrow.int64(),
        pyarrow.uint8(),
        pyarrow.uint16(),
        pyarrow.uint32(),
        pyarrow.uint64(),
    ],
)
async def test_9403(dtype, async_conn, test_env):
    "9403 - fetch_df_batches() with fixed width integer types"
    statement = "select 1 from dual"
    requested_schema = pyarrow.schema([("INT_COL", dtype)])
    async for ora_df in async_conn.fetch_df_batches(
        statement, requested_schema=requested_schema
    ):
        tab = pyarrow.table(ora_df)
        assert tab.field("INT_COL").type == dtype
        assert tab["INT_COL"][0].as_py() == 1


@pytest.mark.parametrize(
    "dtype",
    [
        pyarrow.int8(),
        pyarrow.int16(),
        pyarrow.int32(),
        pyarrow.int64(),
        pyarrow.uint8(),
        pyarrow.uint16(),
        pyarrow.uint32(),
        pyarrow.uint64(),
    ],
)
async def test_9304(dtype, async_conn, test_env):
    "9304 - fetch_df_batches() with duplicate fixed width integer types"
    requested_schema = pyarrow.schema([("INT_COL", dtype)])
    async for ora_df in async_conn.fetch_df_batches(
        """
        select 99 from dual
        union all
        select 99 from dual
        union all
        select 99 from dual
        union all
        select 99 from dual
        union all
        select 99 from dual
        union all
        select 99 from dual
        """,
        requested_schema=requested_schema,
    ):
        tab = pyarrow.table(ora_df)
        assert len(tab) == 6
        assert tab.field("INT_COL").type == dtype
        for value in tab["INT_COL"]:
            assert value.as_py() == 99


async def test_9305(async_conn, test_env):
    "9305 - fetch_df_batches() requested_schema honored for repeated execution"
    statement = "select 1 as int_col from dual"
    async for ora_df in async_conn.fetch_df_batches(statement):
        tab = pyarrow.table(ora_df)
        assert tab.field("INT_COL").type == pyarrow.float64()
    requested_schema = pyarrow.schema([("INT_COL", pyarrow.int8())])
    async for ora_df in async_conn.fetch_df_batches(
        statement, requested_schema=requested_schema
    ):
        tab = pyarrow.table(ora_df)
        assert tab.field("INT_COL").type == pyarrow.int8()
    async for ora_df in async_conn.fetch_df_batches(statement):
        tab = pyarrow.table(ora_df)
        assert tab.field("INT_COL").type == pyarrow.float64()
