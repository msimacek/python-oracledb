#------------------------------------------------------------------------------
# Copyright (c) 2016, 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# BindInsert.py
#
# Demonstrate how to insert a row into a table using bind variables.
#------------------------------------------------------------------------------

import asyncio
import oracledb
import sample_env

rows = [ (1, "First" ),
         (2, "Second" ),
         (3, "Third" ),
         (4, "Fourth" ),
         (5, "Fifth" ),
         (6, "Sixth" ),
         (7, "Seventh" ) ]

async def main():
    pool = await oracledb.create_pool(sample_env.get_main_params())
    async with pool.transaction() as transaction:
        sql = "insert into mytab(id, data) values (:1, :2)"
        await transaction.execute_many(sql, rows)
        sql = "select rowid, id from mytab"
        async for row in await transaction.cursor(sql):
            print(row)

        # roll back, this lets us run the demo multiple times
        await transaction.rollback()

loop = asyncio.get_event_loop()
loop.run_until_complete(main())
loop.close()
