-- File: 14_oracle_feature_usage.sql
-- Purpose: Inventory selected schema features and optional database feature-use evidence.
-- Data collected: Object metadata for selected schema features.
-- Expected privileges: DBA_OBJECTS, DBA_TABLES, DBA_INDEXES, DBA_IND_EXPRESSIONS.
-- Scope: Database and approved schema. Run once per schema.
-- Oracle versions: 10g and later; feature counters vary and are not license advice.
-- Licensing: Reading usage is not proof of entitlement; consult Oracle licensing specialists.
-- Expected output: 14_feature_usage_<OWNER>.csv.
-- Sensitive metadata: Yes.
-- Argument &1 must be one approved Oracle identifier.
whenever sqlerror continue
spool "&output_dir./14_feature_usage_&1..csv"
prompt COLLECTION_UTC,DBID,OWNER,FEATURE_GROUP,ATTRIBUTE,OBJECT_COUNT
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),upper('&1'),'TABLE_FEATURE','PARTITIONED',
       (select count(*) from dba_tables where owner=upper('&1') and partitioned='YES')
  from dual
union all
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),upper('&1'),'TABLE_FEATURE','IOT',
       (select count(*) from dba_tables where owner=upper('&1') and iot_type is not null)
  from dual
union all
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),upper('&1'),'INDEX_FEATURE','BITMAP',
       (select count(*) from dba_indexes where owner=upper('&1') and index_type='BITMAP')
  from dual
union all
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),upper('&1'),'INDEX_FEATURE','FUNCTION_BASED',
       (select count(distinct index_name) from dba_ind_expressions where index_owner=upper('&1'))
  from dual;
spool off
prompt Optional database feature usage is customer/Oracle-licensing evidence only.
