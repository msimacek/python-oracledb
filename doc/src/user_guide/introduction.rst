.. _introduction:

********************************
Introduction to python-oracledb
********************************
python-oracledb is a Python extension module that enables access to Oracle Database 
using either one of its two modes: the python-oracledb Thin mode, which connects to the 
database directly, or, the python-oracledb Thick mode, which loads ODPI-C and Oracle Client
libraries to connect to Oracle Database using the Oracle Call Interface (OCI) API. 
python-oracledb conforms to the `Python Database API v2.0 Specification
<https://www.python.org/dev/peps/pep-0249/>`__ with a considerable number of
additions and a couple of exclusions.

Architecture
============

Python programs call python-oracledb functions. The connection to the Oracle Database
is established depending on the mode chosen and is detailed in the subsequent sections.
You can choose either the python-oracledb Thick mode or the python-oracledb Thin mode 
through an application script runtime option. By default, the python-oracledb Thin mode
is chosen.

The database can be on the same machine as Python, or it can be remote.

.. _archfig:
.. figure:: /images/python-oracledb-arch.png
  :alt: architecture for python-oracledb driver

  Architecture for python-oracledb driver

The figure shows the architecture of the python-oracledb driver for both
the Thin and Thick modes. Users interact with a Python application, for example
by making web requests. The application program makes calls to python-oracledb
functions. If the user has chosen the python-oracledb Thin mode, then the connection
to the Oracle Database is established directly. If the user has chosen the 
python-oracledb Thick mode, then python-oracledb dynamically loads 
Oracle Client libraries. These libraries provide the necessary network connectivity
to access the Oracle Database. Connections are then established from python-oracledb
to Oracle Database using the python-oracledb Thick mode.

python-oracledb is typically installed from `PyPI
<https://pypi.org/project/oracledb/>`__ using `pip
<https://pip.pypa.io/en/latest/installing/>`__.

python-oracledb Thin Mode Architecture
----------------------------------------

The python-oracledb Thin mode directly connects to the Oracle Database. 
The python-oracledb Thin mode does not require Oracle Client libraries.

.. _thinarchfig:
.. figure:: /images/python-oracledb-thin-arch.png
  :alt: architecture for python-oracledb Thin mode

  Architecture for python-oracledb Thin mode

The figure shows the architecture of the python-oracledb Thin mode. 
The application program makes calls to the python-oracledb functions. 
This directly connects to the Oracle Database.

python-oracledb Thick Mode Architecture
-----------------------------------------

The python-oracledb Thick mode dynamically loads Oracle Client libraries 
to access Oracle Database.

.. _thickarchfig:
.. figure:: /images/python-oracledb-thick-arch.png
  :alt: architecture for python-oracledb Thick mode

  Architecture for python-oracledb Thick mode

The figure shows the architecture of the python-oracledb Thick mode. 
The application program makes calls to the python-oracledb functions. 
Internally python-oracledb dynamically loads Oracle Client libraries. 
Connections are then established from python-oracledb to Oracle Database.

To use python-oracledb Thick mode, the Oracle Client libraries
can be installed separately.  The libraries can be from an installation of
`Oracle Instant Client
<https://www.oracle.com/database/technologies/instant-client.html>`__, from a
full Oracle Client installation, or even from an Oracle Database installation
(if Python is running on the same machine as the database). Oracle’s standard
client-server version interoperability allows connection to both older and
newer databases from different Client library versions, see :ref:`python-oracledb 
Installation <installation>`.

Some behaviors of the Oracle Client libraries can optionally be configured with
an ``oraaccess.xml`` file, for example to enable auto-tuning of a statement
cache.  See :ref:`optclientfiles`.

The Oracle Net layer can optionally be configured with files such as
``tnsnames.ora`` and ``sqlnet.ora``, for example to enable :ref:`network
encryption <netencrypt>`. See :ref:`optnetfiles`.

Oracle environment variables that are set before python-oracledb first creates a
database connection will affect python-oracledb behavior. Optional variables include
``NLS_LANG``, ``NLS_DATE_FORMAT``, and ``TNS_ADMIN``. See :ref:`envset`.


Feature Highlights of python-oracledb
======================================

The python-oracledb feature highlights are:

    *   Easy installation from PyPI
    *   Support for multiple Oracle Client and Database versions
    *   Execution of SQL and PL/SQL statements
    *   Extensive Oracle data type support, including large objects (``CLOB`` and
        ``BLOB``) and binding of SQL objects
    *   Connection management, including connection pooling
    *   Oracle Database High Availability features
    *   Full use of Oracle Network Service infrastructure, including encrypted
        network traffic and security features

The python-oracledb Thick mode has additional features in comparison to the 
python-oracledb Thin mode. See :ref:`driverdiff` for the differences between
python-oracledb the Thick and Thin modes. See :ref:`Feature Differences 
<appendixa>` for a complete list of differences between the python-oracledb 
and cx_Oracle 8.3 drivers.

Getting Started
===============

Install python-oracledb using the :ref:`installation <installation>` steps.

Create a script ``query.py`` as shown below:

.. code-block:: python

    # query.py

    import oracledb

    # Establish the database connection
    connection = oracledb.connect(user="hr", password=userpwd,
                                   dsn="dbhost.example.com/orclpdb1")

    # Obtain a cursor
    cursor = connection.cursor()

    # Data for binding
    manager_id = 145
    first_name = "Peter"

    # Execute the query
    sql = """SELECT first_name, last_name
             FROM employees
             WHERE manager_id = :mid AND first_name = :fn"""
    cursor.execute(sql, mid=manager_id, fn=first_name)

    # Loop over the result set
    for row in cursor:
        print(row)

This uses Oracle's `sample HR schema
<https://github.com/oracle/db-sample-schemas>`__.

Simple :ref:`connection <connhandling>` to the database requires a username,
password and connection string.  Locate your Oracle Database `user name and
password <https://www.youtube.com/watch?v=WDJacg0NuLo>`_ and the database
:ref:`connection string <connstr>`, and use them in ``query.py``. 
For python-oracledb, the connection string is commonly of the format
``hostname/servicename``, using the host name where the database is running and
the Oracle Database service name of the database instance.

The :ref:`cursor <cursorobj>` is the object that allows statements to be
executed and results (if any) fetched.

The data values in ``managerId`` and ``firstName`` are 'bound' to the statement
placeholder 'bind variables' ``:mid`` and ``:fn`` when the statement is
executed.  This separates the statement text from the data, which helps avoid
SQL Injection security risks.  :ref:`Binding <bind>` is also important for
performance and scalability.

The cursor allows rows to be iterated over and displayed.

Run the script::

    python query.py

The output is::

    ('Peter', 'Hall')
    ('Peter', 'Tucker')


Examples and Tutorials
======================

Runnable examples are in the `GitHub samples directory
<https://github.com/oracle/python-oracledb/tree/main/samples>`__.  
A `Python python-oracledb tutorial <https://oracle.github.io/python-oracledb
/samples/tutorial/Python-and-Oracle-Database-Scripting-for-the-Future.html>`__
is also available.
