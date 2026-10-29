-- File: 15_dependencies_and_database_links.sql
-- Purpose: Capture inbound/outbound dependencies and redacted database-link metadata.
-- Data collected: DBA_DEPENDENCIES and DBA_DB_LINKS metadata.
-- Expected privileges: DBA_DEPENDENCIES, DBA_DB_LINKS; DBA-run output alternative.
-- Scope: Database and selected schema.
-- Oracle versions: 10g and later.
-- Licensing: None.
-- Expected output: 15_dependencies_<OWNER>.csv and 15_database_links.csv.
-- Sensitive metadata: Yes; link users/hosts are redacted by default.
-- Argument &1 must be one approved Oracle identifier.
whenever sqlerror continue
spool "&output_dir./15_dependencies_&1..csv"
prompt COLLECTION_UTC,DBID,DIRECTION,OWNER,NAME,TYPE,REFERENCED_OWNER,REFERENCED_NAME,REFERENCED_TYPE
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),'OUTBOUND',owner,name,type,referenced_owner,referenced_name,referenced_type
  from dba_dependencies where owner=upper('&1')
union all
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),'INBOUND',owner,name,type,referenced_owner,referenced_name,referenced_type
  from dba_dependencies where referenced_owner=upper('&1') and owner<>upper('&1')
order by 3,4,5;
spool off
spool "&output_dir./15_database_links.csv"
prompt COLLECTION_UTC,DBID,OWNER,DB_LINK,USERNAME,HOST,REDACTION
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),owner,db_link,'[REDACTED]','[REDACTED]','DEFAULT'
  from dba_db_links
 where owner in (upper('&1'),'PUBLIC')
 order by owner,db_link;
spool off
