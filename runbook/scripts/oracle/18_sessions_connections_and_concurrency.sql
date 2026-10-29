-- File: 18_sessions_connections_and_concurrency.sql
-- Purpose: Capture configured/current/peak session and process usage.
-- Data collected: Resource limits and live session counts grouped by status/type.
-- Expected privileges: GV_$RESOURCE_LIMIT, GV_$SESSION.
-- Scope: Instance/database; preserve INST_ID for RAC.
-- Oracle versions: 10g and later.
-- Licensing: None.
-- Expected output: 18_session_limits.csv and 18_session_profile.csv.
-- Sensitive metadata: Yes; counts only, no client identifiers.
whenever sqlerror continue
spool "&output_dir./18_session_limits.csv"
prompt COLLECTION_UTC,DBID,INST_ID,RESOURCE_NAME,CURRENT_UTILIZATION,MAX_UTILIZATION,INITIAL_ALLOCATION,LIMIT_VALUE
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),inst_id,resource_name,current_utilization,
       max_utilization,initial_allocation,limit_value
  from gv$resource_limit
 where resource_name in ('sessions','processes','transactions','enqueue_locks','enqueue_resources')
 order by inst_id,resource_name;
spool off
spool "&output_dir./18_session_profile.csv"
prompt COLLECTION_UTC,DBID,INST_ID,SESSION_TYPE,STATUS,SESSION_COUNT
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),inst_id,type,status,count(*)
  from gv$session
 group by inst_id,type,status order by inst_id,type,status;
spool off
