-- File: 03_instance_and_host_configuration.sql
-- Purpose: Capture per-instance startup, host, CPU and operating-system metrics.
-- Data collected: Instance identity, startup time, host and available OS stats.
-- Expected privileges: GV_$INSTANCE; GV_$OSSTAT where available.
-- Scope: Instance (all RAC instances visible to GV$).
-- Oracle versions: 10g and later; OS statistic names vary.
-- Licensing: None.
-- Expected output: 03_instance_configuration.csv and 03_host_os_stats.csv.
-- Sensitive metadata: Yes; host names and capacity.
-- In RAC, preserve each INST_ID as a separate observation.
whenever sqlerror continue
spool "&output_dir./03_instance_configuration.csv"
prompt COLLECTION_UTC,DBID,INST_ID,INSTANCE_NAME,HOST_NAME,VERSION,STARTUP_TIME,STATUS,THREAD,PARALLEL
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),inst_id,instance_name,
       replace(host_name,',',' '),version,
       to_char(startup_time,'YYYY-MM-DD HH24:MI:SS'),status,thread#,parallel
  from gv$instance order by inst_id;
spool off
spool "&output_dir./03_host_os_stats.csv"
prompt OSSTAT_COLLECTION_UTC,INST_ID,STAT_NAME,VALUE
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       inst_id,stat_name,value
  from gv$osstat
 where stat_name in ('NUM_CPUS','NUM_CPU_CORES','NUM_CPU_SOCKETS',
                     'PHYSICAL_MEMORY_BYTES','LOAD')
 order by inst_id,stat_name;
spool off
