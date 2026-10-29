-- File: 09_object_type_inventory.sql
-- Purpose: Count object types and invalid objects for one approved schema.
-- Data collected: DBA_OBJECTS counts by type/status.
-- Expected privileges: DBA_OBJECTS; DBA-run output alternative.
-- Scope: Schema. Run once per approved owner.
-- Oracle versions: 10g and later.
-- Licensing: None.
-- Expected output: 09_object_type_inventory_<OWNER>.csv.
-- Sensitive metadata: Yes.
-- Argument &1 must be one approved Oracle identifier.
whenever sqlerror continue
spool "&output_dir./09_object_type_inventory_&1..csv"
prompt COLLECTION_UTC,DBID,OWNER,OBJECT_TYPE,STATUS,OBJECT_COUNT
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),owner,object_type,status,count(*)
  from dba_objects where owner=upper('&1')
 group by owner,object_type,status order by object_type,status;
spool off
