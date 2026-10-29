-- File: 29_backup_recovery_and_rpo_rto.sql
-- Purpose: Capture recovery configuration and available RMAN job metadata.
-- Data collected: Archive/flashback configuration and V$RMAN_BACKUP_JOB_DETAILS.
-- Expected privileges: V_$DATABASE, V_$PARAMETER, V_$RMAN_BACKUP_JOB_DETAILS.
-- Scope: Database.
-- Oracle versions: 10g and later; RMAN detail view may be unavailable.
-- Licensing: No AWR/ASH; confirm all Oracle product/licensing questions separately.
-- Expected output: 29_backup_recovery.csv.
-- Sensitive metadata: Yes; backup cadence and recovery posture.
whenever sqlerror continue
spool "&output_dir./29_backup_recovery.csv"
prompt COLLECTION_UTC,DBID,ITEM,VALUE
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       dbid,'LOG_MODE',log_mode from v$database
union all
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       dbid,'FLASHBACK_ON',flashback_on from v$database
union all
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),'PARAMETER:'||name,value
  from v$parameter where name in ('db_recovery_file_dest','db_recovery_file_dest_size',
                                  'control_file_record_keep_time');
spool off
spool "&output_dir./29_rman_backup_jobs.csv"
prompt START_TIME,END_TIME,STATUS,INPUT_TYPE,OUTPUT_BYTES,ELAPSED_SECONDS
select to_char(start_time,'YYYY-MM-DD HH24:MI:SS'),
       to_char(end_time,'YYYY-MM-DD HH24:MI:SS'),status,input_type,
       output_bytes,elapsed_seconds
  from v$rman_backup_job_details
 where start_time >= sysdate-30
 order by start_time desc;
spool off
