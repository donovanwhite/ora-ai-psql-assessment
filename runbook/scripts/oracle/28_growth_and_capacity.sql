-- File: 28_growth_and_capacity.sql
-- Purpose: Capture current allocated/used segment and datafile capacity evidence.
-- Data collected: DBA_SEGMENTS, DBA_DATA_FILES; no historical AWR growth.
-- Expected privileges: DBA_SEGMENTS, DBA_DATA_FILES; DBA-run output alternative.
-- Scope: Database; segment summary by owner and type.
-- Oracle versions: 10g and later.
-- Licensing: None.
-- Expected output: 28_growth_capacity.csv.
-- Sensitive metadata: Yes; storage footprint.
whenever sqlerror continue
spool "&output_dir./28_growth_capacity.csv"
prompt COLLECTION_UTC,DBID,OWNER,SEGMENT_TYPE,ALLOCATED_BYTES,DATAFILE_MAX_BYTES
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),s.owner,s.segment_type,sum(s.bytes),
       (select sum(case when maxbytes>0 then maxbytes else bytes end) from dba_data_files)
  from dba_segments s
 group by s.owner,s.segment_type
 order by s.owner,s.segment_type;
spool off
prompt Historical growth is not calculated here; use approved existing evidence or business forecasts.
