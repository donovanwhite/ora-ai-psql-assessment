---
title: Oracle to Azure PostgreSQL assessment
description: SQL*Plus evidence collection, optional offline reporting, and an operator guide for Oracle-to-PostgreSQL assessment.
---

## Start here

[Open the PDF execution guide](runbook/instructions/Oracle-to-Azure-PostgreSQL-Assessment-Runbook.pdf).
It covers Oracle collection, recovery, evidence review, optional HTML reporting,
and separately approved Azure and VS Code conversion workflows.

This is an assessment toolkit, not a production data-migration tool.

## Collect Oracle evidence

1. Copy `runbook` to an approved, protected working directory outside the Git
   checkout. Keep its folder structure intact.
2. Follow the PDF prerequisites and connect to the approved database or PDB
   using **SQL*Plus**, the only supported Oracle collection client.
3. From that working directory, run this at the connected `SQL>` prompt:

```sql
@scripts\oracle\99_run_complete_assessment.sql
```

Select the approved schema owners and workload interval when prompted.
The runner creates a unique folder under `output`. If an interval is unfinished,
use the continuation or reconnect-recovery commands in PDF section 5 rather
than restarting the entire assessment.

## Optional HTML report

After collection has stopped writing files, run this in PowerShell from the
working copy's root. Replace the bracketed folder name with your actual run.
This optional step requires PowerShell 7 or later.

```powershell
pwsh -NoProfile -File .\scripts\post-assessment-report\New-OracleAssessmentReport.ps1 `
  -InputPath ".\output\<GENERATED_RUN_FOLDER>"
```

The result is `oracle_report.html` inside the run folder, with offline charts
and evidence-review notes.
[Report details and exit codes](runbook/scripts/post-assessment-report/README.md).

## Package layout

* `runbook\instructions`: PDF guide and blank evidence-record templates
* `runbook\scripts`: collectors, recovery helpers, validators and report generator
* `runbook\output`: created during collection for evidence and optional reports
