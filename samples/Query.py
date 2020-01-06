#------------------------------------------------------------------------------
# Copyright (c) 2016, 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Query.py
#
# Demonstrate how to perform a query in different ways.
#------------------------------------------------------------------------------

import asyncio
import oracledb
import sample_env

sql = """
        select * from SampleQueryTab
        where id < 6
        order by id"""

async def main():
    pool = await oracledb.create_pool(sample_env.get_main_params())

    print("Get all rows via iterator")
    async for row in await pool.cursor(sql):
        print(row)
    print()

    print("Get all rows directly")
    result = await pool.execute(sql)
    for row in result["rows"]:
        print(row)
    print()

loop = asyncio.get_event_loop()
loop.run_until_complete(main())
loop.close()
