-- File: 13_code_object_inventory.sql
-- Purpose: Inventory PL/SQL source size without exporting source text.
-- Data collected: Object type, source line count and source bytes.
-- Expected privileges: DBA_SOURCE and DBA_OBJECTS; DBA-run output alternative.
-- Scope: Schema. Run once per approved owner. Does not export source text.
-- Oracle versions: 10g and later.
-- Licensing: None.
-- Expected output: 13_code_object_inventory_<OWNER>.csv.
-- Sensitive metadata: Yes; object names and code-derived patterns.
-- Argument &1 must be one approved Oracle identifier.
whenever sqlerror continue
spool "&output_dir./13_code_object_inventory_&1..csv"
prompt COLLECTION_UTC,DBID,OWNER,NAME,TYPE,SOURCE_LINES,SOURCE_BYTES,STATIC_PATTERN_SCAN
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),s.owner,s.name,s.type,count(*),sum(lengthb(s.text)),
       'NOT_SCANNED'
  from dba_source s
 where s.owner=upper('&1')
 group by s.owner,s.name,s.type
 order by s.type,s.name;
spool off
