# ------------------------------------------------------------------------------
# aq.py (Section 14.1)
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

# Cleanup
cur.execute(f"""
        begin
            dbms_aqadm.stop_queue('{QUEUE_NAME}');
            dbms_aqadm.drop_queue('{QUEUE_NAME}');
            dbms_aqadm.drop_queue_table('{QUEUE_TABLE_NAME}');
       
            execute immediate 'drop type {BOOK_TYPE_NAME}';
            exception when others then
                if sqlcode <> -24010 then
                    raise;
                end if;
        end;""")

# Create a type
print("Creating books type UDT_BOOK...")
cur.execute(f"""
        create type {BOOK_TYPE_NAME} as object (
            title varchar2(100),
            authors varchar2(100),
            price number(5,2)
        );""")


# Create queue table and queue and start the queue
print("Creating queue table...")
cur.callproc("dbms_aqadm.create_queue_table",
             (QUEUE_TABLE_NAME, BOOK_TYPE_NAME))
cur.callproc("dbms_aqadm.create_queue", (QUEUE_NAME, QUEUE_TABLE_NAME))
cur.callproc("dbms_aqadm.start_queue", (QUEUE_NAME,))

books_type = con.gettype(BOOK_TYPE_NAME)
queue = con.queue(QUEUE_NAME, books_type)

# Enqueue a few messages
print("Enqueuing messages...")

BOOK_DATA = [
    ("The Fellowship of the Ring", "Tolkien, J.R.R.", decimal.Decimal("10.99")),
    ("Harry Potter and the Philosopher's Stone", "Rowling, J.K.",
     decimal.Decimal("7.99"))
]

for title, authors, price in BOOK_DATA:
    book = books_type.newobject()
    book.TITLE = title
    book.AUTHORS = authors
    book.PRICE = price
    print(title)
    queue.enqone(con.msgproperties(payload=book))
    con.commit()

# Dequeue the messages
print("\nDequeuing messages...")
queue.deqoptions.wait = oracledb.DEQ_NO_WAIT
while True:
    props = queue.deqone()
    if not props:
        break
    print(props.payload.TITLE)
    con.commit()

print("\nDone.")
