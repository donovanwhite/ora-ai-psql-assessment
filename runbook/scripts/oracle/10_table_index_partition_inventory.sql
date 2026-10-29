-- File: 10_table_index_partition_inventory.sql
-- Purpose: Capture table, index, partition, IOT, temporary and compression metadata.
-- Data collected: DBA_TABLES, DBA_INDEXES, DBA_TAB_PARTITIONS.
-- Expected privileges: DBA_* catalog views; DBA-run output alternative.
-- Scope: Schema. Run once per approved owner.
-- Oracle versions: 10g and later; some attributes vary by release.
-- Licensing: None.
-- Expected output: 10_table_index_partition_<OWNER>.csv.
-- Sensitive metadata: Yes.
-- Argument &1 must be one approved Oracle identifier.
whenever sqlerror continue
spool "&output_dir./10_table_index_partition_&1..csv"
prompt COLLECTION_UTC,DBID,OWNER,OBJECT_NAME,OBJECT_KIND,PARTITIONED,NUM_ROWS,BLOCKS,ATTRIBUTE
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),owner,table_name,'TABLE',
       partitioned,num_rows,blocks,iot_type
  from dba_tables where owner=upper('&1')
union all
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),owner,index_name,'INDEX',
       partitioned,num_rows,leaf_blocks,index_type
  from dba_indexes where owner=upper('&1')
union all
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),table_owner,table_name,'TABLE_PARTITION',
       'YES',num_rows,blocks,partition_name
  from dba_tab_partitions where table_owner=upper('&1')
order by 3,4,5;
spool off
