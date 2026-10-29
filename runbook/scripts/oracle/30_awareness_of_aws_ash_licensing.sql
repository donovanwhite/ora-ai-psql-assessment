-- File: 30_awareness_of_aws_ash_licensing.sql
-- Purpose: Record the AWR/ASH licensing checkpoint; collect no licensed history.
-- Data collected: Checkpoint text only.
-- Expected privileges: None beyond an Oracle SQL*Plus session.
-- Scope: Assessment process.
-- Oracle versions: 10g and later.
-- Licensing: This script does not authorize or query Diagnostics/Tuning Pack data.
-- Expected output: 30_awr_ash_licensing_checkpoint.csv.
-- Sensitive metadata: No.
-- IMPORTANT: AWR/ASH remain excluded unless separately approved in writing.
whenever sqlerror continue
spool "&output_dir./30_awr_ash_licensing_checkpoint.csv"
prompt CHECKPOINT,STATUS,ACTION
prompt ORACLE_DIAGNOSTICS_PACK,NOT_CONFIRMED,DO_NOT_RUN_AWR_OR_ASH
prompt ORACLE_TUNING_PACK,NOT_CONFIRMED,DO_NOT_USE_TUNING_PACK_FEATURES
prompt CUSTOMER_WRITTEN_APPROVAL,REQUIRED,RECORD_APPROVAL_BEFORE_OPTIONAL_SCRIPT_31
prompt BASELINE,AVAILABLE,USE_VIEWS_OS_EVIDENCE_AND_EXISTING_APPROVED_STATSPACK
spool off
