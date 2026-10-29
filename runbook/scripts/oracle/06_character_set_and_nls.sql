-- File: 06_character_set_and_nls.sql
-- Purpose: Capture character sets, NLS settings, time zone and block size.
-- Data collected: NLS database/session parameters and database time zone.
-- Expected privileges: V_$NLS_PARAMETERS, V_$PARAMETER.
-- Scope: Database and current session.
-- Oracle versions: 10g and later.
-- Licensing: None.
-- Expected output: 06_character_set_nls.csv.
-- Sensitive metadata: No application rows; configuration metadata.
whenever sqlerror continue
spool "&output_dir./06_character_set_nls.csv"
prompt COLLECTION_UTC,DBID,PARAMETER,VALUE
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),parameter,replace(value,',',' ')
  from nls_database_parameters
 where parameter in ('NLS_CHARACTERSET','NLS_NCHAR_CHARACTERSET','NLS_LENGTH_SEMANTICS',
   'NLS_COMP','NLS_SORT','NLS_TERRITORY','NLS_LANGUAGE','NLS_DATE_FORMAT',
   'NLS_TIMESTAMP_FORMAT','NLS_NUMERIC_CHARACTERS')
union all
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),'DBTIMEZONE',dbtimezone from dual
union all
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),'DB_BLOCK_SIZE',value
  from v$parameter where name='db_block_size';
spool off
