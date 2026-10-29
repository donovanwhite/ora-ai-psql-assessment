-- File: 27_data_guard_inventory.sql
-- Purpose: Capture database role, protection, archive destinations and standby status.
-- Data collected: V$DATABASE and V$ARCHIVE_DEST_STATUS metadata.
-- Expected privileges: V_$DATABASE, V_$ARCHIVE_DEST_STATUS.
-- Scope: Database and instance.
-- Oracle versions: 10g and later; some columns vary by release.
-- Licensing: None.
-- Expected output: 27_data_guard_inventory.csv.
-- Sensitive metadata: Yes; disaster-recovery topology.
whenever sqlerror continue
spool "&output_dir./27_data_guard_inventory.csv"
prompt COLLECTION_UTC,DBID,ITEM,VALUE
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       dbid,'DATABASE_ROLE',database_role from v$database
union all
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       dbid,'PROTECTION_MODE',protection_mode from v$database
union all
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       dbid,'PROTECTION_LEVEL',protection_level from v$database
union all
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       dbid,'FORCE_LOGGING',force_logging from v$database
union all
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),'ARCHIVE_DEST:'||to_char(dest_id),
       status||';TYPE='||type||';ERROR='||replace(nvl(error,''),',',' ')
  from v$archive_dest_status where dest_id <= 10;
spool off
