-- Recheck the existing START in this session; do not rerun inventory or script 21.
-- After reconnecting, use the run folder's generated resume_workload.sql instead.
whenever oserror exit failure rollback
whenever sqlerror continue
@@99_set_csv_format.sql
variable assessment_workload_action varchar2(10)
begin
  :assessment_workload_action := 'BLOCKED';
end;
/
declare
  elapsed_seconds number;
  remaining_seconds number;
  current_dbid number;
  current_container varchar2(128);
  current_startups clob;
  marker varchar2(300);
begin
  if :assessment_workload_complete = 1 then
    :assessment_workload_action := 'COMPLETE';
    dbms_output.put_line('End collection was already invoked. Existing outputs will not be overwritten.');
  elsif :assessment_window_start is null or :assessment_expected_dbid is null or
        :assessment_expected_container is null or :assessment_expected_startups is null then
    dbms_output.put_line('Workload state is unavailable. Use the existing run folder''s resume_workload.sql.');
  else
    select dbid into current_dbid from v$database;
    if dbms_db_version.version >= 12 then
      current_container := sys_context('USERENV','CON_NAME');
    else
      current_container := '(non-CDB)';
    end if;
    if current_dbid <> :assessment_expected_dbid or
       current_container is null or current_container <> :assessment_expected_container then
      dbms_output.put_line('WRONG DATABASE/CONTAINER: no END files were written.');
      dbms_output.put_line('Reconnect to the original database/PDB, then use its saved recovery file.');
    else
      dbms_lob.createtemporary(current_startups,true);
      for r in (select inst_id,instance_name,startup_time from gv$instance order by inst_id) loop
        marker := to_char(r.inst_id,'TM9') || '|' || r.instance_name || '|' ||
                  to_char(r.startup_time,'YYYYMMDDHH24MISS') || ';';
        dbms_lob.writeappend(current_startups,length(marker),marker);
      end loop;
      if dbms_lob.compare(current_startups,:assessment_expected_startups) <> 0 then
        dbms_output.put_line('INSTANCE CHANGED/RESTARTED: no END files were written.');
        dbms_output.put_line('Preserve this run. Ask the DBA to arrange a new workload window only.');
      else
        elapsed_seconds :=
          (cast(sys_extract_utc(systimestamp) as date) -
           to_date(:assessment_window_start,'YYYYMMDDHH24MISS')) * 86400;
        remaining_seconds := ceil(&assessment_window_minutes * 60 - elapsed_seconds);
        if remaining_seconds > 0 then
          :assessment_workload_action := 'WAIT';
          dbms_output.put_line('Interval still running: ' || to_char(remaining_seconds,'TM9') ||
                               ' seconds remaining.');
          dbms_output.put_line('Inventory, selected owners and the original START are preserved.');
          dbms_output.put_line('You are returning to SQL>, still connected. When ready, run:');
          dbms_output.put_line('@scripts/oracle/99_complete_workload.sql');
          dbms_output.put_line('If you reconnect first, use this saved recovery file instead:');
          dbms_output.put_line('@&assessment_run_dir./resume_workload.sql');
        else
          :assessment_workload_action := 'READY';
          dbms_output.put_line('Approved interval elapsed. Completing this same workload window.');
        end if;
      end if;
      dbms_lob.freetemporary(current_startups);
    end if;
  end if;
end;
/
set termout off
spool "&assessment_run_dir./_finish_workload.sql"
select case when :assessment_workload_action='READY'
            then '@scripts/oracle/99_finalize_assessment.sql'
            else 'REM No END collection requested; existing files are preserved.'
       end
  from dual;
spool off
set termout on
@"&assessment_run_dir./_finish_workload.sql"
