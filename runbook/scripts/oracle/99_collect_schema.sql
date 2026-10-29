-- Called only by script 99's generated driver with a validated catalog owner.
-- Capture the argument before script 00 replaces SQL*Plus positional variables.
define assessment_owner = '&1'
column assessment_schema_mkdir new_value assessment_schema_mkdir noprint
select case &assessment_client_os
         when 1 then 'mkdir "' ||
           replace('&assessment_run_dir./oracle/schemas/&assessment_owner','/',chr(92)) || '"'
         else 'mkdir -p -m 700 ''&assessment_run_dir./oracle/schemas/&assessment_owner'''
       end assessment_schema_mkdir
  from dual;
host &assessment_schema_mkdir
@@00_set_environment.sql "&assessment_run_dir./oracle/schemas/&assessment_owner"
@@08_schema_inventory.sql &assessment_owner
@@09_object_type_inventory.sql &assessment_owner
@@10_table_index_partition_inventory.sql &assessment_owner
@@11_lob_inventory.sql &assessment_owner
@@12_data_type_compatibility.sql &assessment_owner
@@13_code_object_inventory.sql &assessment_owner
@@14_oracle_feature_usage.sql &assessment_owner
@@15_dependencies_and_database_links.sql &assessment_owner
@@16_jobs_queues_directories_external_tables.sql &assessment_owner
@@17_security_roles_and_privileges_summary.sql &assessment_owner
@@33_configuration_risk_checks.sql &assessment_owner
