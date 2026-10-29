-- Copyright (c) Microsoft Corporation.
-- SPDX-License-Identifier: MIT
--
-- Extract sizing metrics from Statspack without using licensed AWR or ASH.
-- Optional existing Statspack workflow, step 2 of 2; run step 01 first.
-- Usage from the package root:
-- @scripts\perfstat\02_collect_perfstat_metrics.sql <output-dir> <perfstat-owner>
--        <begin-snap-id> <end-snap-id>

whenever oserror exit failure rollback
whenever sqlerror exit failure rollback

set define on
set verify off
set echo off
set feedback off
set heading off
set pagesize 0
set linesize 32767
set trimspool on
set termout off
set tab off

define output_dir = '&1'
define perfstat_owner = '&2'
define begin_snap_id = '&3'
define end_snap_id = '&4'

declare
  l_snapshot_count number;
  l_expected_instances number;
  l_begin_instances number;
  l_end_instances number;
begin
  if to_number('&&begin_snap_id') >= to_number('&&end_snap_id') then
    raise_application_error(-20011, 'Begin snapshot must precede end snapshot');
  end if;

  execute immediate
    'select count(*) from &&perfstat_owner..stats$snapshot ' ||
    'where dbid = (select dbid from v$database) ' ||
    'and snap_id between :begin_id and :end_id'
    into l_snapshot_count
    using to_number('&&begin_snap_id'), to_number('&&end_snap_id');

  if l_snapshot_count < 2 then
    raise_application_error(-20012, 'The selected range has fewer than two snapshots');
  end if;

  execute immediate
    'select count(distinct instance_number) ' ||
    'from &&perfstat_owner..stats$snapshot ' ||
    'where dbid = (select dbid from v$database) ' ||
    'and snap_id between :begin_id and :end_id'
    into l_expected_instances
    using to_number('&&begin_snap_id'), to_number('&&end_snap_id');

  execute immediate
    'select count(distinct instance_number) ' ||
    'from &&perfstat_owner..stats$snapshot ' ||
    'where dbid = (select dbid from v$database) and snap_id = :snap_id'
    into l_begin_instances
    using to_number('&&begin_snap_id');

  execute immediate
    'select count(distinct instance_number) ' ||
    'from &&perfstat_owner..stats$snapshot ' ||
    'where dbid = (select dbid from v$database) and snap_id = :snap_id'
    into l_end_instances
    using to_number('&&end_snap_id');

  if l_begin_instances <> l_expected_instances
     or l_end_instances <> l_expected_instances then
    raise_application_error(
      -20013,
      'Begin and end snapshots must exist for every selected RAC instance'
    );
  end if;
end;
/

spool "&output_dir./perfstat_metric_availability.csv"
prompt "instance_number","output_field","source_stat_name","quality","available"

with selected_instances as (
  select distinct dbid, instance_number
    from &&perfstat_owner..stats$snapshot
   where dbid = (select dbid from v$database)
     and snap_id between to_number('&&begin_snap_id')
                         and to_number('&&end_snap_id')
),
required_metrics as (
  select 'db_cpu_cs' output_field,
         'cpu used by this session' preferred_name,
         cast(null as varchar2(64)) fallback_name
    from dual
  union all select 'db_time_microseconds', 'db time', null from dual
  union all select 'physical_read_io_requests',
                   'physical read total io requests', 'physical reads' from dual
  union all select 'physical_write_io_requests',
                   'physical write total io requests', 'physical writes' from dual
  union all select 'physical_read_bytes', 'physical read total bytes',
                   'physical reads' from dual
  union all select 'physical_write_bytes', 'physical write total bytes',
                   'physical writes' from dual
  union all select 'redo_bytes', 'redo size', null from dual
  union all select 'user_commits', 'user commits', null from dual
  union all select 'user_rollbacks', 'user rollbacks', null from dual
  union all select 'execute_count', 'execute count', null from dual
  union all select 'hard_parse_count', 'parse count (hard)', null from dual
  union all select 'logical_reads', 'session logical reads', null from dual
  union all select 'logons_current', 'logons current', null from dual
),
available_metrics as (
  select distinct instance_number, lower(name) stat_name
    from &&perfstat_owner..stats$sysstat
   where dbid = (select dbid from v$database)
     and snap_id between to_number('&&begin_snap_id')
                         and to_number('&&end_snap_id')
  union
  select distinct t.instance_number, lower(n.stat_name) stat_name
    from &&perfstat_owner..stats$sys_time_model t
    join v$sys_time_model n on n.stat_id = t.stat_id
   where t.dbid = (select dbid from v$database)
     and t.snap_id between to_number('&&begin_snap_id')
                         and to_number('&&end_snap_id')
)
select '"' || to_char(i.instance_number, 'fm9999999990') || '","' ||
       r.output_field || '","' ||
       nvl(p.stat_name, nvl(f.stat_name, '')) || '","' ||
       case
         when p.stat_name is not null then 'EXACT'
         when f.stat_name is not null then 'APPROXIMATE'
         else 'MISSING'
       end || '","' ||
       case
         when p.stat_name is not null or f.stat_name is not null then 'YES'
         else 'NO'
       end || '"'
  from selected_instances i
 cross join required_metrics r
  left join available_metrics p
    on p.instance_number = i.instance_number
   and p.stat_name = r.preferred_name
  left join available_metrics f
    on f.instance_number = i.instance_number
   and f.stat_name = r.fallback_name
 order by i.instance_number, r.output_field;

spool off

spool "&output_dir./perfstat_metrics.csv"
prompt "dbid","instance_number","begin_snap_id","end_snap_id","begin_time","end_time","elapsed_seconds","db_cpu_cs","db_time_microseconds","physical_read_io_requests","physical_write_io_requests","physical_read_bytes","physical_write_bytes","redo_bytes","user_commits","user_rollbacks","execute_count","hard_parse_count","logical_reads","logons_current","interval_status","status_reason"

with snapshot_scope as (
  select s.dbid,
         s.instance_number,
         s.snap_id,
         s.snap_time,
         s.startup_time
    from &&perfstat_owner..stats$snapshot s
   where s.dbid = (select dbid from v$database)
     and s.snap_id between to_number('&&begin_snap_id')
                         and to_number('&&end_snap_id')
),
sysstat_values as (
  select s.dbid,
         s.instance_number,
         s.snap_id,
         s.snap_time,
         s.startup_time,
         max(case when lower(t.name) = 'cpu used by this session'
                  then t.value end) db_cpu_cs,
         max(case when lower(t.name) = 'physical read total io requests'
                  then t.value end) preferred_read_requests,
         max(case when lower(t.name) = 'physical write total io requests'
                  then t.value end) preferred_write_requests,
         max(case when lower(t.name) = 'physical read total bytes'
                  then t.value end) preferred_read_bytes,
         max(case when lower(t.name) = 'physical write total bytes'
                  then t.value end) preferred_write_bytes,
         max(case when lower(t.name) = 'physical reads'
                  then t.value end) fallback_reads,
         max(case when lower(t.name) = 'physical writes'
                  then t.value end) fallback_writes,
         max(case when lower(t.name) = 'redo size'
                  then t.value end) redo_bytes,
         max(case when lower(t.name) = 'user commits'
                  then t.value end) user_commits,
         max(case when lower(t.name) = 'user rollbacks'
                  then t.value end) user_rollbacks,
         max(case when lower(t.name) = 'execute count'
                  then t.value end) execute_count,
         max(case when lower(t.name) = 'parse count (hard)'
                  then t.value end) hard_parse_count,
         max(case when lower(t.name) = 'session logical reads'
                  then t.value end) logical_reads,
         max(case when lower(t.name) = 'logons current'
                  then t.value end) logons_current
    from snapshot_scope s
    left join &&perfstat_owner..stats$sysstat t
      on t.dbid = s.dbid
     and t.instance_number = s.instance_number
     and t.snap_id = s.snap_id
   group by s.dbid, s.instance_number, s.snap_id, s.snap_time, s.startup_time
),
time_model_values as (
  select s.dbid,
         s.instance_number,
         s.snap_id,
         max(case when lower(n.stat_name) = 'db time' then t.value end)
           db_time_microseconds
    from snapshot_scope s
    left join &&perfstat_owner..stats$sys_time_model t
      on t.dbid = s.dbid
     and t.instance_number = s.instance_number
     and t.snap_id = s.snap_id
    left join v$sys_time_model n on n.stat_id = t.stat_id
   group by s.dbid, s.instance_number, s.snap_id
),
block_sizes as (
  select inst_id instance_number, to_number(value) db_block_size
    from gv$parameter
   where name = 'db_block_size'
),
snapshot_stats as (
  select v.dbid,
         v.instance_number,
         v.snap_id,
         v.snap_time,
         v.startup_time,
         v.db_cpu_cs,
         m.db_time_microseconds,
         nvl(v.preferred_read_requests, v.fallback_reads)
           physical_read_io_requests,
         nvl(v.preferred_write_requests, v.fallback_writes)
           physical_write_io_requests,
         nvl(v.preferred_read_bytes, v.fallback_reads * b.db_block_size)
           physical_read_bytes,
         nvl(v.preferred_write_bytes, v.fallback_writes * b.db_block_size)
           physical_write_bytes,
         v.redo_bytes,
         v.user_commits,
         v.user_rollbacks,
         v.execute_count,
         v.hard_parse_count,
         v.logical_reads,
         v.logons_current
    from sysstat_values v
    left join time_model_values m
      on m.dbid = v.dbid
     and m.instance_number = v.instance_number
     and m.snap_id = v.snap_id
    left join block_sizes b on b.instance_number = v.instance_number
),
intervals as (
  select dbid,
         instance_number,
         lag(snap_id) over (
           partition by dbid, instance_number order by snap_id
         ) begin_snap_id,
         snap_id end_snap_id,
         lag(snap_time) over (
           partition by dbid, instance_number order by snap_id
         ) begin_time,
         snap_time end_time,
         (snap_time - lag(snap_time) over (
           partition by dbid, instance_number order by snap_id
         )) * 86400 elapsed_seconds,
         startup_time,
         lag(startup_time) over (
           partition by dbid, instance_number order by snap_id
         ) begin_startup_time,
         db_cpu_cs - lag(db_cpu_cs) over (
           partition by dbid, instance_number order by snap_id
         ) db_cpu_cs,
         db_time_microseconds - lag(db_time_microseconds) over (
           partition by dbid, instance_number order by snap_id
         ) db_time_microseconds,
         physical_read_io_requests - lag(physical_read_io_requests) over (
           partition by dbid, instance_number order by snap_id
         ) physical_read_io_requests,
         physical_write_io_requests - lag(physical_write_io_requests) over (
           partition by dbid, instance_number order by snap_id
         ) physical_write_io_requests,
         physical_read_bytes - lag(physical_read_bytes) over (
           partition by dbid, instance_number order by snap_id
         ) physical_read_bytes,
         physical_write_bytes - lag(physical_write_bytes) over (
           partition by dbid, instance_number order by snap_id
         ) physical_write_bytes,
         redo_bytes - lag(redo_bytes) over (
           partition by dbid, instance_number order by snap_id
         ) redo_bytes,
         user_commits - lag(user_commits) over (
           partition by dbid, instance_number order by snap_id
         ) user_commits,
         user_rollbacks - lag(user_rollbacks) over (
           partition by dbid, instance_number order by snap_id
         ) user_rollbacks,
         execute_count - lag(execute_count) over (
           partition by dbid, instance_number order by snap_id
         ) execute_count,
         hard_parse_count - lag(hard_parse_count) over (
           partition by dbid, instance_number order by snap_id
         ) hard_parse_count,
         logical_reads - lag(logical_reads) over (
           partition by dbid, instance_number order by snap_id
         ) logical_reads,
         logons_current
    from snapshot_stats
),
classified_intervals as (
  select i.*,
         case
           when begin_startup_time <> startup_time then 'INVALID'
           when end_snap_id <> begin_snap_id + 1 then 'INVALID'
           when elapsed_seconds <= 0 then 'INVALID'
           when db_cpu_cs is null or db_time_microseconds is null
             or physical_read_io_requests is null
             or physical_write_io_requests is null
             or physical_read_bytes is null or physical_write_bytes is null
             or redo_bytes is null or user_commits is null
             or user_rollbacks is null or execute_count is null
             or hard_parse_count is null or logical_reads is null
             or logons_current is null then 'INVALID'
           when db_cpu_cs < 0 or db_time_microseconds < 0
             or physical_read_io_requests < 0
             or physical_write_io_requests < 0
             or physical_read_bytes < 0 or physical_write_bytes < 0
             or redo_bytes < 0 or user_commits < 0 or user_rollbacks < 0
             or execute_count < 0 or hard_parse_count < 0
             or logical_reads < 0 then 'INVALID'
           else 'VALID'
         end interval_status,
         case
           when begin_startup_time <> startup_time then 'INSTANCE_RESTART'
           when end_snap_id <> begin_snap_id + 1 then 'SNAPSHOT_GAP'
           when elapsed_seconds <= 0 then 'INVALID_ELAPSED_TIME'
           when db_cpu_cs is null or db_time_microseconds is null
             or physical_read_io_requests is null
             or physical_write_io_requests is null
             or physical_read_bytes is null or physical_write_bytes is null
             or redo_bytes is null or user_commits is null
             or user_rollbacks is null or execute_count is null
             or hard_parse_count is null or logical_reads is null
             or logons_current is null then 'MISSING_METRIC'
           when db_cpu_cs < 0 or db_time_microseconds < 0
             or physical_read_io_requests < 0
             or physical_write_io_requests < 0
             or physical_read_bytes < 0 or physical_write_bytes < 0
             or redo_bytes < 0 or user_commits < 0 or user_rollbacks < 0
             or execute_count < 0 or hard_parse_count < 0
             or logical_reads < 0 then 'COUNTER_RESET'
           else ''
         end status_reason
    from intervals i
)
select '"' || to_char(dbid, 'fm99999999999999999990') || '","' ||
       to_char(instance_number, 'fm9999999990') || '","' ||
       to_char(begin_snap_id, 'fm99999999999999999990') || '","' ||
       to_char(end_snap_id, 'fm99999999999999999990') || '","' ||
       to_char(begin_time, 'YYYY-MM-DD"T"HH24:MI:SS') || '","' ||
       to_char(end_time, 'YYYY-MM-DD"T"HH24:MI:SS') || '","' ||
       to_char(elapsed_seconds, 'fm99999999999999999990.999999') || '","' ||
        nvl(to_char(db_cpu_cs, 'fm99999999999999999990'), '') || '","' ||
        nvl(to_char(db_time_microseconds, 'fm99999999999999999990'), '') || '","' ||
        nvl(to_char(physical_read_io_requests,
                   'fm99999999999999999990'), '') || '","' ||
        nvl(to_char(physical_write_io_requests,
                   'fm99999999999999999990'), '') || '","' ||
        nvl(to_char(physical_read_bytes,
                   'fm99999999999999999990'), '') || '","' ||
        nvl(to_char(physical_write_bytes,
                   'fm99999999999999999990'), '') || '","' ||
        nvl(to_char(redo_bytes, 'fm99999999999999999990'), '') || '","' ||
        nvl(to_char(user_commits, 'fm99999999999999999990'), '') || '","' ||
        nvl(to_char(user_rollbacks, 'fm99999999999999999990'), '') || '","' ||
        nvl(to_char(execute_count, 'fm99999999999999999990'), '') || '","' ||
        nvl(to_char(hard_parse_count, 'fm99999999999999999990'), '') || '","' ||
        nvl(to_char(logical_reads, 'fm99999999999999999990'), '') || '","' ||
        nvl(to_char(logons_current, 'fm99999999999999999990'), '') || '","' ||
        interval_status || '","' || status_reason || '"'
      from classified_intervals
 where begin_snap_id is not null
 order by instance_number, end_snap_id;

spool off

spool "&output_dir./perfstat_top_waits.csv"
prompt "dbid","instance_number","event_name","wait_class","wait_count","time_waited_seconds"

with snapshot_bounds as (
  select dbid,
         instance_number,
         min(snap_id) begin_snap_id,
         max(snap_id) end_snap_id,
         min(startup_time) begin_startup_time,
         max(startup_time) end_startup_time
    from &&perfstat_owner..stats$snapshot
   where dbid = (select dbid from v$database)
     and snap_id between to_number('&&begin_snap_id')
                         and to_number('&&end_snap_id')
   group by dbid, instance_number
),
begin_events as (
  select e.dbid, e.instance_number, e.event, e.total_waits, e.time_waited
    from &&perfstat_owner..stats$system_event e
    join snapshot_bounds b
      on b.dbid = e.dbid
     and b.instance_number = e.instance_number
     and b.begin_snap_id = e.snap_id
),
end_events as (
  select e.dbid, e.instance_number, e.event, e.total_waits, e.time_waited
    from &&perfstat_owner..stats$system_event e
    join snapshot_bounds b
      on b.dbid = e.dbid
     and b.instance_number = e.instance_number
     and b.end_snap_id = e.snap_id
   where b.begin_startup_time = b.end_startup_time
)
select '"' || to_char(e.dbid, 'fm99999999999999999990') || '","' ||
       to_char(e.instance_number, 'fm9999999990') || '","' ||
       replace(e.event, '"', '""') || '","' ||
       replace(nvl(n.wait_class, 'Other'), '"', '""') || '","' ||
       to_char(greatest(e.total_waits - nvl(b.total_waits, 0), 0),
               'fm99999999999999999990') || '","' ||
       to_char(greatest(e.time_waited - nvl(b.time_waited, 0), 0) / 100,
               'fm99999999999999999990.999999') || '"'
  from end_events e
  left join begin_events b
    on b.dbid = e.dbid
   and b.instance_number = e.instance_number
   and b.event = e.event
  left join v$event_name n on n.name = e.event
 where greatest(e.time_waited - nvl(b.time_waited, 0), 0) > 0
   and nvl(n.wait_class, 'Other') <> 'Idle'
 order by greatest(e.time_waited - nvl(b.time_waited, 0), 0) desc;

spool off
set termout on
exit success