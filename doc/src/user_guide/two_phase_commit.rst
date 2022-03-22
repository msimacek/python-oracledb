.. _tcp:

***********************
Two-Phase Commit (TPC)
***********************

The python-oracledb driver supports two-phase commit (TPC). cx_Oracle has two methods that can be used to perform TPC for transactions::

    Connection.begin()
    Connection.prepare()

The ``Connection.begin()`` and ``Connection.prepare()`` methods are
deprecated in python-oracledb. New methods to perform TPC are introduced in python-oracledb to better comply with Python Database API and are detailed in the subsequent sections.

.. note::

    The new TPC functionality is applicable only to the Thick mode.

New Constants
==============

The following flags are intended for use with the new method :meth:`~Connection.tpc_begin()`::

    TPC_BEGIN_JOIN
    TPC_BEGIN_NEW
    TPC_BEGIN_PROMOTE
    TPC_BEGIN_RESUME

.. Open question: what is the difference between `TPC_BEGIN_JOIN` and `TPC_BEGIN_RESUME`?

The following flags are intended for use with the new method :meth:`~Connection.tpc_end()`::

    TPC_END_NORMAL
    TPC_END_SUSPEND

.. Open question: should a detailed explanation of these flags be provided?


New Connection Methods
=======================

The following are the new connection methods introduced in python-oracledb:

    - :meth:`~Connection.xid()`: This function is used to build a named tuple called `Xid`, which contains the three components that identify an XA transaction.
    - :meth:`~Connection.tpc_begin`: This function begins work on a global transaction. 
    - :meth:`~Connection.tpc_commit()`: This function commits a global transaction.
    - :meth:`~Connection.tpc_end()`: This function ends work on a global transaction and is only intended for use by transaction managers.
    - :meth:`~Connection.tpc_forget()`: This function forgets a heuristically completed global transaction. 
    - :meth:`~Connection.tpc_prepare()`: This function prepares a global transaction for commit.
    - :meth:`~Connection.tpc_recover()`: This function returns a list of pending transactions that require recovery. See the :ref:`samples` section for an example on how to perform recovery with the :meth:`~Connection.tpc_recover` function.
    - :meth:`~Connection.tpc_rollback()`: This function rolls back a global transaction.

.. Open question: what purpose does the tpc_forget() function actually serve?

.. _samples:

Samples
=======

The following example shows how to perform recovery.

.. code-block:: python

    import oracledb

    oracledb.defaults.thin = False

    with oracledb.connect(DSN, mode=oracledb.SYSDBA) as conn:
        for xid in conn.tpc_recover():
            print("Recovering xid by rolling it back:", xid)
            conn.tpc_rollback(xid)


The following example shows how to perform application level two-phase commit.

.. code-block:: python

    import oracledb

    oracledb.defaults.thin = False

    # connect to first database and begin transaction
    conn1 = oracledb.connect(DSN1)
    xid1 = conn1.xid(1000, "txn1", "branch1")
    conn1.tpc_begin(xid1)
    with conn1.cursor() as cursor:
        cursor.execute("insert into SomeTable values (1, 'Some value')")

    # connect to second database and begin transaction
    conn2 = oracledb.connect(DSN2)
    xid2 = conn1.xid(1000, "txn1", "branch2")
    conn2.tpc_begin(xid2)
    with conn2.cursor() as cursor:
        cursor.execute("insert into SomeOtherTable values (2, 'Some value')")

    # prepare both transactions and commit
    commit_needed1 = conn1.tpc_prepare()
    commit_needed2 = conn2.tpc_prepare()
    if commit_needed1:
        conn1.tpc_commit()
    if commit_needed2:
        conn2.tpc_commit()

