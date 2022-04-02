/*-----------------------------------------------------------------------------
 * Copyright 2017, 2022, Oracle and/or its affiliates. 
 * This program is free software: you can modify it and/or redistribute it
 * under the terms of:
 *
 * (i)  the Universal Permissive License v 1.0 or at your option, any
 *      later version (http://oss.oracle.com/licenses/upl); and/or
 *
 * (ii) the Apache License v 2.0. (http://www.apache.org/licenses/LICENSE-2.0)
 *---------------------------------------------------------------------------*/

/*-----------------------------------------------------------------------------
 * drop_samples_exec.sql
 *
 * Performs the actual work of dropping the database schemas and edition used
 * by the python-oracledb samples. It is called by the drop_samples.sql and
 * setup_samples.sql scripts after acquiring the necessary parameters and also
 * by the Python script drop_samples.py.
 *---------------------------------------------------------------------------*/

begin

    for r in
            ( select username
              from dba_users
              where username in (upper('&main_user'), upper('&edition_user'))
            ) loop
        execute immediate 'drop user ' || r.username || ' cascade';
    end loop;

    for r in
            ( select edition_name
              from dba_editions
              where edition_name in (upper('&edition_name'))
            ) loop
        execute immediate 'drop edition ' || r.edition_name || ' cascade';
    end loop;

end;
/
