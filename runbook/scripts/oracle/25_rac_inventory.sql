-- File: 25_rac_inventory.sql
-- Purpose: Record RAC parameter and per-instance topology evidence.
-- Data collected: CLUSTER_DATABASE, GV$INSTANCE and global cache counters.
-- Expected privileges: GV_$PARAMETER, GV_$INSTANCE, GV_$SYSSTAT.
-- Scope: Database and all visible instances.
-- Oracle versions: 10g and later.
-- Licensing: None.
-- Expected output: 25_rac_inventory.csv.
-- Sensitive metadata: Yes; host and topology.
whenever sqlerror continue
spool "&output_dir./25_rac_inventory.csv"
prompt COLLECTION_UTC,DBID,INST_ID,ITEM,VALUE
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),inst_id,'INSTANCE',
       instance_name||';HOST='||replace(host_name,',',' ')||';STARTUP='||
       to_char(startup_time,'YYYY-MM-DD HH24:MI:SS')
  from gv$instance
union all
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),inst_id,name,value
  from gv$parameter where name='cluster_database'
union all
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),inst_id,'GC_COUNTER:'||name,to_char(value)
  from gv$sysstat where name like 'gc%';
spool off
