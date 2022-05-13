.. _tracingsql:

***********************
Tracing python-oracledb
***********************

.. _applntracing:

Application Tracing
===================

There are multiple approaches for application tracing and monitoring:

- :ref:`End-to-end database tracing <endtoendtracing>` attributes such as
  :attr:`Connection.action`, and :attr:`Connection.module` are supported in the
  python-oracledb Thin and Thick modes.  Using these attributes is recommended
  since they aid application monitoring and troubleshooting.

- You can :ref:`subclass python-oracledb classes <subclassconn>` and implement
  your own driver API call tracing and logging. Also, the standard `Python
  tracing capabilities <https://docs.python.org/3/library/trace.html>`__ can be
  used.

- The Java Debug Wire Protocol (JDWP) for debugging PL/SQL can be used, see :ref:`jdwp`.

- Python-oracledb in Thick mode can dump a trace of SQL statements
  executed, see :ref:`lowlevelsqltrace`.

.. _endtoendtracing:

Oracle Database End-to-End Tracing
----------------------------------

Oracle Database End-to-end application tracing simplifies diagnosing application
code flow and performance problems in multi-tier or multi-user environments.

The connection attributes, :attr:`~Connection.client_identifier`,
:attr:`~Connection.clientinfo`, :attr:`~Connection.dbop`,
:attr:`~Connection.module` and :attr:`~Connection.action`, set the metadata for
end-to-end tracing.  You can use data dictionary and ``V$`` views to monitor
tracing or use other application tracing utilities.

The attributes are sent to the database when the next :ref:`round-trip
<roundtrips>` to the database occurs, for example when the next SQL statement is
executed.

The attribute values will remain set in connections released back to connection
pools.  When the application re-acquires a connection from the pool it should
initialize the values to a desired state before using that connection.

The example below shows setting the action, module and client identifier
attributes on the connection object:

.. code-block:: python

    # Set the tracing metadata
    connection.client_identifier = "pythonuser"
    connection.action = "Query Session tracing parameters"
    connection.module = "End-to-end Demo"

    for row in cursor.execute("""
            SELECT username, client_identifier, module, action
            FROM V$SESSION
            WHERE username = 'SYSTEM'"""):
        print(row)

The output will be::

    ('SYSTEM', 'pythonuser', 'End-to-end Demo', 'Query Session tracing parameters')

The values can also be manually set as shown by calling
`DBMS_APPLICATION_INFO procedures
<https://www.oracle.com/pls/topic/lookup?ctx=dblatest&
id=GUID-14484F86-44F2-4B34-B34E-0C873D323EAD>`__
or `DBMS_SESSION.SET_IDENTIFIER
<https://www.oracle.com/pls/topic/lookup?ctx=dblatest&
id=GUID-988EA930-BDFE-4205-A806-E54F05333562>`__. These incur round-trips to
the database, however, reducing scalability.

.. code-block:: sql

    BEGIN
        DBMS_SESSION.SET_IDENTIFIER('pythonuser');
        DBMS_APPLICATION_INFO.set_module('End-to-End Demo');
        DBMS_APPLICATION_INFO.set_action(action_name => 'Query Session tracing parameters');
    END;

.. _subclassconn:

Subclassing Connections
-----------------------

Subclassing enables applications to add "hooks" for connection and statement
execution.  This can be used to alter, or log, connection and execution
parameters, and to extend python-oracledb functionality.

The example below demonstrates subclassing a connection to log SQL execution
to a file.  This example also shows how connection credentials can be embedded
in the custom subclass, so application code does not need to supply them.

.. code-block:: python

    class Connection(oracledb.Connection):
        log_file_name = "log.txt"

        def __init__(self):
            connect_string = "hr/hr_password@dbhost.example.com/orclpdb1"
            self._log("Connect to the database")
            return super(Connection, self).__init__(connect_string)

        def _log(self, message):
            with open(self.log_file_name, "a") as f:
                print(message, file=f)

        def execute(self, sql, parameters):
            self._log(sql)
            cursor = self.cursor()
            try:
                return cursor.execute(sql, parameters)
            except oracledb.Error as e:
                error_obj, = e.args
                self._log(error_obj.message)
                raise

    connection = Connection()
    connection.execute("""
            select department_name
            from departments
            where department_id = :id""", dict(id=270))

The messages logged in ``log.txt`` are::

    Connect to the database

                select department_name
                from departments
                where department_id = :id

If an error occurs, perhaps due to a missing table, the log file would contain
instead::

    Connect to the database

                select department_name
                from departments
                where department_id = :id
    ORA-00942: table or view does not exist

In production applications be careful not to log sensitive information.

See `Subclassing.py
<https://github.com/oracle/python-oracledb/blob/main/
samples/subclassing.py>`__ for an example.


.. _jdwp:

Debugging PL/SQL with the Java Debug Wire Protocol
--------------------------------------------------

The Java Debug Wire Protocol (JDWP) for debugging PL/SQL can be used.

  The python-oracledb applications that call PL/SQL can step through that PL/SQL code
  using JDWP in a debugger. This allows Python and PL/SQL code to be debugged in the
  same debugger environment. You can enable PL/SQL debugging in the python-oracledb
  modes as follows:

    - If you are using python-oracledb Thick mode, set the ``ORA_DEBUG_JDWP`` environment
      variable to `host=hostname;port=portnum` indicating where the PL/SQL debugger
      is running.

    - In the python-oracledb Thin mode, you can additionally set the connection
      parameter ``debug_jdwp``. This variable defaults to the value of the
      ``ORA_DEBUG_JDWP`` environment variable.

  See `DBMS_DEBUG_JDWP <https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_DEBUG_JDWP.html>`_ and `Debugging PL/SQL from ASP.NET and Visual
  Studio <http://cshay.blogspot.com/2006/10/debugging-plsql-from-aspnet-and-visual.html>`_.


.. _lowlevelsqltrace:

Low Level SQL Tracing
---------------------

The Thick mode of python-oracledb is implemented using the `ODPI-C <https://oracle.
github.io/odpi>`__ wrapper on top of the Oracle Client libraries.  The ODPI-C tracing
capability can be used to log executed python-oracledb statements to the standard error
stream. Before executing Python, set the environment variable ``DPI_DEBUG_LEVEL`` to 16.

At a Windows command prompt, this could be done with::

    set DPI_DEBUG_LEVEL=16

On Linux, you might use::

    export DPI_DEBUG_LEVEL=16

After setting the variable, run the Python Script, for example on Linux::

    python end-to-endtracing.py 2> log.txt

For an application that does a single query, the log file might contain a
tracing line consisting of the prefix 'ODPI', a thread identifier, a timestamp,
and the SQL statement executed::

    ODPI [26188] 2019-03-26 09:09:03.909: ODPI-C 3.1.1
    ODPI [26188] 2019-03-26 09:09:03.909: debugging messages initialized at level 16
    ODPI [26188] 2019-03-26 09:09:09.917: SQL SELECT * FROM jobss
    Traceback (most recent call last):
    File "end-to-endtracing.py", line 14, in <module>
      cursor.execute("select * from jobss")
    oracledb.DatabaseError: ORA-00942: table or view does not exist

See `ODPI-C Debugging
<https://oracle.github.io/odpi/doc/user_guide/debugging.html>`__ for
documentation on ``DPI_DEBUG_LEVEL``.

Low Level Python-oracledb Driver Tracing
========================================

Low level tracing is mostly useful to maintainers of python-oracledb.

- For the python-oracledb Thin mode, packets can be traced by setting the
  environment variable::

      pyo_debug_packets=1

  Output goes to stdout. The logging is similar to an Oracle Net trace of
  level 16.

- The python-oracledb Thick mode can be traced using:

    - dpi_debug_level as documented in `ODPI-C Debugging
      <https://oracle.github.io/odpi/doc/user_guide/debugging.html>`__.

    - Oracle Call Interface (OCI) tracing as directed by Oracle Support.

    - Oracle Net services tracing as documented in `Oracle Net Services Tracing
      Parameters
      <https://docs.oracle.com/en/database/oracle/oracle-database/21/
      netrf/parameters-for-the-sqlnet.ora.html>`__
