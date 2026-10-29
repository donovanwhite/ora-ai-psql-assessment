-- File: 26_asm_inventory.sql
-- Purpose: Capture ASM disk-group capacity when connected to an ASM-visible instance.
-- Data collected: GV$ASM_DISKGROUP totals, free bytes, redundancy and state when available.
-- Expected privileges: GV_$ASM_DISKGROUP; DBA/ASM operator output alternative.
-- Scope: ASM instance/storage.
-- Oracle versions: 10g and later; ASM views/columns vary.
-- Licensing: None.
-- Expected output: 26_asm_inventory.csv.
-- Sensitive metadata: Yes; storage names and capacity.
-- If unavailable, record ASM evidence as unavailable; do not infer no ASM.
whenever sqlerror continue
spool "&output_dir./26_asm_inventory.csv"
prompt COLLECTION_UTC,DBID,INST_ID,NAME,STATE,TYPE,TOTAL_MB,FREE_MB,USABLE_FILE_MB,STATUS
declare
  c integer;
  dbid_value number;
  instance_id number;
  disk_name varchar2(128);
  disk_state varchar2(32);
  disk_type varchar2(32);
  total_mb number;
  free_mb number;
  usable_file_mb number;
  rows_fetched integer;
  visible_rows integer := 0;
begin
  select dbid into dbid_value from v$database;
  c := dbms_sql.open_cursor;
  begin
    dbms_sql.parse(c,
      'select inst_id,name,state,type,total_mb,free_mb,usable_file_mb '||
      'from gv$asm_diskgroup order by inst_id,name', dbms_sql.native);
    dbms_sql.define_column(c,1,instance_id);
    dbms_sql.define_column(c,2,disk_name,128);
    dbms_sql.define_column(c,3,disk_state,32);
    dbms_sql.define_column(c,4,disk_type,32);
    dbms_sql.define_column(c,5,total_mb);
    dbms_sql.define_column(c,6,free_mb);
    dbms_sql.define_column(c,7,usable_file_mb);
    rows_fetched := dbms_sql.execute(c);
    while dbms_sql.fetch_rows(c) > 0 loop
      visible_rows := visible_rows + 1;
      dbms_sql.column_value(c,1,instance_id);
      dbms_sql.column_value(c,2,disk_name);
      dbms_sql.column_value(c,3,disk_state);
      dbms_sql.column_value(c,4,disk_type);
      dbms_sql.column_value(c,5,total_mb);
      dbms_sql.column_value(c,6,free_mb);
      dbms_sql.column_value(c,7,usable_file_mb);
      dbms_output.put_line(to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"')||','||
        dbid_value||','||instance_id||','||replace(disk_name,',',' ')||','||
        disk_state||','||disk_type||','||
        to_char(total_mb,'FM9999999999999999999999999990D999999','NLS_NUMERIC_CHARACTERS=''.,''')||','||
        to_char(free_mb,'FM9999999999999999999999999990D999999','NLS_NUMERIC_CHARACTERS=''.,''')||','||
        to_char(usable_file_mb,'FM9999999999999999999999999990D999999','NLS_NUMERIC_CHARACTERS=''.,''')||
        ',AVAILABLE');
    end loop;
    dbms_sql.close_cursor(c);
    if visible_rows = 0 then
      dbms_output.put_line(to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"')||','||
        dbid_value||',,,,,,,,NO_VISIBLE_DISKGROUPS_VERIFY_USAGE');
    end if;
  exception
    when others then
      if dbms_sql.is_open(c) then dbms_sql.close_cursor(c); end if;
      if sqlcode not in (-942,-904,-1031) then raise; end if;
      dbms_output.put_line(to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"')||','||
        dbid_value||',,,,,,,,"UNAVAILABLE_OR_VIEW_NOT_VISIBLE: '||replace(sqlerrm,'"','""')||'"');
  end;
end;
/
spool off
