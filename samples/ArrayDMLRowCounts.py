#------------------------------------------------------------------------------
# Copyright (c) 2016, 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# ArrayDMLRowCounts.py
#
# Demonstrate the use of the 12.1 feature that allows execute_many() to return
# the number of rows affected by each individual execution as a list.  The
# parameter "array_dml_row_counts" must be set to True in the call to
# execute_many() after which the result will contain the key "dml_row_counts".
#------------------------------------------------------------------------------

import asyncio
import oracledb
import sample_env

async def perform_work(transaction):

    # show the number of rows for each parent ID as a means of verifying the
    # output from the delete statement
    async for parentId, count in await transaction.cursor("""
            select ParentId, count(*)
            from ChildTable
            group by ParentId
            order by ParentId"""):
        print("Parent ID:", parentId, "has", int(count), "rows.")
    print()

    # delete the following parent IDs only
    parent_ids_to_delete = [20, 30, 50]

    print("Deleting Parent IDs:", parent_ids_to_delete)
    print()

    # enable array DML row counts for each iteration executed in execute_many()
    result = await transaction.execute_many("""
            delete from ChildTable
            where ParentId = :1""",
            [(i,) for i in parent_ids_to_delete],
            array_dml_row_counts=True)

    # display the number of rows deleted for each parent ID
    for parentId, count in zip(parent_ids_to_delete, result["dml_row_counts"]):
        print("Parent ID:", parentId, "deleted", count, "rows.")

async def main():
    pool = await oracledb.create_pool(sample_env.get_main_params())
    async with pool.transaction() as transaction:
        await perform_work(transaction)
        # roll back so that script can be run multiple times
        await transaction.rollback()

loop = asyncio.get_event_loop()
loop.run_until_complete(main())
loop.close()
