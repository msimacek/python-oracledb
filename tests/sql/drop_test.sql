/*-----------------------------------------------------------------------------
 * Copyright 2020, 2022, Oracle and/or its affiliates.
 * This program is free software: you can modify it and/or redistribute it
 * under the terms of:
 * 
 * (i)  the Universal Permissive License v 1.0 or at your option, any
 *      later version (http://oss.oracle.com/licenses/upl); and/or
 * (ii) the Apache License v 2.0. (http://www.apache.org/licenses/LICENSE-2.0)
 *---------------------------------------------------------------------------*/

/*-----------------------------------------------------------------------------
 * drop_test.sql
 *
 * Drops database objects used for python-oracledb tests.
 *
 * Run this like:
 *     sqlplus sys/syspassword@hostname/servicename as sysdba @drop_test
 *---------------------------------------------------------------------------*/

whenever sqlerror exit failure

-- get parameters
set echo off termout on feedback off verify off
accept main_user char default pythontest -
        prompt "Name of main schema [pythontest]: "
accept proxy_user char default pythontestproxy -
        prompt "Name of proxy schema [pythontestproxy]: "
set feedback on

-- perform work
@@drop_test_exec.sql

exit
