/*-----------------------------------------------------------------------------
 * Copyright 2017, 2022, Oracle and/or its affiliates.
 *
 * This software is dual-licensed to you under the Universal Permissive License
 * (UPL) 1.0 as shown at https://oss.oracle.com/licenses/upl and Apache License
 * 2.0 as shown at http://www.apache.org/licenses/LICENSE-2.0. You may choose
 * either license.*
 *
 * If you elect to accept the software under the Apache License, Version 2.0,
 * the following applies:
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *---------------------------------------------------------------------------*/

/*-----------------------------------------------------------------------------
 * setup_samples.sql
 *
 * Creates and populates schemas with the database objects used by the
 * python-oracledb samples. An edition is also created for the demonstration of
 * PL/SQL editioning.
 *
 * Run this like:
 *     sqlplus sys/syspassword@hostname/servicename as sysdba @setup_samples
 *---------------------------------------------------------------------------*/

whenever sqlerror exit failure

-- get parameters
set echo off termout on feedback off verify off
accept main_user char default pythondemo -
        prompt "Name of main schema [pythondemo]: "
accept main_password char prompt "Password for &main_user: " HIDE
accept edition_user char default pythoneditions -
        prompt "Name of edition schema [pythoneditions]: "
accept edition_password char prompt "Password for &edition_user: " HIDE
accept edition_name char default python_e1 -
        prompt "Name of edition [python_e1]: "
set feedback on

-- perform work
@@drop_samples_exec.sql
@@setup_samples_exec.sql

exit
