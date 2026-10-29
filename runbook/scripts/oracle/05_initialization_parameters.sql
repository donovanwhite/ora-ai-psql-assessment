-- File: 05_initialization_parameters.sql
-- Purpose: Capture sizing, concurrency, optimizer, logging and compatibility parameters.
-- Data collected: Selected V$PARAMETER values.
-- Expected privileges: V_$PARAMETER.
-- Scope: Instance; GV$ captures RAC values.
-- Oracle versions: 10g and later; missing parameters are version-specific.
-- Licensing: None.
-- Expected output: 05_initialization_parameters.csv.
-- Sensitive metadata: Yes; configuration.
whenever sqlerror continue
spool "&output_dir./05_initialization_parameters.csv"
prompt COLLECTION_UTC,INST_ID,NAME,VALUE,ISDEFAULT,ISMODIFIED
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       inst_id,name,replace(value,',',' '),isdefault,ismodified
  from gv$parameter
 where name in ('cluster_database','cpu_count','memory_target','memory_max_target',
   'sga_target','sga_max_size','pga_aggregate_target','pga_aggregate_limit',
   'processes','sessions','transactions','open_cursors','db_block_size',
   'compatible','optimizer_mode','parallel_max_servers','parallel_degree_policy',
   'undo_tablespace','undo_retention','db_flashback_retention_target',
   'log_archive_dest_1','remote_login_passwordfile','audit_trail',
   'max_string_size','global_names')
 order by inst_id,name;
spool off
