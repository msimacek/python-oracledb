#------------------------------------------------------------------------------
# Copyright (c) 2016, 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# BindQuery.py
#
# Demonstrate how to perform a simple query limiting the rows retrieved using
# a bind variable. Since the query that is executed is identical, no additional
# parsing is required, thereby reducing overhead and increasing performance. It
# also permits data to be bound without having to be concerned about escaping
# special characters or SQL injection attacks.
#------------------------------------------------------------------------------

import asyncio
import oracledb
import sample_env

sql = 'select * from SampleQueryTab where id = :bvid'

async def main():
    pool = await oracledb.create_pool(sample_env.get_main_params())

    print("Query results with id = 4")
    async for row in await pool.cursor(sql, dict(bvid=4)):
        print(row)
    print()

    print("Query results with id = 1")
    async for row in await pool.cursor(sql, dict(bvid=1)):
        print(row)
    print()

loop = asyncio.get_event_loop()
loop.run_until_complete(main())
loop.close()
