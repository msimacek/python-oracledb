.. _changingmodes:

*****************************************************
Changing from Thin Mode to Thick Mode and Vice-Versa
*****************************************************

Once you have migrated from cx_Oracle to either the python-oracledb Thin or python-oracledb Thick mode, you can also change from the Thick mode to the Thin mode and vice-versa. The steps to change from one mode to another are detailed in the subsequent sections.  

Changing from Thick Mode to Thin Mode
======================================

To change your mode from Thick to Thin, perform the following:

1. Verify and ensure that the Thin mode supports the requirements of your application by reviewing the :ref:`Features Supported <appendixa>` and :ref:`driverdiff`.
2. Remove calls to :func:`~oracledb.init_oracle_client`.
3. Optionally, you can remove Oracle Instant Client, if it was installed.
4. Query the ``CLIENT_DRIVER`` column of ``V$SESSION_CONNECT_INFO`` to verify the mode in use.

Changing from Thin Mode to Thick Mode
======================================

To change your mode from Thin to Thick, perform the following:

1. Verify and ensure that the Thick mode supports the requirements of your application by reviewing the :ref:`Features Supported <appendixa>` and :ref:`driverdiff`.
2. Install Oracle Client libraries. You can install the free `Oracle Instant Client <https://www.oracle.com/database/technologies/instant-client.html>`__ "Basic" or "Basic Light" package. The libraries are also available in any Oracle Database installation or full Oracle Client installation.
3.  Call :func:`~oracledb.init_oracle_client()` anywhere before the first call to :func:`~oracledb.connect()`, :func:`oracledb.Connection()`, and :func:`~oracledb.SessionPool()`. ``init_oracle_client()`` must be called atleast once per process.