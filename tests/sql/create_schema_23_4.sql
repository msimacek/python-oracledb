/*-----------------------------------------------------------------------------
 * Copyright (c) 2023, 2024, Oracle and/or its affiliates.
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
 * create_schema_23_4.sql
 *
 * Performs the actual work of creating and populating the schemas with the
 * database objects used by the python-oracledb test suite that require Oracle
 * Database 23.4 or higher. It is executed by the Python script
 * create_schema.py.
 *---------------------------------------------------------------------------*/

create domain &main_user..SimpleDomain as number(3, 0) NOT NULL
/

create table &main_user..TableWithDomainAndAnnotations (
    id number(9) not null,
    age number(3, 0) domain &main_user..SimpleDomain
    annotations (
        Anno_1 'first annotation',
        Anno_2 'second annotation',
        Anno_3
    )
)
/

insert into &main_user..TableWithDomainAndAnnotations values (1, 25)
/

commit
/

create table &main_user..TestVectors (
    IntCol                  number(9) not null,
    VectorFlexAllCol        vector,
    VectorFlexTypeCol       vector(2),
    VectorFlex8Col          vector(*, int8),
    VectorFlex32Col         vector(*, float32),
    VectorFlex64Col         vector(*, float64),
    Vector8Col              vector(16, int8),
    Vector32Col             vector(16, float32),
    Vector64Col             vector(16, float64)
)
/

create table &main_user..TestCompressedJson (
    IntCol number(9) not null,
    JsonCol json not null
)
json (JsonCol)
store as (compress high)
/

create table &main_user..TestBooleans (
    IntCol                  number(9) not null,
    BooleanCol1             boolean not null,
    BooleanCol2             boolean
)
/

--create tables for json duality views
create table &main_user..projects (
    proj_id           number PRIMARY KEY,
    proj_name         varchar2(100),
    proj_status       varchar2(100)
)
/

create table &main_user..specifications (
    proj_id           number,
    spec_id           number PRIMARY KEY,
    spec_name         varchar2(100),
    spec_url          varchar2(100),
    last_mod          timestamp,
    foreign key(proj_id) references &main_user..projects(proj_id)
)
/

create or replace json relational duality view &main_user..proj_dualv as
    select json {
        proj_id,
        proj_name,
        proj_status,
        'specs' : (
            select JSON_ArrayAgg(JSON{spec_id, spec_name, last_mod})
            from &main_user..specifications s with (insert, update, delete)
            where p.proj_id = s.proj_id
        ) NULL ON NULL
    }
    from &main_user..projects p with (insert, update, delete)
/

--create tables with proj_id as varchar2
create table &main_user..projects2 (
    proj_id           varchar2(100) PRIMARY KEY,
    proj_name         varchar2(100),
    proj_status       varchar2(100)
)
/

create table &main_user..specifications2 (
    proj_id           varchar2(100),
    spec_id           number PRIMARY KEY,
    spec_name         varchar2(100),
    spec_url          varchar2(100),
    last_mod          timestamp,
    foreign key(proj_id) references &main_user..projects2(proj_id)
)
/

create or replace json relational duality view &main_user..proj_dualv2 as
    select json {
        proj_id,
        proj_name,
        proj_status,
        'specs' : (
            select JSON_ArrayAgg(JSON{spec_id, spec_name, last_mod})
            from &main_user..specifications2 s with (insert, update, delete)
            where p.proj_id = s.proj_id
        ) NULL ON NULL
    }
    from &main_user..projects2 p with (insert, update, delete)
/
