-- File: 01_assessment_precheck.sql
-- Purpose: Verify identity, read-only session, and basic catalog visibility.
-- Data collected: DB identity, user, role, dictionary-view visibility.
-- Expected privileges: V_$DATABASE, V_$INSTANCE; ALL_* views.
-- Scope: Database and current instance/container.
-- Oracle versions: 10g and later.
-- Licensing: None.
-- Expected output: 01_assessment_precheck.csv.
-- Sensitive metadata: Yes.
-- Run from an approved non-SYS assessment account.
whenever sqlerror continue
spool "&output_dir./01_assessment_precheck.csv"
prompt COLLECTION_UTC,DBID,DB_NAME,DB_UNIQUE_NAME,DB_ROLE,INSTANCE,SESSION_USER,SESSION_DB_NAME,DICTIONARY_OBJECTS_VISIBLE
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       d.dbid,replace(d.name,',',' '),replace(d.db_unique_name,',',' '),
       d.database_role,i.instance_name,sys_context('USERENV','SESSION_USER'),
       sys_context('USERENV','DB_NAME'),
       (select count(*) from all_objects where rownum <= 1000000)
  from v$database d, v$instance i;
spool off
prompt Precheck passed only if the preceding query returned a row without ORA errors.
