.. _exception:

*******************
Handling Exceptions
*******************

All exceptions raised by python-oracledb are inherited from :attr:`oracledb.Error`.
See :ref:`Exceptions <exceptions>` for more details on the various exceptions
defined by python-oracledb. See the exception handling section in the
:ref:`API manual <exchandling>` for more details on the information available
when an exception is raised.

.. need to confirm with Chris on the below info

The exception types in the python-oracledb driver are similar to cx_Oracle 8.3 
and follow this approach:

  - 1000-1999: exceptions.InterfaceError
  - 2000-2999: exceptions.ProgrammingError
  - 3000-3999: exceptions.NotSupportedError
  - 4000-4999: exceptions.DatabaseError
  - 5000-5999: exceptions.InternalError
  - 6000-6999: exceptions.OperationalError

.. note::

   Some of the errors like DPY-6001 are OperationalError which is a subclass 
   of DatabaseError. These exceptions can be caught in the same way as in 
   cx_Oracle 8.3.

Applications can catch exceptions as needed. For example, when trying to add a
customer that already exists in the database, the following could be used
to catch the exception:

.. code-block:: python

    try:
        cursor.execute("insert into customer values (101, 'Customer A')")
    except oracledb.IntegrityError:
        print("Customer ID already exists")
    else:
        print("Customer added")


If information about the exception needs to be processed instead, the following
code can be used:

.. code-block:: python

    try:
        cursor.execute("insert into customer values (101, 'Customer A')")
    except oracledb.IntegrityError as e:
        error_obj, = e.args
        print("Customer ID already exists")
        print("Error Code:", error_obj.code)
        print("Error Full Code:", error_obj.full_code)
        print("Error Message:", error_obj.message)
    else:
        print("Customer added")
