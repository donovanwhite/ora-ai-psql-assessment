-- Private continuation, dispatched only after 99_complete_workload says READY.
-- Disable automatic replay before attempting END, including partial I/O failures.
spool "&assessment_run_dir./resume_workload.sql"
prompt prompt End capture has already started for this run.
prompt prompt Preserve existing END files; ask the DBA to review before any retry.
spool off
begin
  :assessment_workload_complete := 1;
end;
/
define output_dir = '&assessment_run_dir./performance/window_01'
@@22_workload_counters_snapshot_end.sql
@@23_top_sql_metadata.sql
@@24_wait_events_and_system_metrics.sql

whenever sqlerror continue
begin
  dbms_lob.freetemporary(:assessment_selected);
  dbms_lob.freetemporary(:assessment_expected_startups);
  :assessment_selected := null;
  :assessment_expected_startups := null;
end;
/
spool "&assessment_run_dir./99_run_complete_assessment.txt"
prompt ORACLE_COLLECTORS_INVOKED - VALIDATION_REQUIRED
prompt Current connection/container only; no automatic reconnect or privilege change.
prompt Approved schemas: &assessment_schema_count
prompt Requested workload interval in minutes: &assessment_window_minutes
prompt Output folder: &assessment_run_dir
prompt Review every ORA-/SP2-/TNS- error and run the output-pack validator.
prompt Optional host collection, approved existing Statspack and VS Code assessment remain separate.
spool off
spool "&assessment_run_dir./resume_workload.sql"
prompt prompt This run's END collection was already invoked. Validation is still required.
prompt prompt No files were changed. Do not repeat the assessment or overwrite its snapshots.
spool off
prompt All supplied numbered Oracle collectors were invoked for this run.
prompt Outputs are NOT yet validated. Finish the runbook validation and handover.
