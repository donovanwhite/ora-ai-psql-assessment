-- File: 23_top_sql_metadata.sql
-- Purpose: Capture high-resource SQL identifiers and aggregate counters, not SQL text.
-- Data collected: GV$SQLAREA hash IDs, parsing schema, executions, gets, reads and elapsed time.
-- Expected privileges: GV_$SQLAREA.
-- Scope: Instance; preserve INST_ID.
-- Oracle versions: 10g and later.
-- Licensing: None; no AWR or ASH.
-- Expected output: 23_top_sql_metadata.csv.
-- Sensitive metadata: Yes; identifiers and workload activity. No bind values/text.
whenever sqlerror continue
spool "&output_dir./23_top_sql_metadata.csv"
prompt COLLECTION_UTC,DBID,INST_ID,PARSING_SCHEMA,SQL_ID_OR_ADDRESS,HASH_VALUE,EXECUTIONS,BUFFER_GETS,DISK_READS,ELAPSED_TIME
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),inst_id,parsing_schema_name,
       rawtohex(address),hash_value,executions,buffer_gets,disk_reads,elapsed_time
  from (select inst_id,parsing_schema_name,address,hash_value,executions,
               buffer_gets,disk_reads,elapsed_time
          from gv$sqlarea
         where parsing_schema_name is not null
         order by buffer_gets desc)
 where rownum <= 100;
spool off
