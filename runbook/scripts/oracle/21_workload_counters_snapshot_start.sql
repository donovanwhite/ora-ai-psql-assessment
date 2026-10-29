-- File: 21_workload_counters_snapshot_start.sql
-- Purpose: Capture start values for a two-point, non-AWR workload interval.
-- Data collected: Instance startup markers and cumulative SYSSTAT counters.
-- Expected privileges: GV_$INSTANCE, GV_$SYSSTAT, V_$DATABASE.
-- Scope: Database and all visible RAC instances.
-- Oracle versions: 10g and later.
-- Licensing: None; does not query AWR or ASH.
-- Expected output: 21_workload_start.csv.
-- Sensitive metadata: Workload profile; no SQL text or application rows.
-- Run immediately before an approved representative period.
whenever sqlerror continue
spool "&output_dir./21_workload_start.csv"
prompt COLLECTION_UTC,DBID,INST_ID,INSTANCE_NAME,STARTUP_TIME,COUNTER_NAME,COUNTER_VALUE
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),s.inst_id,i.instance_name,
       to_char(i.startup_time,'YYYY-MM-DD HH24:MI:SS'),s.name,s.value
  from gv$sysstat s,gv$instance i
 where s.inst_id=i.inst_id
   and s.name in ('CPU used by this session','user commits','user rollbacks',
     'execute count','parse count (total)','parse count (hard)','user calls',
     'session logical reads','physical reads','physical writes',
     'physical read total bytes','physical write total bytes',
     'physical read total IO requests','physical write total IO requests',
     'bytes sent via SQL*Net to client','bytes received via SQL*Net from client',
     'redo size','redo writes','sorts (disk)','sorts (memory)')
 order by s.inst_id,s.name;
spool off
spool "&output_dir./21_workload_time_model_start.csv"
prompt COLLECTION_UTC,DBID,INST_ID,INSTANCE_NAME,STARTUP_TIME,STAT_NAME,VALUE_MICROSECONDS
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),t.inst_id,i.instance_name,
       to_char(i.startup_time,'YYYY-MM-DD HH24:MI:SS'),t.stat_name,t.value
  from gv$sys_time_model t,gv$instance i
 where t.inst_id=i.inst_id and t.stat_name in ('DB time','DB CPU')
 order by t.inst_id,t.stat_name;
spool off
prompt Record the UTC start time, workload label and approved interval in the execution record.
