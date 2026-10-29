-- File: 04_cdb_pdb_inventory.sql
-- Purpose: Detect and inventory CDB/PDB containers without breaking 10g.
-- Data collected: Active container context and dynamic V$PDBS output when available.
-- Expected privileges: V_$DATABASE and V_$PDBS on 12c+.
-- Scope: CDB.
-- Oracle versions: 10g and later; PDB inventory is available only in 12c+.
-- Licensing: None.
-- Expected output: 04_cdb_pdb_inventory.csv.
-- Sensitive metadata: Yes.
-- A non-CDB or pre-12c database is reported as unavailable/not applicable.
whenever sqlerror continue
spool "&output_dir./04_cdb_pdb_inventory.csv"
prompt COLLECTION_UTC,DBID,CONTAINER_TYPE,ACTIVE_CONTAINER,CONTAINER_NAME,OPEN_MODE,CON_ID,STATUS
declare
  c integer;
  n varchar2(128);
  m varchar2(32);
  active_container varchar2(128);
  id number;
  dbid_value number;
  rows_fetched integer;
  visible_rows integer := 0;
begin
  select dbid into dbid_value from v$database;
  begin
    select sys_context('USERENV','CON_NAME') into active_container from dual;
  exception
    when others then
      if sqlcode = -2003 then
        active_container := null;
      else
        raise;
      end if;
  end;
  if active_container is null then
    active_container := 'NOT_APPLICABLE';
  end if;
  dbms_output.put_line(to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"')||','||
    dbid_value||',ACTIVE,'||replace(active_container,',',' ')||','||
    replace(active_container,',',' ')||',,,'||
    case when active_container = 'NOT_APPLICABLE' then 'NOT_APPLICABLE_PRE_12C'
         else 'AVAILABLE' end);
  c := dbms_sql.open_cursor;
  begin
    dbms_sql.parse(c,'select name, open_mode, con_id from v$pdbs order by con_id',dbms_sql.native);
    dbms_sql.define_column(c,1,n,128);
    dbms_sql.define_column(c,2,m,32);
    dbms_sql.define_column(c,3,id);
    rows_fetched := dbms_sql.execute(c);
    while dbms_sql.fetch_rows(c) > 0 loop
      visible_rows := visible_rows + 1;
      dbms_sql.column_value(c,1,n);
      dbms_sql.column_value(c,2,m);
      dbms_sql.column_value(c,3,id);
      dbms_output.put_line(to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"')||','||
        dbid_value||',PDB,'||replace(active_container,',',' ')||','||
        replace(n,',',' ')||','||m||','||id||',AVAILABLE');
    end loop;
    dbms_sql.close_cursor(c);
    if visible_rows = 0 then
      dbms_output.put_line(to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"')||','||
        dbid_value||',PDB,'||replace(active_container,',',' ')||
        ',,,,NO_VISIBLE_PDB_ROWS_VERIFY_SCOPE');
    end if;
  exception
    when others then
      if dbms_sql.is_open(c) then dbms_sql.close_cursor(c); end if;
      if sqlcode not in (-942,-904,-1031) then raise; end if;
      dbms_output.put_line(to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"')||','||
        dbid_value||',PDB,'||replace(active_container,',',' ')||
        ',NOT_APPLICABLE,,,"VIEW_UNAVAILABLE_OR_NON_CDB: '||replace(sqlerrm,'"','""')||'"');
  end;
end;
/
spool off
