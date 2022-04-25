# ------------------------------------------------------------------------------
# aq-dequeue.py (Section 14.1)
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Copyright (c) 2017, 2022, Oracle and/or its affiliates.
# ------------------------------------------------------------------------------

import oracledb
import decimal
import db_config_thick as db_config

con = oracledb.connect(user=db_config.user,
                       password=db_config.pw, dsn=db_config.dsn)
cur = con.cursor()

BOOK_TYPE_NAME = "UDT_BOOK"
QUEUE_NAME = "BOOKS"
QUEUE_TABLE_NAME = "BOOK_QUEUE_TABLE"

# Dequeue the messages
books_type = con.gettype(BOOK_TYPE_NAME)
queue = con.queue(QUEUE_NAME, books_type)
queue.deqoptions.wait = oracledb.DEQ_NO_WAIT
queue.deqoptions.visibility = oracledb.DEQ_IMMEDIATE

print("\nDequeuing messages...")
while True:
    props = queue.deqone()
    if not props:
        break
    print(props.payload.TITLE)

print("\nDone.")
