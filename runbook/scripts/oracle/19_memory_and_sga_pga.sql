-- File: 19_memory_and_sga_pga.sql
-- Purpose: Capture SGA components and PGA statistics for each instance.
-- Data collected: GV$SGA, GV$PGASTAT and memory parameters.
-- Expected privileges: GV_$SGA, GV_$PGASTAT, GV_$PARAMETER.
-- Scope: Instance; preserve INST_ID for RAC.
-- Oracle versions: 10g and later; metric set varies by release.
-- Licensing: None.
-- Expected output: 19_sga_pga_memory.csv.
-- Sensitive metadata: Yes; memory configuration.
whenever sqlerror continue
spool "&output_dir./19_sga_pga_memory.csv"
prompt COLLECTION_UTC,DBID,INST_ID,METRIC,VALUE,UNIT
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),inst_id,'SGA:'||name,to_char(value),'bytes'
  from gv$sga
union all
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),inst_id,name,to_char(value),unit
  from gv$pgastat
union all
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),inst_id,name,value,'PARAMETER'
  from gv$parameter where name in ('sga_target','sga_max_size','pga_aggregate_target',
                                   'pga_aggregate_limit','memory_target','memory_max_target')
order by 3,4;
spool off
