-- File: 07_tablespace_and_storage.sql
-- Purpose: Report tablespace/datafile/tempfile allocation, used, free and autoextend capacity.
-- Data collected: DBA_DATA_FILES, DBA_TEMP_FILES, DBA_FREE_SPACE, DBA_TABLESPACES.
-- Expected privileges: DBA_* catalog views; DBA-run output is an alternative.
-- Scope: Database.
-- Oracle versions: 10g and later.
-- Licensing: None.
-- Expected output: 07_tablespace_capacity.csv and 07_tempfile_capacity.csv.
-- Sensitive metadata: Yes; storage layout.
whenever sqlerror continue
spool "&output_dir./07_tablespace_capacity.csv"
prompt COLLECTION_UTC,TABLESPACE,ALLOCATED_BYTES,FREE_BYTES,USED_BYTES,MAX_BYTES,AUTOEXTENSIBLE
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       d.tablespace_name,sum(d.bytes),
       nvl(f.free_bytes,0),sum(d.bytes)-nvl(f.free_bytes,0),
       sum(case when d.maxbytes > 0 then d.maxbytes else d.bytes end),
       max(d.autoextensible)
  from dba_data_files d,
       (select tablespace_name,sum(bytes) free_bytes from dba_free_space group by tablespace_name) f
 where d.tablespace_name=f.tablespace_name(+)
 group by d.tablespace_name,f.free_bytes order by d.tablespace_name;
spool off
spool "&output_dir./07_tempfile_capacity.csv"
prompt COLLECTION_UTC,TABLESPACE,TEMPFILE_COUNT,ALLOCATED_BYTES,MAX_BYTES,AUTOEXTENSIBLE
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       tablespace_name,count(*),sum(bytes),
       sum(case when maxbytes > 0 then maxbytes else bytes end),max(autoextensible)
  from dba_temp_files group by tablespace_name order by tablespace_name;
spool off
