#------------------------------------------------------------------------------
# Copyright (c) 2016, 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# QueryArraysize.py
#
# Demonstrate how to alter the array size on a cursor in order to reduce the
# number of network round trips and overhead required to fetch all of the rows
# from a large table.
#------------------------------------------------------------------------------

import asyncio
import oracledb
import sample_env
import time

async def main():

    pool = await oracledb.create_pool(sample_env.get_main_params())

    start = time.time()
    res = await pool.execute('select * from bigtab', fetch_array_size=1000)
    elapsed = (time.time() - start)

    # print(res)  # uncomment to display the query results
    print("Retrieved", len(res["rows"]), "rows in", elapsed, "seconds")

loop = asyncio.get_event_loop()
loop.run_until_complete(main())
loop.close()
