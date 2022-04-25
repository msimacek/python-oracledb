/*-----------------------------------------------------------------------------
 * drop_user.sql (Setup Section)
 *   Drops the database user used for the python-oracledb tutorial 
 *
 * Substitute your actual password and connection string.
 * For Oracle Autonomous Database, use 'admin' instead of system.
 * You will be prompted for the user to drop.
 *
 *---------------------------------------------------------------------------*/

/*-----------------------------------------------------------------------------
 * Copyright (c) 2017, 2022, Oracle and/or its affiliates.
 *---------------------------------------------------------------------------*/

begin
  dbms_aqadm.stop_queue('BOOKS');
  dbms_aqadm.drop_queue('BOOKS');
  dbms_aqadm.drop_queue_table('BOOK_QUEUE_TABLE');
  exception when others then
    if sqlcode <> -24010 then
      raise;
    end if;
  end;
/

begin

    for r in
            ( select username
              from dba_users
              where username in (upper('&user'))
            ) loop
        execute immediate 'drop user ' || r.username || ' cascade';
    end loop;
end;
/