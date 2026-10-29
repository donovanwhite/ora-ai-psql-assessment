-- Copyright (c) Microsoft Corporation.
-- SPDX-License-Identifier: MIT
--
-- List Statspack snapshots available for a representative assessment window.
-- Optional existing Statspack workflow, step 1 of 2; not the base inventory.
-- Usage from the package root:
-- @scripts\perfstat\01_list_perfstat_snapshots.sql <output-directory> <perfstat-owner>

whenever oserror exit failure rollback
whenever sqlerror exit failure rollback

set define on
set verify off
set echo off
set feedback off
set heading off
set pagesize 0
set linesize 32767
set trimspool on
set termout off
set tab off

define output_dir = '&1'
define perfstat_owner = '&2'

declare
  l_table_count number;
begin
  select count(*)
    into l_table_count
    from all_tables
   where owner = upper('&&perfstat_owner')
     and table_name in (
       'STATS$SNAPSHOT',
       'STATS$SYSSTAT',
       'STATS$SYS_TIME_MODEL',
       'STATS$SYSTEM_EVENT'
     );

  if l_table_count <> 4 then
    raise_application_error(
      -20010,
      'Statspack tables are not visible in owner ' || upper('&&perfstat_owner')
    );
  end if;
end;
/

spool "&output_dir./snapshot_catalog.csv"
prompt "dbid","instance_number","snap_id","snap_time","startup_time","snap_level"

select '"' || to_char(s.dbid, 'fm99999999999999999990') || '","' ||
       to_char(s.instance_number, 'fm9999999990') || '","' ||
       to_char(s.snap_id, 'fm99999999999999999990') || '","' ||
       to_char(s.snap_time, 'YYYY-MM-DD"T"HH24:MI:SS') || '","' ||
       to_char(s.startup_time, 'YYYY-MM-DD"T"HH24:MI:SS') || '","' ||
       to_char(s.snap_level, 'fm9999999990') || '"'
  from &&perfstat_owner..stats$snapshot s
 where s.dbid = (select dbid from v$database)
 order by s.instance_number, s.snap_id;

spool off
set termout on
exit success