-- Save only non-secret run state so a fresh connection can finish this window.
-- Disable substitution while restoring quoted metadata, not while defining paths.
set termout off
spool "&assessment_run_dir./resume_workload.sql"
prompt -- Run from the package root after reconnecting to the original database/PDB.
prompt -- Contains metadata only, never a username/password connection command.
prompt set echo off
prompt set verify off
prompt define assessment_run_dir = "&assessment_run_dir"
prompt define assessment_window_minutes = "&assessment_window_minutes"
prompt define assessment_schema_count = "&assessment_schema_count"
prompt @scripts/oracle/99_set_csv_format.sql
prompt set define off
prompt variable assessment_selected clob
prompt variable assessment_window_start varchar2(14)
prompt variable assessment_expected_dbid number
prompt variable assessment_expected_container varchar2(128)
prompt variable assessment_expected_startups clob
prompt variable assessment_workload_complete number
declare
  function literal(value varchar2) return varchar2 is
    escaped varchar2(32767);
  begin
    escaped := replace(value,chr(39),chr(39)||chr(39));
    escaped := replace(escaped,chr(13),chr(39)||'||chr(13)||'||chr(39));
    escaped := replace(escaped,chr(10),chr(39)||'||chr(10)||'||chr(39));
    escaped := replace(escaped,chr(9),chr(39)||'||chr(9)||'||chr(39));
    return chr(39) || escaped || chr(39);
  end;
  procedure save_lob(name varchar2, value clob) is
    offset_value number := 1;
    piece varchar2(1000);
  begin
    dbms_output.put_line('  dbms_lob.createtemporary(:' || name || ',true);');
    while offset_value <= dbms_lob.getlength(value) loop
      piece := dbms_lob.substr(value,1000,offset_value);
      dbms_output.put_line('  dbms_lob.writeappend(:' || name || ',' ||
        to_char(length(piece),'TM9') || ',' || literal(piece) || ');');
      offset_value := offset_value + length(piece);
    end loop;
  end;
begin
  dbms_output.put_line('begin');
  dbms_output.put_line('  :assessment_window_start := ' || literal(:assessment_window_start) || ';');
  dbms_output.put_line('  :assessment_expected_dbid := ' ||
    to_char(:assessment_expected_dbid,'TM9','NLS_NUMERIC_CHARACTERS=''.,''') || ';');
  dbms_output.put_line('  :assessment_expected_container := ' ||
    literal(:assessment_expected_container) || ';');
  dbms_output.put_line('  :assessment_workload_complete := 0;');
  save_lob('assessment_selected',:assessment_selected);
  save_lob('assessment_expected_startups',:assessment_expected_startups);
  dbms_output.put_line('end;');
  dbms_output.put_line('/');
end;
/
prompt set define on
prompt @scripts/oracle/99_show_connection.sql
prompt @scripts/oracle/99_complete_workload.sql
spool off
set termout on
