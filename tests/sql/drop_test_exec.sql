/*-----------------------------------------------------------------------------
 * Copyright (c) 2020, 2022, Oracle and/or its affiliates.
 * This program is free software: you can modify it and/or redistribute it
 * under the terms of:
 * 
 * (i)  the Universal Permissive License v 1.0 or at your option, any
 *      later version (http://oss.oracle.com/licenses/upl); and/or
 * (ii) the Apache License v 2.0. (http://www.apache.org/licenses/LICENSE-2.0)
 *---------------------------------------------------------------------------*/

/*-----------------------------------------------------------------------------
 * drop_test_exec.sql
 *
 * Performs the actual work of dropping the database schemas used by the
 * python-oracledb test suite. It is called by the drop_test.sql and
 * setup_test.sql scripts after acquiring the necessary parameters and also by
 * the Python script drop_test.py.
 *---------------------------------------------------------------------------*/

begin

    for r in
            ( select username
              from dba_users
              where username in (upper('&main_user'), upper('&proxy_user'))
            ) loop
        execute immediate 'drop user ' || r.username || ' cascade';
    end loop;

end;
/
