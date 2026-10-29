-- File: 02_database_identity_and_version.sql
-- Purpose: Record database identity, version banners, edition and operating mode.
-- Data collected: DBID, database role/open mode, version and platform identifiers.
-- Expected privileges: V_$DATABASE, V_$VERSION.
-- Scope: Database.
-- Oracle versions: 10g and later; version banner varies by release.
-- Licensing: None.
-- Expected output: 02_database_identity.csv and 02_version_banners.csv.
-- Sensitive metadata: Yes.
-- Run once for each database; record container separately.
whenever sqlerror continue
spool "&output_dir./02_database_identity.csv"
prompt COLLECTION_UTC,DBID,DB_NAME,DB_UNIQUE_NAME,DATABASE_ROLE,OPEN_MODE,LOG_MODE,PLATFORM_ID,PLATFORM_NAME
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       dbid,replace(name,',',' '),replace(db_unique_name,',',' '),
       database_role,open_mode,log_mode,platform_id,replace(platform_name,',',' ')
  from v$database;
spool off
spool "&output_dir./02_version_banners.csv"
prompt VERSION_BANNER
select replace(banner,',',' ') from v$version order by banner;
spool off
