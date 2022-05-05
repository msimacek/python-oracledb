.. _introduction:

**************************************************
Introduction to Python Driver for Oracle Database
**************************************************
The Python driver for Oracle Database (python-oracledb) is a Python extension module
that enables access to Oracle Database using either one of its two modes:
the python-oracledb Thin mode, which connects to the database directly, or, the
python-oracledb Thick mode, which loads ODPI-C and Oracle Client
libraries to connect to Oracle Database using the Oracle Call Interface (OCI) API.
python-oracledb conforms to the `Python Database API v2.0 Specification
<https://www.python.org/dev/peps/pep-0249/>`__ with a considerable number of
additions and a couple of exclusions.

Architecture
============

The connection to the Oracle Database is established depending on the mode chosen.
You can choose either the python-oracledb Thick mode or the python-oracledb Thin mode
through an application script runtime option. By default, the python-oracledb Thin mode
is chosen.

The database can be on the same machine as Python, or it can be remote.

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
Users interact with a Python application, for example by making web
requests. The application program makes calls to python-oracledb
functions. The connection from python-oracledb Thin mode to the
Oracle Database is established directly.

python-oracledb Thick Mode Architecture
-----------------------------------------

The python-oracledb Thick mode dynamically loads Oracle Client libraries
to access Oracle Database.

.. _thickarchfig:
.. figure:: /images/python-oracledb-thick-arch.png
  :alt: architecture for python-oracledb Thick mode

  Architecture for python-oracledb Thick mode

The figure shows the architecture of the python-oracledb Thick mode.
Users interact with a Python application, for example by making web
requests. The application program makes calls to python-oracledb
functions. Internally, python-oracledb dynamically loads Oracle Client libraries.
Connections from python-oracledb Thick mode to Oracle Database are
established using the Oracle Client libraries.

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
database connection may affect python-oracledb behavior.  See :ref:`envset`.


Feature Highlights of python-oracledb
======================================

The python-oracledb feature highlights are:

    *   Easy installation from PyPI
    *   Support for multiple Oracle Database versions
    *   Execution of SQL and PL/SQL statements
    *   Extensive Oracle data type support, including JSON, large objects (``CLOB`` and
        ``BLOB``) and binding of SQL objects
    *   Connection management, including connection pooling
    *   Oracle Database High Availability features
    *   Full use of Oracle Network Service infrastructure, including encrypted
        network traffic

See :ref:`Feature List <appendixa>` for more information.

Getting Started
===============

See `Quick Start python-oracledb Installation <Quick Start python-oracledb Installation>`_.


Examples and Tutorial
=====================

Runnable examples are in the `GitHub samples directory
<https://github.com/oracle/python-oracledb/tree/main/samples>`__.
A tutorial `Python and Oracle Database Tutorial: The New Wave of Scripting
<https://oracle.github.io/python-oracledb
/samples/tutorial/Python-and-Oracle-Database-Scripting-for-the-Future.html>`__
is also available.
