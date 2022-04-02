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
 * drop_samples.sql
 *
 * Drops database objects used for python-oracledb samples.
 *
 * Run this like:
 *     sqlplus sys/syspassword@hostname/servicename as sysdba @drop_samples
 *---------------------------------------------------------------------------*/

whenever sqlerror exit failure

-- get parameters
set echo off termout on feedback off verify off
accept main_user char default pythondemo -
        prompt "Name of main schema [pythondemo]: "
accept edition_user char default pythoneditions -
        prompt "Name of edition schema [pythoneditions]: "
accept edition_name char default python_e1 -
        prompt "Name of edition [python_e1]: "
set feedback on

-- perform work
@@drop_samples_exec.sql

exit
