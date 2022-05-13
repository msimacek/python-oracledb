.. _globalization:

*********************************************
Working with Character Sets and Globalization
*********************************************

Data fetched from, and sent to, Oracle Database will be mapped between the
database character set and the "Oracle client" character set of the Oracle
Client libraries used by python-oracledb. If data cannot be correctly mapped between
client and server character sets, then it may be corrupted or queries may fail
with :ref:`"codec can't decode byte" <codecerror>`.

All database character sets are supported by the python-oracledb Thick mode.
The database performs any required conversion for the python-oracledb Thin mode.
For `national character sets <https://docs.oracle.com/en/database/oracle/oracle-database
/21/nlspg/choosing-character-set.html#GUID-4E12D991-C286-4F1A-AFC6-F35040A5DE4F>`__:

    - AL16UTF16 is supported by both the python-oracledb Thin and Thick modes
    - UTF8 is not supported by the python-oracledb Thin mode

python-oracledb Thick mode uses Oracle's National Language Support (NLS) to assist in
globalizing applications.

.. note::

    All NLS_* environment variables are ignored by the python-oracledb Thin mode.

For more information, see the `Database Globalization Support Guide
<https://www.oracle.com/pls/topic/lookup?ctx=dblatest&id=NLSPG>`__.

You can change the following settings in the python-oracledb Thick mode with
``ALTER SESSION`` statement or by using the initialization parameter file.

    - NLS_CALENDAR: Calendar system
    - NLS_COMP: SQL, PL/SQL operator comparison
    - NLS_CURRENCY: Local currency symbol
    - NLS_DATE_FORMAT: Date format
    - NLS_DATE_LANGUAGE: Language for day and month names
    - NLS_DEBIT: Debit accounting symbol
    - NLS_DUAL_CURRENCY: Dual currency symbol
    - NLS_ISO_CURRENCY: ISO international currency symbol
    - NLS_LANGUGAGE: Language
    - NLS_LENGTH_SEMANTICS: How strings are treated
    - NLS_NCHAR_CONV_EXCP: Reports data loss during a character type conversion
    - NLS_NUMERIC_CHARACTERS: Decimal character and group separator
    - NLS_SORT: Collation
    - NLS_TERRITORY: Territory
    - NLS_TIMESTAMP_FORMAT: Timestamp
    - NLS_TIMESTAMP_TZ_FORMAT: Timestamp with time zone

The following settings can be defined only through environment variables
and hence are not supported in the python-oracledb Thin mode.

    - NLS_LANG: Language, territory, character set
    - NLS_CREDIT: Credit accounting symbol
    - NLS_DEBIT: Debit accounting symbol
    - NLS_LIST_SEPARATOR: Character that separates items in a list
    - NLS_MONETARY_CHARACTERS: Monetary symbol for dollar and cents (or their equivalents)


Setting the Client Character Set
================================

In cx_Oracle 8, the default encoding used for all character data changed to
"UTF-8". This universal encoding is suitable for most applications.  If you
have a special need, you can pass the ``encoding`` and ``nencoding`` parameters
to the :meth:`oracledb.connect` and :meth:`oracledb.create_pool` methods to
specify different Oracle Client character sets. For example:

.. code-block:: python

    import oracledb
    connection = oracledb.connect(dsn=connect_string, encoding="US-ASCII",
                                   nencoding="UTF-8")

.. note::

    In a future release of cx_Oracle, only UTF-8 will be supported.

The ``encoding`` parameter affects character data such as VARCHAR2 and CLOB
columns.  The ``nencoding`` parameter affects "National Character" data such as
NVARCHAR2 and NCLOB.  If you are not using national character types, then you
can omit ``nencoding``. Both the ``encoding`` and ``nencoding`` parameters are
expected to be one of the `Python standard encodings
<https://docs.python.org/3/library/codecs.html#standard-encodings>`__ such as
``UTF-8``. Do not accidentally use ``UTF8``, which Oracle uses to specify the
older Unicode 3.0 Universal character set, ``CESU-8``. Note that Oracle does
not recognize all of the encodings that Python recognizes. You can see which
encodings are usable in python-oracledb by issuing this query:

.. code-block:: sql

    select distinct utl_i18n.map_charset(value)
    from v$nls_valid_values
    where parameter = 'CHARACTERSET'
      and utl_i18n.map_charset(value) is not null
    order by 1

.. note::

    From cx_Oracle 8, it is no longer possible to change the character set
    using the ``NLS_LANG`` environment variable.  The character set component
    of that variable is ignored.  The language and territory components of
    ``NLS_LANG`` are still respected by the Oracle Client libraries.

Character Set Example
---------------------

The script below tries to display data containing a Euro symbol from the
database.

.. code-block:: python

    connection = oracledb.connect(user=user, password=password,
                                   dsn="dbhost.example.com/orclpdb1",
                                   encoding="US-ASCII")
    cursor = connection.cursor()
    for row in cursor.execute("select nvarchar2_column from nchar_test"):
        print(row)

Because the '€' symbol is not supported by the ``US-ASCII`` character set, all
'€' characters are replaced by '¿' in the python-oracledb output::

    ('¿',)

When the ``encoding`` parameter is removed (or set to "UTF-8") during
connection:

.. code-block:: python

    connection = oracledb.connect(user=user, password=password,
                                   dsn="dbhost.example.com/orclpdb1")

Then the output displays the Euro symbol as desired::

    ('€',)

.. _findingcharset:

Finding the Database and Client Character Set
---------------------------------------------

To find the database character set, execute the query:

.. code-block:: sql

    SELECT value AS db_charset
    FROM nls_database_parameters
    WHERE parameter = 'NLS_CHARACTERSET';

To find the database 'national character set' used for NCHAR and related types,
execute the query:

.. code-block:: sql

     SELECT value AS db_ncharset
     FROM nls_database_parameters
     WHERE parameter = 'NLS_NCHAR_CHARACTERSET';

To find the current "client" character set used by python-oracledb, execute the
query:

.. code-block:: sql

    SELECT DISTINCT client_charset AS client_charset
    FROM v$session_connect_info
    WHERE sid = SYS_CONTEXT('USERENV', 'SID');

If these character sets do not match, characters transferred over Oracle Net
will be mapped from one character set to another.  This may impact performance
and may result in invalid data.

Setting the Oracle Client Locale in python-oracledb Thick Mode
==============================================================

You can use the ``NLS_LANG`` environment variable to set the language and
territory used by the Oracle Client libraries.  For example, on Linux you could
set::

    export NLS_LANG=JAPANESE_JAPAN

The language ("JAPANESE" in this example) specifies conventions such as the
language used for Oracle Database messages, sorting, day names, and month
names.  The territory ("JAPAN") specifies conventions such as the default date,
monetary, and numeric formats. If the language is not specified, then the value
defaults to AMERICAN.  If the territory is not specified, then the value is
derived from the language value.  See `Choosing a Locale with the NLS_LANG
Environment Variable
<https://www.oracle.com/pls/topic/lookup?ctx=dblatest&id=GUID-86A29834-AE29-4BA5-8A78-E19C168B690A>`__

If the ``NLS_LANG`` environment variable is set in the application with
``os.environ['NLS_LANG']``, it must be set before any connection pool is
created, or before any standalone connections are created.

Other Oracle globalization variables, such as ``NLS_DATE_FORMAT`` can also be
set to change the behavior of python-oracledb Thick, see `Setting NLS Parameters
<https://www.oracle.com/pls/topic/lookup?ctx=dblatest&
id=GUID-6475CA50-6476-4559-AD87-35D431276B20>`__.

Setting Locale-aware Number and Date Conversions in python-oracledb Thin Mode
================================================================================

In python-oracledb Thick mode, Oracle NLS routines convert numbers and dates to strings
in the locale specific format.

In python-oracledb Thin mode, output type handlers can be used to perform similar
conversions. The examples below show a simple conversion and also how the
Python locale module can be used.

To convert numbers:

.. code-block:: python

    import locale
    import oracledb

    # use this if the environment variable LANG is already set
    #locale.setlocale(locale.LC_ALL, '')

    # use this for programmatic setting of locale
    locale.setlocale(locale.LC_ALL, 'de_DE.UTF-8')

    DSN = 'user/password@host/service_name'

    # simple naive conversion
    def type_handler1(cursor, name, default_type, size, precision, scale):
        if default_type == oracledb.DB_TYPE_NUMBER:
            return cursor.var(oracledb.DB_TYPE_VARCHAR, arraysize=cursor.arraysize,
                    outconverter=lambda v: v.replace('.', ','))

    # locale conversion
    def type_handler2(cursor, name, default_type, size, precision, scale):
        if default_type == oracledb.DB_TYPE_NUMBER:
            return cursor.var(default_type, arraysize=cursor.arraysize,
                    outconverter=lambda v: locale.format_string("%g", v))


    conn = oracledb.connect(DSN)
    cursor = conn.cursor()

    print("no type handler...")
    cursor.execute("select 2.5 from dual")
    for row in cursor:
        print(row)       # gives 2.5
    print()

    print("with naive type handler...")
    conn.outputtypehandler = type_handler1
    cursor.execute("select 2.5 from dual")
    for row in cursor:
        print(row)       # gives '2,5'
    print()

    print("with locale type handler...")
    conn.outputtypehandler = type_handler2
    cursor.execute("select 2.5 from dual")
    for row in cursor:
        print(row)       # gives '2,5'
    print()


To convert dates:

.. code-block:: python

    import locale
    import oracledb

    # use this if the environment variable LANG is already set
    #locale.setlocale(locale.LC_ALL, '')

    # use this for programmatic setting of locale
    locale.setlocale(locale.LC_ALL, 'de_DE.UTF-8')
    locale_date_format = locale.nl_langinfo(locale.D_T_FMT)

    DSN = 'user/password@host/service_name'

    # simple naive conversion
    def type_handler3(cursor, name, default_type, size, precision, scale):
        if default_type == oracledb.DB_TYPE_DATE:
            return cursor.var(default_type, arraysize=cursor.arraysize,
                    outconverter=lambda v: v.strftime("%Y-%m-%d %H:%M:%S"))

    # locale conversion
    def type_handler4(cursor, name, default_type, size, precision, scale):
        if default_type == oracledb.DB_TYPE_DATE:
            return cursor.var(default_type, arraysize=cursor.arraysize,
                    outconverter=lambda v: v.strftime(locale_date_format))


    conn = oracledb.connect(DSN)
    cursor = conn.cursor()

    print("no type handler...")
    cursor.execute("select sysdate from dual")
    for row in cursor:
        print(row)       # gives datetime.datetime(2021, 12, 15, 19, 49, 37)
    print()

    print("with naive type handler...")
    conn.outputtypehandler = type_handler3
    cursor.execute("select sysdate from dual")
    for row in cursor:
        print(row)       # gives '2021-12-15 19:49:37'
    print()

    print("with locale type handler...")
    conn.outputtypehandler = type_handler4
    cursor.execute("select sysdate from dual")
    for row in cursor:
        print(row)       # gives 'Mi 15 Dez 19:57:56 2021'
    print()
