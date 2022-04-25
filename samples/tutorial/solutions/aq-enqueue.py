# ------------------------------------------------------------------------------
# aq-enqueue.py (Section 14.1)
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

# Enqueue a few messages
print("Enqueuing messages...")

BOOK_DATA = [
    ("The Fellowship of the Ring", "Tolkien, J.R.R.", decimal.Decimal("10.99")),
    ("Harry Potter and the Philosopher's Stone",
     "Rowling, J.K.", decimal.Decimal("7.99"))
]

books_type = con.gettype(BOOK_TYPE_NAME)
queue = con.queue(QUEUE_NAME, books_type)

for title, authors, price in BOOK_DATA:
    book = books_type.newobject()
    book.TITLE = title
    book.AUTHORS = authors
    book.PRICE = price
    print(title)
    queue.enqone(con.msgproperties(payload=book, expiration=4))
    con.commit()
