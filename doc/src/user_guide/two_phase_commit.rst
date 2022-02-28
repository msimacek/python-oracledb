.. _tcp:

******************
Two-Phase Commit
******************

The python-oracledb driver supports two-phase commit. cx_Oracle has two methods that can be used to perform TPC (two-phase
commit) for transactions::

    Connection.begin()
    Connection.prepare()

Both functions ``connection.begin()`` and ``connection.prepare()`` are
deprecated in python-oracledb by the new functionality of the two-phase commit feature.

Implementation
===============

New Constants
-------------

The following flags are intended for use with the new method `tpc_begin()`::

    TPC_BEGIN_JOIN
    TPC_BEGIN_NEW
    TPC_BEGIN_PROMOTE
    TPC_BEGIN_RESUME

Open question: what is the difference between `TPC_BEGIN_JOIN` and
`TPC_BEGIN_RESUME`?

The following flags are intended for use with the new method `tpc_end()`::

    TPC_END_NORMAL
    TPC_END_SUSPEND

Open question: should a detailed explanation of these flags be provided?


New Connection Methods
----------------------

.. code-block:: python

    def xid(self,
            format_id: int,
            global_transaction_id: Union[bytes, str],
            branch_qualifier: Union[bytes, str]) -> Xid

This function is used to build a named tuple (called `Xid`) which contains the
three components that identify an XA transaction. No checking is performed at
the Python level. The values are checked by ODPI-C when they are passed to the
relevant functions. When this functionality is also supported in the thin
driver the checks will be performed at the Python level as well.

The `format_id` parameter is expected to be a positive 32-bit integer. This
value identifies the format of the `global_transaction_id` and
`branch_qualifier` parameters and the value is determined by the TM if one is
in use.

The `global_transaction_id` and `branch_qualifier` parameters are expected to
be values of type `str` or `bytes`. If a value of type `str` is passed it will
be UTF-8 encoded to `bytes`. The values cannot exceed 64 bytes in length.


.. code-block:: python

    def tpc_begin(self,
                  xid: Xid,
                  flags: int=constants.TPC_BEGIN_NEW) -> None

This function begins work on a global transaction. The `xid` parameter should
be an object returned by the `xid()` function. This function replaces the
original `begin()` function and internally `begin()` simply calls this
function.


.. code-block:: python

    def tpc_commit(self,
                   xid: Xid=None,
                   one_phase: bool=False) -> None

This function commits a global transaction. When called with no arguments, it
commits a transaction previously prepared with `tpc_begin()` and optionally
prepared with `tpc_prepare()`. If `tpc_prepare()` is not called, a single phase
commit is performed. A transaction manager may choose to do this if only a
single resource is participating in the global transaction.

When called with a value for the `xid` parameter, it should be an object
returned by the `xid()` function. This form should be called outside a
transaction and is intended for use in recovery.

The `one_phase` parameter is expected to be a boolean identifying whether to
perform a one phase or two phase commit. It is only examined if a value is
provided for the `xid` parameter, as otherwise the driver already knows whether
`tpc_prepare()` was called for the transaction and whether a one phase or two
phase commit is required.


.. code-block:: python

    def tpc_end(self,
                xid: Xid=None,
                flags: int=constants.TPC_END_NORMAL) -> None

This function ends work on a global transaction. It is generally only intended
to be used by transaction managers.

If an `xid` parameter is passed it is expected to be an object returned by the
`xid()` function. If no `xid` parameter is passed the one previously started
with `tpc_begin()` is used.


.. code-block:: python

    def tpc_forget(self, xid: Xid) -> None

This function forgets a heuristically completed global transaction. The `xid`
parameter is mandatory and is expected to be an object returned by the `xid()`
function. It is only intended to be called by transaction managers.

Open question: what purpose does this function actually serve?


.. code-block:: python

    def tpc_prepare(self, xid: Xid=None) -> bool

This function prepares a global transaction for commit. A boolean is returned
indicating if a commit is needed or not. Attempting to commit if a commit is
not needed results in the error `ORA-24756: transaction does not exist` being
raised.

If an `xid` parameter is passed it is expected to be an object returned by the
`xid()` function. If no `xid` parameter is passed the one previously started
with `tpc_begin()` is used.

This function replaces the original `prepare()` function. The original
`prepare()` function is replaced by a call to this function without parameters.


.. code-block:: python

    def tpc_recover(self) -> list

This function returns a list of pending transactions that require recovery.
Objects of type `Xid` (as returned by the `xid()` function) are returned and
these can be passed to `tpc_commit()` or `tpc_rollback()` as needed.

This function performs a query against `DBA_PENDING_TRANSACTIONS` and requires
select privilege on this view.

See the samples section for an example of how to perform recovery with this
function.

.. code-block:: python

    def tpc_rollback(self, xid: Xid=None) -> None

This function rolls back a global transaction. When called with no arguments,
rolls back the transaction previously started with `tpc_begin()`.

When called with a value for the `xid` parameter is is expected to be an object
returned by the `xid()` function and the specified transactions is rolled back.
This form should be called outside of a transaction and is intended for use in
recovery.


Samples
=======

The following example shows how to perform recovery. This may be particularly
useful when testing!

.. code-block:: python

    import oracledb

    oracledb.defaults.thin = False

    with oracledb.connect(DSN, mode=oracledb.SYSDBA) as conn:
        for xid in conn.tpc_recover():
            print("Recovering xid by rolling it back:", xid)
            conn.tpc_rollback(xid)


The following sample shows how to perform application level two-phase commit:

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

