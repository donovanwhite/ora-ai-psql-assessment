-- Human-readable checkpoint for script 99, outside every CSV spool.
-- The parent declares assessment_selected before the first checkpoint.
whenever sqlerror exit failure rollback
set termout on
set linesize 80
set serveroutput on size 1000000 format wrapped
declare
  database_name varchar2(128);
  unique_name varchar2(128);
  instance_name varchar2(128);
  container_name varchar2(128);
  container_id varchar2(20);
  container_type varchar2(40);
  chosen_owner varchar2(128);
  owner_index number := 1;
  procedure show_field(label varchar2, field_value varchar2) is
    clean_value varchar2(4000);
    prefix varchar2(24);
    offset_value number := 1;
  begin
    clean_value := regexp_replace(nvl(field_value,'(not available)'),'[[:cntrl:]]',' ');
    prefix := rpad(label,22) || ': ';
    loop
      dbms_output.put_line(prefix || substr(clean_value,offset_value,52));
      offset_value := offset_value + 52;
      exit when offset_value > length(clean_value);
      prefix := rpad(' ',24);
    end loop;
  end;
begin
  select d.name,d.db_unique_name,i.instance_name
    into database_name,unique_name,instance_name
    from v$database d cross join v$instance i;
  if dbms_db_version.version >= 12 then
    container_name := sys_context('USERENV','CON_NAME');
    container_id := sys_context('USERENV','CON_ID');
    if container_name is null or container_id is null then
      raise_application_error(-20010,'Active container could not be identified. Ask the DBA to confirm scope.');
    end if;
    container_type := case container_id
      when '0' then 'Non-CDB'
      when '1' then 'CDB root (not an application PDB)'
      else 'Pluggable database (PDB)' end;
  else
    container_name := '(not applicable: pre-12c non-CDB)';
    container_id := '(not applicable)';
    container_type := 'Non-CDB';
  end if;
  dbms_output.put_line(' ');
  dbms_output.put_line('==========================================================================');
  dbms_output.put_line('CURRENT ORACLE CONNECTION - REVIEW BEFORE CONTINUING');
  dbms_output.put_line('==========================================================================');
  show_field('Database / CDB',database_name);
  show_field('Database unique name',unique_name);
  show_field('Instance / SID',instance_name);
  show_field('Database server',sys_context('USERENV','SERVER_HOST',4000));
  show_field('Active container/PDB',container_name);
  show_field('Container ID',container_id);
  show_field('Container type',container_type);
  show_field('Connected service',sys_context('USERENV','SERVICE_NAME',4000));
  show_field('Login account',sys_context('USERENV','SESSION_USER',4000));
  show_field('Session current schema',sys_context('USERENV','CURRENT_SCHEMA',4000));
  if :assessment_selected is null or dbms_lob.getlength(:assessment_selected)=0 then
    show_field('Collection owners','Not selected yet; choose from the next schema menu.');
  else
    loop
      chosen_owner := dbms_lob.substr(
        regexp_substr(:assessment_selected,'[^,]+',1,owner_index),128,1);
      exit when chosen_owner is null;
      show_field(case when owner_index=1 then 'Collection owners' else 'Additional owner' end,chosen_owner);
      owner_index := owner_index + 1;
    end loop;
  end if;
  dbms_output.put_line('The login/current schema is NOT the application-owner selection.');
  dbms_output.put_line('==========================================================================');
end;
/
set linesize 32767
