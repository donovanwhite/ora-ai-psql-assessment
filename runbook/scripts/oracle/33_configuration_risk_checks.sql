-- File: 33_configuration_risk_checks.sql
-- Purpose: Flag selected configuration and schema features for human review.
-- Data collected: Parameter values, invalid objects, and Oracle-specific object types.
-- Expected privileges: V_$PARAMETER, DBA_OBJECTS, DBA_TABLES; DBA-run output alternative.
-- Scope: Database and one approved schema.
-- Oracle versions: 10g and later; later features may be unavailable.
-- Licensing: None; this is not licensing advice.
-- Expected output: 33_configuration_risks_<OWNER>.csv.
-- Sensitive metadata: Yes.
-- Argument &1 must be one approved Oracle identifier.
whenever sqlerror continue
spool "&output_dir./33_configuration_risks_&1..csv"
prompt COLLECTION_UTC,DBID,OWNER,RISK_CATEGORY,EVIDENCE,COUNT_OR_VALUE
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),upper('&1'),'INVALID_OBJECTS',
       'DBA_OBJECTS.STATUS=INVALID',
       (select count(*) from dba_objects where owner=upper('&1') and status='INVALID')
  from dual
union all
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),upper('&1'),'OBJECT_TABLES',
       'DBA_OBJECT_TABLES',
       (select count(*) from dba_object_tables where owner=upper('&1'))
  from dual
union all
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),upper('&1'),'GLOBAL_TEMPORARY_TABLES',
       'DBA_TABLES.TEMPORARY=Y',
       (select count(*) from dba_tables where owner=upper('&1') and temporary='Y')
  from dual
union all
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),upper('&1'),'ORACLE_FEATURE',
       object_type,count(*)
  from dba_objects
 where owner=upper('&1') and object_type in ('JAVA CLASS','JAVA SOURCE','TYPE',
   'TYPE BODY','MATERIALIZED VIEW','TRIGGER','PACKAGE','PACKAGE BODY')
 group by object_type;
spool off
