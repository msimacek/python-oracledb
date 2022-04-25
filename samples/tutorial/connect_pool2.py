# ------------------------------------------------------------------------------
# connect_pool2.py (Section 2.2 and 2.4)
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Copyright (c) 2017, 2022, Oracle and/or its affiliates.
# ------------------------------------------------------------------------------

import oracledb
import threading
import db_config

pool = oracledb.ConnectionPool(user=db_config.user, password=db_config.pw, dsn=db_config.dsn,
                               min=2, max=5, increment=1, getmode=oracledb.POOL_GETMODE_WAIT)


def Query():
    con = pool.acquire()
    cur = con.cursor()
    for i in range(4):
        cur.execute("select myseq.nextval from dual")
        seqval, = cur.fetchone()
        print("Thread", threading.current_thread().name,
              "fetched sequence =", seqval)


number_of_threads = 2
thread_array = []

for i in range(number_of_threads):
    thread = threading.Thread(name='#' + str(i), target=Query)
    thread_array.append(thread)
    thread.start()

for t in thread_array:
    t.join()

print("All done!")
