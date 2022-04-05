.. _changingmodes:

*******************************
Changing python-oracledb Modes
*******************************

Once you have installed or migrated from cx_Oracle to the python-oracledb driver (Thick mode or Thin mode), you are also provided with the ability to change from the Thick mode to the Thin mode and vice versa. The steps to change from one mode to another are detailed in the subsequent sections.  

Changing from Thick Mode to Thin Mode
======================================

To change from Thick mode to Thin mode, perform the following:

1. Optionally remove Oracle Client libraries. For example, uninstall Oracle Instant Client.
2. Remove all calls to :func:`~oracledb.init_oracle_client` in the application.
3. Move any ``sqlnet.ora`` network connection properties to :meth:`oracledb.defaults`, to ``ConnectParams()``, or to connection and pool creation calls arguments. Alternatively, you can set them in the Easy Connect String.

You can validate the connection by querying the ``CLIENT_DRIVER`` column of ``V$SESSION_CONNECT_INFO`` and checking if it begins with ``python-oracledb thn``. See :ref:`dbviews`.
Also review the :ref:`functional differences <driverdiff>` between the Thick and Thin modes and make necessary adjustments.

Changing from Thin Mode to Thick Mode
======================================

To take advantage of the additional features available in the python-oracledb Thick mode, perform the following steps to change from the Thin mode to the Thick mode:

1. Make Oracle Client libraries available. For example, install Oracle Instant Client. See :ref:`installation` for detailed steps.
2. Add a call to :func:`~oracledb.init_oracle_client()` in the application with or without ``lib_dir``. This function must be called at least once. If repeated calls are made with the same arguments, then these calls will be ignored. See :ref:`initialization`.
3. Change any use of network connection properties set in :meth:`oracledb.defaults` using ``ConnectParams()`` or in connection and pool creation calls. These need to be moved to a ``sqlnet.ora`` file or set in an Easy Connect String.

The connection can be validated by querying the ``CLIENT_DRIVER`` column of ``V$SESSION_CONNECT_INFO`` and checking if it begins with ``python-oracledb thk``. See :ref:`dbviews`.

Also review the :ref:`functional differences <driverdiff>` between the Thick and Thin modes and make necessary adjustments.
