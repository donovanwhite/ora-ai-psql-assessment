---
title: Oracle post-assessment report package
description: Generate a self-contained offline HTML and SVG evidence report from one Oracle assessment run.
---

## Generate a report

This is an **optional post-collection step**. Script `99` does not launch it.
You can skip HTML generation and complete the required CSV validation and
handover normally; do not create an empty report to satisfy a checklist.

Use **PowerShell 7 or later** on the workstation holding your collected evidence.
PowerShell 7 is needed only if you choose this optional reporting step, not
for Oracle collection itself.
SQL*Plus remains the only supported database collection client. This package
does not connect to Oracle or require Java, Python, modules, chart libraries,
cloud resources, or an internet connection.

Open PowerShell in the `runbook` root, the folder containing `instructions`,
`scripts` and `output`. Confirm the runtime with `pwsh --version`, then run:

```powershell
pwsh -NoProfile -File .\scripts\post-assessment-report\New-OracleAssessmentReport.ps1 `
  -InputPath ".\output\<GENERATED_RUN_FOLDER>"
```

Replace every `<PLACEHOLDER>`, including the brackets, before execution.
`InputPath` must identify **one run folder**, not the package or `output` parent.
The folder must retain the collected `oracle` and `performance` subdirectories.
Keep the complete `scripts` tree together. The generator shares
`scripts\validation\required-files.txt` with the evidence validators; that file
is a required-output checklist, not a checksum manifest. No files outside
`runbook` or separate report ZIP are needed.

The default result is `oracle_report.html` inside that run folder. Open it in a
browser. Keep the report with its run folder so the relative source-CSV links work.
Reports can also be generated for incomplete runs; missing evidence is shown
explicitly and is never assumed to be zero.

The script prints the report location and returns:

| Exit code | Meaning |
|-----------|---------|
| 0 | Report written; no missing/invalid evidence or review warnings detected |
| 2 | Report written; review warnings, incomplete evidence, or invalid data need attention |
| 1 | Report could not be generated; an actionable error is printed |

Exit code 2 does not mean the HTML generation failed. Open the report and review
its issues section. A completion marker alone is not proof that collection passed.
Generate after SQL*Plus has finished or stopped and closed its CSV files.
Do not run the generator while collection or recovery is writing evidence.
Use an unchanged handover copy when reproducible reporting is required.

The generator replaces only a report carrying its own generator marker. It
refuses to overwrite unrelated HTML, linked files, or CSV evidence. If local
script policy blocks execution, follow your organization's approval/unblocking
process rather than disabling execution policy globally.

## Report contents

* Database identity, active PDB, login/current schema, and selected application owners
* Instance, memory, resource-limit, schema, object, type, feature, and review-flag summaries
* Container storage and selected-owner allocation, without double-counting repeated datafile capacity
* Per-window and per-instance performance charts with window/instance filters
* Explicit missing, invalid, unavailable, and inconclusive evidence diagnostics
* Local source links, file sizes, row counts, and SHA-256 evidence hashes

Detail tables show at most 100 records; summary counts include every parsed row.
Review issues and the source-evidence list are not truncated.
LOB columns are counted by distinct owner/table/column, not partition-segment
rows. Repeated metadata at a declared unique grain is flagged, not double-counted.
The full CSV remains authoritative. Performance datasets exceeding 100,000 rows
per file are rejected rather than silently sampled. Symbolic links and reparse points are
not followed. Unknown CSV filenames are not read.

All charts are embedded SVG. The report contains its own CSS and small,
fixed filter script, with a restrictive content-security policy. No CDNs, web
fonts, analytics, external scripts, live queries, or AI-generated conclusions
are used. Treat the HTML as sensitive metadata, just like its source pack.

## Interpret performance correctly

The chart grain is **one run, workload window, and Oracle instance**. Counter
pairs must agree on DBID, instance identity, startup markers, counter names, and
valid UTC timestamps. Duplicate counters, resets, negative deltas, and zero or
negative elapsed time cause rates to be withheld.

The active PDB is taken from the run's scope evidence. Counter files do not
include `CON_ID`, so the charts do not prove PDB-exclusive resource attribution.
Preserve the execution record and do not add duplicate instance-wide counters
collected through separate PDB runs.

| Chart | Calculation and scope |
|-------|-----------------------|
| Read/write throughput | Byte-counter delta / actual elapsed seconds / 1,048,576, shown as MiB/s |
| Read/write IOPS | I/O-request delta / actual elapsed seconds |
| Redo | Redo-byte delta / actual elapsed seconds / 1,048,576 |
| Activity | Execution, commit, rollback, and logical-read deltas / actual elapsed seconds |
| DB time / DB CPU | Microsecond delta / 1,000,000 / actual elapsed seconds |
| Wait ranking | `TIME_WAITED / 100` seconds, cumulative since instance startup |
| Cached SQL ranking | Cumulative buffer gets for the captured cached cursors, not interval-only SQL |

The requested interval is not used as the denominator. A recovered run can have
a longer actual interval, which the report displays. Different counter pairs
use their own recorded timestamps; timestamp precision is one second.

DB CPU is a component of DB time, so those bars are not additive. They are
database activity measurements, not total server CPU utilization. Waits and
cached SQL are separate cumulative snapshots. Oracle's `SYSMETRIC` file covers
its own short rolling windows, not the complete assessment interval.

START/END pairs provide averages, not a continuous timeline. They cannot reveal
a short spike within a longer window. No synthetic trend line is drawn.
Additional timestamped samples would be needed for trend charts.

## Other options

Write the report to an existing directory elsewhere:

```powershell
pwsh -NoProfile -File .\scripts\post-assessment-report\New-OracleAssessmentReport.ps1 `
  -InputPath ".\output\<GENERATED_RUN_FOLDER>" `
  -OutputPath "C:\<REPORT_DIRECTORY>\oracle_report.html"
```

The generator defaults to UTF-8 and detects byte-order marks. If SQL*Plus wrote
Windows-1252 evidence, explicitly select that encoding:

```powershell
pwsh -NoProfile -File .\scripts\post-assessment-report\New-OracleAssessmentReport.ps1 `
  -InputPath ".\output\<GENERATED_RUN_FOLDER>" `
  -CsvEncoding windows-1252
```

Invalid encoding is reported, not silently repaired. Do not edit the raw CSVs
to make the report look complete. Record and resolve collection gaps with the DBA.

## Runbook contents

The self-contained runbook has three top-level folders:

* `instructions`: the PDF execution guide and blank evidence-record templates
* `scripts`: Oracle collectors, optional host/Statspack collectors, validators and this optional report generator
* `output`: collected runs and any generated reports

The report folder contains only the generator and this guide. Development tests,
ZIP builders and package checksum manifests are not runtime requirements.
The source codebase outside `runbook` is separate and is not read by the report.

Reports are deterministic for the same input paths, evidence bytes, package,
and PowerShell version. Generator/contract hashes and the runtime version are
recorded alongside the CSV hashes. Source files are read-only to the generator.
An evidence report is not
a license assessment, a PostgreSQL compatibility certification, or a production
capacity recommendation.
