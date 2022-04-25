/*-----------------------------------------------------------------------------
 * create_user.sql (Setup Section)
 *   Creates a database user for the python-oracledb tutorial
 * For Oracle Autonomous Database, use 'admin' instead of system.
 * You will be prompted for the new username and the new password to use.
 *
 * When you no longer need this user, run drop_user.sql to drop the user
 *
 *---------------------------------------------------------------------------*/

/*-----------------------------------------------------------------------------
 * Copyright (c) 2017, 2022, Oracle and/or its affiliates.
 *---------------------------------------------------------------------------*/

create user &user
/

grant
    create session,
    create table,
    create procedure,
    create type,
    create sequence,
    select any dictionary,
    unlimited tablespace
to &user
/

begin

    for r in
            ( select role
              from dba_roles
              where role in ('SODA_APP', 'AQ_ADMINISTRATOR_ROLE')
            ) loop
        execute immediate 'grant ' || r.role || ' to &user';
    end loop;

end;
/

alter user &user identified by "&pw"
/