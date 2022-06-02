---
name: Installation Problems
about: Use this for python-oracledb installation questions
title: ''
labels: install & configuration
assignees: ''

---

<!--

Thank you for using python-oracledb.

Do these before creating a new issue:

    Review and follow the Installation Instructions: https://python-oracledb.readthedocs.io/en/latest/user_guide/installation.html

    Review the troubleshooting tips: https://python-oracledb.readthedocs.io/en/latest/user_guide/installation.html#troubleshooting

    Review the user manual: https://python-oracledb.readthedocs.io/en/latest/index.html

If you have a `DPI-1047`, `DPI-1050` or `DPI-1072` error, re-review the links above.

Google any errors.

Then please answer these questions so we can help you.

GitHub issues that are not updated for a month may be automatically closed.  Feel free to update them at any time.

-->

1. What versions are you using?

<!--

Give your database version.

Also run Python and show the output of:

    import sys
    import platform

    print("platform.platform:", platform.platform())
    print("sys.maxsize > 2**32:", sys.maxsize > 2**32)
    print("platform.python_version:", platform.python_version())

-->

2. Describe the problem

<!-- Cut and paste text showing the command you ran.  No screenshots. -->

3. If you are trying to use Oracle Client libraries then:

   3a. What version, and where are they installed (e.g. the Instant Client directory)?

   3b. Are they 64-bit or 32-bit?

   3c. On Windows, what is the version of your VS Redistributable?

   3d. Show the `PATH` environment variable (on Windows) or `LD_LIBRARY_PATH` (on Linux) values?

4. Show any Oracle environment variables set (e.g. TNS_ADMIN, ORACLE_HOME, ORACLE_BASE).
