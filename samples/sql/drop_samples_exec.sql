/*-----------------------------------------------------------------------------
 * Copyright 2017, 2022, Oracle and/or its affiliates. All rights reserved.
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
