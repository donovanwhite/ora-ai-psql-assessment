-- File: 11_lob_inventory.sql
-- Purpose: Inventory LOB columns and segment allocation for one approved schema.
-- Data collected: DBA_LOBS and segment bytes.
-- Expected privileges: DBA_LOBS, DBA_SEGMENTS; DBA-run output alternative.
-- Scope: Schema. Run once per approved owner.
-- Oracle versions: 10g and later; SECUREFILE attributes are not assumed.
-- Licensing: None.
-- Expected output: 11_lob_inventory_<OWNER>.csv.
-- Sensitive metadata: Yes; object names and footprint.
-- Argument &1 must be one approved Oracle identifier.
whenever sqlerror continue
spool "&output_dir./11_lob_inventory_&1..csv"
prompt COLLECTION_UTC,DBID,OWNER,TABLE_NAME,COLUMN_NAME,SEGMENT_NAME,INDEX_NAME,LOB_BYTES
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),l.owner,l.table_name,l.column_name,
       l.segment_name,l.index_name,nvl(s.bytes,0)
  from dba_lobs l,dba_segments s
 where l.owner=upper('&1') and s.owner(+)=l.owner
   and s.segment_name(+)=l.segment_name
 order by l.table_name,l.column_name;
spool off
