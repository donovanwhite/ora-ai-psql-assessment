-- File: 00_set_environment.sql
-- Purpose: Initialize SQL*Plus formatting and output directory.
-- Data collected: Run metadata only.
-- Expected privileges: Normal authenticated connection.
-- Scope: Session / database.
-- Oracle versions: 10g and later.
-- Licensing: None.
-- Expected output: run_environment.csv.
-- Sensitive metadata: Yes; contains database identity.
-- Script 99 calls this automatically for each output folder.
-- Manual rerun only: @00_set_environment.sql <EXISTING_OUTPUT_DIRECTORY>
whenever sqlerror continue
@@99_set_csv_format.sql
define output_dir = '&1'
spool "&output_dir./run_environment.csv"
prompt COLLECTION_UTC,DBID,DB_UNIQUE_NAME,INSTANCE,CURRENT_SCHEMA
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"') || ',' ||
       d.dbid || ',' || replace(d.db_unique_name,',',' ') || ',' ||
       i.instance_name || ',' || sys_context('USERENV','CURRENT_SCHEMA')
  from v$database d, v$instance i;
spool off
prompt Output directory initialized. Keep this SQL*Plus session open.
