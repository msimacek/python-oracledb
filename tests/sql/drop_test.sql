/*-----------------------------------------------------------------------------
 * Copyright 2020, 2022, Oracle and/or its affiliates.
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
