-- File: 12_data_type_compatibility.sql
-- Purpose: Inventory column types, precision, nullability and legacy data types.
-- Data collected: DBA_TAB_COLUMNS metadata only; no table rows.
-- Expected privileges: DBA_TAB_COLUMNS; ALL_TAB_COLUMNS alternative may undercount.
-- Scope: Schema. Run once per approved owner.
-- Oracle versions: 10g and later.
-- Licensing: None.
-- Expected output: 12_data_type_compatibility_<OWNER>.csv.
-- Sensitive metadata: Yes; schema definition.
-- Argument &1 must be one approved Oracle identifier.
whenever sqlerror continue
spool "&output_dir./12_data_type_compatibility_&1..csv"
prompt COLLECTION_UTC,DBID,OWNER,TABLE_NAME,COLUMN_NAME,DATA_TYPE,DATA_LENGTH,CHAR_LENGTH,CHAR_USED,PRECISION,SCALE,NULLABLE
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),owner,table_name,column_name,data_type,
       data_length,char_length,char_used,data_precision,data_scale,nullable
  from dba_tab_columns
 where owner=upper('&1')
 order by table_name,column_id;
spool off
