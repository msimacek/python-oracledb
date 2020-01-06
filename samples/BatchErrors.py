#------------------------------------------------------------------------------
# Copyright (c) 2016, 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# BatchErrors.py
#
# Demonstrate the use of the Oracle Database 12.1 feature that allows
# execute_many() to complete successfully, even if errors take place during the
# execution of one or more of the individual executions. The parameter
# "batch_errors" must be set to True in the call to execute_many() after which
# the key "batch_errors" will contain a list of error objects.
#------------------------------------------------------------------------------

import asyncio
import oracledb
import sample_env

# define data to insert
data_to_insert = [
    (1016, 10, 'Child B of Parent 10'),
    (1017, 10, 'Child C of Parent 10'),
    (1018, 20, 'Child D of Parent 20'),
    (1018, 20, 'Child D of Parent 20'),       # duplicate key
    (1019, 30, 'Child C of Parent 30'),
    (1020, 30, 'Child D of Parent 40'),
    (1021, 60, 'Child A of Parent 60'),       # parent does not exist
    (1022, 40, 'Child F of Parent 40'),
]

async def perform_work(transaction):

    # retrieve the number of rows in the table
    result = await transaction.execute("select count(*) from ChildTable")
    count = int(result["rows"][0][0])
    print("number of rows in child table:", count)
    print("number of rows to insert:", len(data_to_insert))


    # execute_many() with batch errors enabled (and array DML row counts
    # also enabled) results in no immediate error being raised
    sql = "insert into ChildTable values (:1, :2, :3)"
    result = await transaction.execute_many(sql, data_to_insert,
            batch_errors=True, array_dml_row_counts=True)

    # where errors have taken place, the row count is 0; otherwise it is 1
    print("Array DML row counts:", result["dml_row_counts"])

    # display the errors that have taken place
    errors = result["batch_errors"]
    print("number of errors which took place:", len(errors))
    for error in errors:
        print("Error", error.message.rstrip(), "at row offset", error.offset)

    # demonstrate that all of the rows without errors have been successfully
    # inserted
    result = await transaction.execute("select count(*) from ChildTable")
    count = int(result["rows"][0][0])
    print("number of rows in child table after successful insert:", count)

async def main():
    pool = await oracledb.create_pool(sample_env.get_main_params())
    async with pool.transaction() as transaction:
        await perform_work(transaction)
        # roll back so that script can be run multiple times
        await transaction.rollback()

loop = asyncio.get_event_loop()
loop.run_until_complete(main())
loop.close()
