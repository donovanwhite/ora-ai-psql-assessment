-- File: 24_wait_events_and_system_metrics.sql
-- Purpose: Capture cumulative wait profile and short-window system metrics.
-- Data collected: GV$SYSTEM_EVENT and GV$SYSMETRIC where available.
-- Expected privileges: GV_$SYSTEM_EVENT, GV_$SYSMETRIC.
-- Scope: Instance; preserve INST_ID.
-- Oracle versions: 10g and later; SYSMETRIC availability/fields vary.
-- Licensing: None; does not query AWR or ASH.
-- Expected output: 24_wait_events.csv and 24_system_metrics.csv.
-- Sensitive metadata: Workload metadata.
whenever sqlerror continue
spool "&output_dir./24_wait_events.csv"
prompt COLLECTION_UTC,DBID,INST_ID,EVENT,WAIT_CLASS,TOTAL_WAITS,TIME_WAITED,CAPTURE_SCOPE
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),inst_id,replace(event,',',' '),
       wait_class,total_waits,time_waited,'CUMULATIVE_SINCE_STARTUP'
  from gv$system_event
 where wait_class <> 'Idle'
 order by inst_id,time_waited desc;
spool off
spool "&output_dir./24_system_metrics.csv"
prompt COLLECTION_UTC,DBID,INST_ID,METRIC_NAME,VALUE,UNIT,INTSIZE_CSEC
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),inst_id,replace(metric_name,',',' '),
       value,metric_unit,intsize_csec
  from gv$sysmetric
 where group_id=2 order by inst_id,metric_name;
spool off
