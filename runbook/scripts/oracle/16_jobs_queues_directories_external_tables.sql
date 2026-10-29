-- File: 16_jobs_queues_directories_external_tables.sql
-- Purpose: Inventory jobs, queues, directories and external tables for one schema.
-- Data collected: Scheduler/legacy job metadata and selected DBA catalog rows.
-- Expected privileges: DBA_SCHEDULER_JOBS, DBA_JOBS, DBA_QUEUES, DBA_DIRECTORIES,
-- DBA_EXTERNAL_TABLES; missing/version-specific views may report errors.
-- Scope: Database and schema.
-- Oracle versions: 10g and later; newer views/features are version dependent.
-- Licensing: None.
-- Expected output: 16_jobs_queues_directories_<OWNER>.csv.
-- Sensitive metadata: Yes; job actions are omitted.
-- Argument &1 must be one approved Oracle identifier.
whenever sqlerror continue
spool "&output_dir./16_jobs_queues_directories_&1..csv"
prompt COLLECTION_UTC,DBID,OWNER,CATEGORY,OBJECT_NAME,DETAIL
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),owner,'SCHEDULER_JOB',job_name,
       'ENABLED='||enabled||';STATE='||state
  from dba_scheduler_jobs where owner=upper('&1')
union all
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),log_user,'DBMS_JOB',to_char(job),
       'BROKEN='||broken
  from dba_jobs where log_user=upper('&1')
union all
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),owner,'QUEUE',name,
       'QUEUE_TABLE='||queue_table
  from dba_queues where owner=upper('&1')
union all
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),owner,'EXTERNAL_TABLE',table_name,
       'TYPE='||default_directory_name
  from dba_external_tables where owner=upper('&1')
order by 3,4,5;
spool off
spool "&output_dir./16_directories.csv"
prompt COLLECTION_UTC,DBID,OWNER,DIRECTORY_NAME,DIRECTORY_PATH
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),owner,directory_name,replace(directory_path,',',' ')
  from dba_directories order by owner,directory_name;
spool off
