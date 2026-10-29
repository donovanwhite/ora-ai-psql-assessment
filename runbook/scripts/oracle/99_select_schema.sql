-- Called only by the generated selection driver from script 99.
-- Free-form SQL identifiers are not accepted: a numeric choice resolves against
-- the frozen, filtered catalog, rather than a changing list of database users.
whenever oserror exit failure rollback
whenever sqlerror exit failure rollback
accept assessment_schema_number number default 0 prompt 'Enter the next approved schema NUMBER: '
variable assessment_chosen_owner varchar2(128)
declare
  chosen_owner varchar2(128);
begin
  if &assessment_schema_number < 1 or
     &assessment_schema_number <> trunc(&assessment_schema_number) or
     &assessment_schema_number > :assessment_catalog_count then
    raise_application_error(-20007,'Schema number must be a whole number from the displayed menu.');
  end if;
  chosen_owner := dbms_lob.substr(
    regexp_substr(:assessment_catalog,'[^,]+',1,&assessment_schema_number),128,1);
  if chosen_owner is null or not regexp_like(chosen_owner,'^[A-Z][A-Z0-9_$#]*$') then
    raise_application_error(-20008,'Unsupported schema identifier; ask the DBA to review this owner.');
  end if;
  if dbms_lob.instr(:assessment_selected,',' || chosen_owner || ',') > 0 then
    raise_application_error(-20009,'Schema already selected. Restart and select each approved owner only once.');
  end if;
  dbms_lob.writeappend(:assessment_selected,length(chosen_owner)+2,',' || chosen_owner || ',');
  :assessment_chosen_owner := chosen_owner;
  dbms_output.put_line('Selected approved owner: ' || chosen_owner);
end;
/
set termout off
spool "&assessment_run_dir./_collect_schemas.sql" append
select '@scripts/oracle/99_collect_schema.sql ' ||
       :assessment_chosen_owner
  from dual;
spool off
set termout on
