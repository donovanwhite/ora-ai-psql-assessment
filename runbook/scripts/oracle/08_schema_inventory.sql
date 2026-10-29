-- File: 08_schema_inventory.sql
-- Purpose: Inventory one explicitly approved schema owner.
-- Data collected: Account status/profile/creation and object counts.
-- Expected privileges: DBA_USERS, DBA_OBJECTS; ALL_* alternative may undercount.
-- Scope: Schema. Run once per approved owner.
-- Oracle versions: 10g and later.
-- Licensing: None.
-- Expected output: 08_schema_inventory_<OWNER>.csv.
-- Sensitive metadata: Yes; owner and account metadata.
-- Argument &1 must be one approved Oracle identifier, not a wildcard or SQL fragment.
whenever sqlerror continue
spool "&output_dir./08_schema_inventory_&1..csv"
prompt COLLECTION_UTC,DBID,OWNER,ACCOUNT_STATUS,CREATED,PROFILE,OBJECT_TYPE,OBJECT_COUNT,INVALID_COUNT
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),u.username,u.account_status,
       to_char(u.created,'YYYY-MM-DD'),u.profile,o.object_type,count(o.object_type),
       sum(case when o.status='INVALID' then 1 else 0 end)
  from dba_users u,dba_objects o
 where u.username=upper('&1') and o.owner(+)=u.username
 group by u.username,u.account_status,u.created,u.profile,o.object_type
 order by o.object_type;
spool off
