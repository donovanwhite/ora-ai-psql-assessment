-- File: 17_security_roles_and_privileges_summary.sql
-- Purpose: Summarize grants and roles touching one approved schema.
-- Data collected: Role/system/object privilege metadata; no password hashes.
-- Expected privileges: DBA_TAB_PRIVS, DBA_ROLE_PRIVS, DBA_SYS_PRIVS.
-- Scope: Database and schema.
-- Oracle versions: 10g and later.
-- Licensing: None.
-- Expected output: 17_security_summary_<OWNER>.csv.
-- Sensitive metadata: Restricted; review and redact before handover.
-- Argument &1 must be one approved Oracle identifier.
whenever sqlerror continue
spool "&output_dir./17_security_summary_&1..csv"
prompt COLLECTION_UTC,DBID,GRANTEE,GRANT_TYPE,PRIVILEGE,OBJECT_OWNER,OBJECT_NAME,GRANTABLE
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),grantee,'OBJECT',privilege,owner,table_name,grantable
  from dba_tab_privs where owner=upper('&1') or grantee=upper('&1')
union all
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),grantee,'ROLE',granted_role,null,null,admin_option
  from dba_role_privs where grantee=upper('&1')
union all
select to_char(sys_extract_utc(systimestamp),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       (select dbid from v$database),grantee,'SYSTEM',privilege,null,null,admin_option
  from dba_sys_privs where grantee=upper('&1')
order by 3,4,5;
spool off
