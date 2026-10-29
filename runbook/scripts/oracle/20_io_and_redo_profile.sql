-- File: 20_io_and_redo_profile.sql
-- Purpose: Capture cumulative I/O, redo, logical reads, parse and call counters.
-- Data collected: Selected GV$SYSSTAT counters, separated by instance.
-- Expected privileges: GV_$SYSSTAT.
-- Scope: Instance; preserve INST_ID for RAC.
-- Oracle versions: 10g and later; counter names can differ.
-- Licensing: None.
-- Expected output: 20_io_redo_counters.csv.
-- Sensitive metadata: No application rows; workload metadata.
whenever sqlerror continue
spool "&output_dir./20_io_redo_counters.csv"
prompt COLLECTION_UTC,DBID,INST_ID,STATISTIC,VALUE
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),inst_id,name,value
  from gv$sysstat
 where name in ('CPU used by this session','user commits','user rollbacks',
   'execute count','parse count (total)','parse count (hard)','user calls',
   'session logical reads','physical reads','physical writes','physical read total bytes',
   'physical write total bytes','physical read total IO requests',
   'physical write total IO requests','bytes sent via SQL*Net to client',
   'bytes received via SQL*Net from client','redo size','redo entries','redo writes',
   'sorts (disk)','sorts (memory)')
 order by inst_id,name;
spool off
