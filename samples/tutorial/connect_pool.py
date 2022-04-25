# ------------------------------------------------------------------------------
# connect_pool.py (Section 2.1)
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


thread1 = threading.Thread(name='#1', target=Query)
thread1.start()

thread2 = threading.Thread(name='#2', target=Query)
thread2.start()

thread1.join()
thread2.join()

print("All done!")
