-- File: 99_run_complete_assessment.sql
-- Purpose: Guide the operator through every supplied numbered Oracle collector.
-- Data collected: Database, approved schemas, and a paired workload interval.
-- Expected privileges: As documented in collectors; DBA_USERS, DBA_OBJECTS,
-- ALL_TAB_COLUMNS and DBMS_LOB are also used for the schema selection menu.
-- Scope: Current approved connection/container and explicitly selected owners.
-- Oracle versions: 10g and later; optional features may be unavailable.
-- Licensing: No AWR/ASH, source export, Statspack installation or configuration.
-- Expected output: A new output/run_<UTC>_<ID> tree and collection status file.
-- Sensitive metadata: Yes.
-- Prerequisites: Start SQL*Plus from the writable package root, connect
-- to the approved PDB/non-CDB, and agree schema scope and a workload interval.
-- Do not run this driver in a SQL Developer worksheet.
-- No passwords, grants, application rows or persistent database objects change.
whenever oserror exit failure rollback
whenever sqlerror exit failure rollback
set echo off
set verify off
set feedback off
set heading off
set pagesize 0
set linesize 32767
set trimspool on
set tab off
set serveroutput on size 1000000
set termout on
variable assessment_selected clob

prompt COMPLETE ORACLE COLLECTION - current connection only.
prompt SUPPORTED COLLECTION CLIENT: SQL*Plus only.
prompt Start from the extracted package root, not an Oracle installation folder.
prompt This driver creates a unique output folder; previous runs are not reused.
accept assessment_client_os number default 1 prompt 'Client OS: 1=Windows, 2=Linux/macOS [1]: '
begin
  if &assessment_client_os not in (1,2) then
    raise_application_error(-20001,'Choose client OS 1 or 2.');
  end if;
end;
/
@@99_show_connection.sql
prompt Confirm the ACTIVE CONTAINER/PDB shown in the summary, not the login schema.
prompt If this is the wrong container, enter 0 and reconnect to the approved PDB.
accept assessment_scope_confirm number default 0 prompt 'Approved current database/container? 1=yes, 0=stop [0]: '
begin
  if &assessment_scope_confirm <> 1 then
    raise_application_error(-20002,'Scope not confirmed. Reconnect to the approved container before restarting.');
  end if;
end;
/
column assessment_run_dir new_value assessment_run_dir noprint
select 'output/run_' ||
       to_char(sys_extract_utc(systimestamp),'YYYYMMDD_HH24MISS') || '_' ||
       lower(rawtohex(sys_guid())) assessment_run_dir
  from dual;
column assessment_mkdir new_value assessment_mkdir noprint
select case &assessment_client_os
         when 1 then 'mkdir "' ||
           replace('&assessment_run_dir./oracle/database','/',chr(92)) || '" "' ||
           replace('&assessment_run_dir./oracle/schemas','/',chr(92)) || '" "' ||
           replace('&assessment_run_dir./performance/window_01','/',chr(92)) || '"'
         else 'mkdir -p -m 700 "&assessment_run_dir./oracle/database" ' ||
           '"&assessment_run_dir./oracle/schemas" ' ||
           '"&assessment_run_dir./performance/window_01"'
       end assessment_mkdir
  from dual;
host &assessment_mkdir

@@00_set_environment.sql "&assessment_run_dir./oracle/database"
@@01_assessment_precheck.sql
@@02_database_identity_and_version.sql
@@03_instance_and_host_configuration.sql
@@04_cdb_pdb_inventory.sql
@@05_initialization_parameters.sql
@@06_character_set_and_nls.sql
@@07_tablespace_and_storage.sql

whenever sqlerror exit failure rollback
@@99_show_connection.sql
variable assessment_catalog clob
variable assessment_catalog_count number
declare
  candidates sys_refcursor;
  candidate_owner varchar2(128);
  object_count number;
  has_maintained_column number;
  owner_query varchar2(2000);
begin
  dbms_lob.createtemporary(:assessment_catalog,true);
  dbms_lob.createtemporary(:assessment_selected,true);
  :assessment_catalog_count := 0;
  select count(*) into has_maintained_column
    from all_tab_columns
   where owner='SYS' and table_name='DBA_USERS'
     and column_name='ORACLE_MAINTAINED';
  owner_query :=
    'select u.username, (select count(*) from dba_objects o where o.owner=u.username) ' ||
    'from dba_users u where regexp_like(u.username,''^[A-Z][A-Z0-9_$#]*$'') ' ||
    'and u.username not in (''SYS'',''SYSTEM'') ';
  if has_maintained_column > 0 then
    owner_query := owner_query || 'and u.oracle_maintained=''N'' ';
  else
    dbms_output.put_line('Oracle-maintained flags unavailable: choose only DBA-approved application owners.');
  end if;
  open candidates for owner_query || 'order by u.username';
  dbms_output.put_line('SCHEMA NUMBER | OWNER | OBJECT COUNT');
  loop
    fetch candidates into candidate_owner, object_count;
    exit when candidates%notfound;
    :assessment_catalog_count := :assessment_catalog_count + 1;
    dbms_lob.writeappend(:assessment_catalog,length(candidate_owner)+1,candidate_owner || ',');
    dbms_output.put_line(to_char(:assessment_catalog_count) || ' | ' ||
                         candidate_owner || ' | ' || to_char(object_count));
  end loop;
  close candidates;
  if :assessment_catalog_count = 0 then
    raise_application_error(-20003,'No supported schema owners found. Confirm the PDB and catalog privileges with the DBA.');
  end if;
  dbms_output.put_line('Only standard unquoted owners are listed. Quoted/mixed-case owners need a DBA-reviewed manual collection.');
end;
/
prompt Select only owners explicitly approved for assessment, not every account.
prompt Supply each approved owner once, using its schema NUMBER from this menu.
accept assessment_schema_count number default 1 prompt 'How many approved schema owners will you select [1]? '
begin
  if &assessment_schema_count < 1 or
     &assessment_schema_count <> trunc(&assessment_schema_count) or
     &assessment_schema_count > :assessment_catalog_count then
    raise_application_error(-20004,'Schema count must be a positive whole number within the displayed catalog.');
  end if;
end;
/

set termout off
spool "&assessment_run_dir./_collect_schemas.sql"
prompt -- Generated approved-schema driver. Contains no credentials.
spool off
spool "&assessment_run_dir./_select_schemas.sql"
select '@scripts/oracle/99_select_schema.sql'
  from dual connect by level <= &assessment_schema_count;
spool off
set termout on
@"&assessment_run_dir./_select_schemas.sql"

prompt Collecting remaining database and instance evidence.
@@18_sessions_connections_and_concurrency.sql
@@19_memory_and_sga_pga.sql
@@20_io_and_redo_profile.sql
@@25_rac_inventory.sql
@@26_asm_inventory.sql
@@27_data_guard_inventory.sql
@@28_growth_and_capacity.sql
@@29_backup_recovery_and_rpo_rto.sql
@@30_awareness_of_aws_ash_licensing.sql

prompt Collecting every schema collector for each approved owner.
@"&assessment_run_dir./_collect_schemas.sql"
whenever sqlerror exit failure rollback
begin
  dbms_lob.freetemporary(:assessment_catalog);
  :assessment_catalog := null;
end;
/

@@99_show_connection.sql
whenever sqlerror exit failure rollback
prompt Workload collection uses the same current database/container.
prompt Enter the representative interval agreed with the DBA/application owner.
prompt There is no automatic workload generation, AWR access or Statspack change.
accept assessment_window_minutes number default 0 prompt 'Approved workload interval in minutes (greater than 0): '
begin
  if &assessment_window_minutes <= 0 then
    raise_application_error(-20005,'Agree a positive representative workload interval before continuing.');
  end if;
end;
/
@@00_set_environment.sql "&assessment_run_dir./performance/window_01"
variable assessment_window_start varchar2(14)
variable assessment_expected_dbid number
variable assessment_expected_container varchar2(128)
variable assessment_expected_startups clob
variable assessment_workload_complete number
begin
  select dbid into :assessment_expected_dbid from v$database;
  if dbms_db_version.version >= 12 then
    :assessment_expected_container := sys_context('USERENV','CON_NAME');
  else
    :assessment_expected_container := '(non-CDB)';
  end if;
  dbms_lob.createtemporary(:assessment_expected_startups,true);
  for r in (select inst_id,instance_name,startup_time from gv$instance order by inst_id) loop
    declare
      marker varchar2(300);
    begin
      marker := to_char(r.inst_id,'TM9') || '|' || r.instance_name || '|' ||
                to_char(r.startup_time,'YYYYMMDDHH24MISS') || ';';
      dbms_lob.writeappend(:assessment_expected_startups,length(marker),marker);
    end;
  end loop;
  :assessment_workload_complete := 0;
end;
/
@@21_workload_counters_snapshot_start.sql
begin
  :assessment_window_start :=
    to_char(sys_extract_utc(systimestamp),'YYYYMMDDHH24MISS');
end;
/
@@99_write_workload_resume.sql
@@99_show_connection.sql
prompt START snapshot captured. Observe the approved representative workload now.
begin
  dbms_output.put_line('Timer START (UTC) : ' ||
    to_char(to_date(:assessment_window_start,'YYYYMMDDHH24MISS'),'YYYY-MM-DD HH24:MI:SS'));
  dbms_output.put_line('Earliest END (UTC): ' ||
    to_char(to_date(:assessment_window_start,'YYYYMMDDHH24MISS') +
      ceil(&assessment_window_minutes * 60)/86400,'YYYY-MM-DD HH24:MI:SS'));
end;
/
prompt Recovery file saved; your completed inventory and START files are retained.
prompt &assessment_run_dir./resume_workload.sql
pause Press Enter to check whether the approved workload interval has finished.
@@99_complete_workload.sql
