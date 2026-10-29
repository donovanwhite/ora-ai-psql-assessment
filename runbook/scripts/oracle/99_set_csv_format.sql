-- Client-only formatting shared by initial collection and fresh-session recovery.
-- Do not spool or recreate run_environment.csv while restoring a workload run.
set echo off
set verify off
set feedback off
set heading off
set pagesize 0
set newpage none
set recsep off
set numformat TM9
set linesize 32767
set trimspool on
set tab off
set termout on
set define on
set colsep ,
set serveroutput on size 1000000
