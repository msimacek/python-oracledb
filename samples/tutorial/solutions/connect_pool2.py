# ------------------------------------------------------------------------------
# connect_pool2.py (Section 2.5)
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Copyright (c) 2017, 2022, Oracle and/or its affiliates.
# ------------------------------------------------------------------------------

import oracledb
import threading
import time
import db_config

pool = oracledb.ConnectionPool(user=db_config.user, password=db_config.pw, dsn=db_config.dsn + ":pooled",
                               min=2, max=5, increment=1, getmode=oracledb.POOL_GETMODE_WAIT)


def Query():
    con = pool.acquire(cclass="PYTHONDEMO", purity=oracledb.ATTR_PURITY_SELF)
    #con = pool.acquire(cclass="PYTHONDEMO", purity=oracledb.ATTR_PURITY_NEW)
    cur = con.cursor()
    for i in range(4):
        cur.execute("select myseq.nextval from dual")
        seqval, = cur.fetchone()
        print("Thread", threading.current_thread().name,
              "fetched sequence =", seqval)
        # time.sleep(1)


numberOfThreads = 5
threadArray = []

for i in range(numberOfThreads):
    thread = threading.Thread(name='#'+str(i), target=Query)
    threadArray.append(thread)
    # time.sleep(4)
    thread.start()

for t in threadArray:
    t.join()

print("All done!")
