#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0

<#
.SYNOPSIS
    Builds an offline HTML/SVG report from one Oracle assessment run.
.DESCRIPTION
    Reads recognized CSV evidence only. Does not connect to Oracle, execute
    collected SQL, load credentials, or change source evidence. Exit codes:
    0 = report generated without review issues; 2 = report generated but review
    is required; 1 = report could not be generated.
.PARAMETER InputPath
    One generated assessment run directory, not the package or output parent.
.PARAMETER OutputPath
    HTML destination. Defaults to oracle_report.html inside InputPath.
.PARAMETER CsvEncoding
    Source CSV encoding. UTF-8 is the default; BOMs are detected.
.EXAMPLE
    pwsh -NoProfile -File .\scripts\post-assessment-report\New-OracleAssessmentReport.ps1 -InputPath ".\output\<GENERATED_RUN_FOLDER>"
.NOTES
    Run from the runbook root. Keep scripts\validation\required-files.txt.
    PowerShell 7 or later. No modules, database clients or network access needed.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$InputPath,
    [string]$OutputPath = '',
    [ValidateSet('utf8', 'windows-1252')]
    [string]$CsvEncoding = 'utf8'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName Microsoft.VisualBasic.Core

#region Contracts
$script:Version = '1.0.0'
$script:Culture = [Globalization.CultureInfo]::InvariantCulture
$script:Headers = @{
    'run_environment.csv' = 'COLLECTION_UTC,DBID,DB_UNIQUE_NAME,INSTANCE,CURRENT_SCHEMA'
    '01_assessment_precheck.csv' = 'COLLECTION_UTC,DBID,DB_NAME,DB_UNIQUE_NAME,DB_ROLE,INSTANCE,SESSION_USER,SESSION_DB_NAME,DICTIONARY_OBJECTS_VISIBLE'
    '02_database_identity.csv' = 'COLLECTION_UTC,DBID,DB_NAME,DB_UNIQUE_NAME,DATABASE_ROLE,OPEN_MODE,LOG_MODE,PLATFORM_ID,PLATFORM_NAME'
    '02_version_banners.csv' = 'VERSION_BANNER'
    '03_instance_configuration.csv' = 'COLLECTION_UTC,DBID,INST_ID,INSTANCE_NAME,HOST_NAME,VERSION,STARTUP_TIME,STATUS,THREAD,PARALLEL'
    '03_host_os_stats.csv' = 'OSSTAT_COLLECTION_UTC,INST_ID,STAT_NAME,VALUE'
    '04_cdb_pdb_inventory.csv' = 'COLLECTION_UTC,DBID,CONTAINER_TYPE,ACTIVE_CONTAINER,CONTAINER_NAME,OPEN_MODE,CON_ID,STATUS'
    '05_initialization_parameters.csv' = 'COLLECTION_UTC,INST_ID,NAME,VALUE,ISDEFAULT,ISMODIFIED'
    '06_character_set_nls.csv' = 'COLLECTION_UTC,DBID,PARAMETER,VALUE'
    '07_tablespace_capacity.csv' = 'COLLECTION_UTC,TABLESPACE,ALLOCATED_BYTES,FREE_BYTES,USED_BYTES,MAX_BYTES,AUTOEXTENSIBLE'
    '07_tempfile_capacity.csv' = 'COLLECTION_UTC,TABLESPACE,TEMPFILE_COUNT,ALLOCATED_BYTES,MAX_BYTES,AUTOEXTENSIBLE'
    '08_schema_inventory_<OWNER>.csv' = 'COLLECTION_UTC,DBID,OWNER,ACCOUNT_STATUS,CREATED,PROFILE,OBJECT_TYPE,OBJECT_COUNT,INVALID_COUNT'
    '09_object_type_inventory_<OWNER>.csv' = 'COLLECTION_UTC,DBID,OWNER,OBJECT_TYPE,STATUS,OBJECT_COUNT'
    '10_table_index_partition_<OWNER>.csv' = 'COLLECTION_UTC,DBID,OWNER,OBJECT_NAME,OBJECT_KIND,PARTITIONED,NUM_ROWS,BLOCKS,ATTRIBUTE'
    '11_lob_inventory_<OWNER>.csv' = 'COLLECTION_UTC,DBID,OWNER,TABLE_NAME,COLUMN_NAME,SEGMENT_NAME,INDEX_NAME,LOB_BYTES'
    '12_data_type_compatibility_<OWNER>.csv' = 'COLLECTION_UTC,DBID,OWNER,TABLE_NAME,COLUMN_NAME,DATA_TYPE,DATA_LENGTH,CHAR_LENGTH,CHAR_USED,PRECISION,SCALE,NULLABLE'
    '13_code_object_inventory_<OWNER>.csv' = 'COLLECTION_UTC,DBID,OWNER,NAME,TYPE,SOURCE_LINES,SOURCE_BYTES,STATIC_PATTERN_SCAN'
    '14_feature_usage_<OWNER>.csv' = 'COLLECTION_UTC,DBID,OWNER,FEATURE_GROUP,ATTRIBUTE,OBJECT_COUNT'
    '15_dependencies_<OWNER>.csv' = 'COLLECTION_UTC,DBID,DIRECTION,OWNER,NAME,TYPE,REFERENCED_OWNER,REFERENCED_NAME,REFERENCED_TYPE'
    '15_database_links.csv' = 'COLLECTION_UTC,DBID,OWNER,DB_LINK,USERNAME,HOST,REDACTION'
    '16_jobs_queues_directories_<OWNER>.csv' = 'COLLECTION_UTC,DBID,OWNER,CATEGORY,OBJECT_NAME,DETAIL'
    '16_directories.csv' = 'COLLECTION_UTC,DBID,OWNER,DIRECTORY_NAME,DIRECTORY_PATH'
    '17_security_summary_<OWNER>.csv' = 'COLLECTION_UTC,DBID,GRANTEE,GRANT_TYPE,PRIVILEGE,OBJECT_OWNER,OBJECT_NAME,GRANTABLE'
    '18_session_limits.csv' = 'COLLECTION_UTC,DBID,INST_ID,RESOURCE_NAME,CURRENT_UTILIZATION,MAX_UTILIZATION,INITIAL_ALLOCATION,LIMIT_VALUE'
    '18_session_profile.csv' = 'COLLECTION_UTC,DBID,INST_ID,SESSION_TYPE,STATUS,SESSION_COUNT'
    '19_sga_pga_memory.csv' = 'COLLECTION_UTC,DBID,INST_ID,METRIC,VALUE,UNIT'
    '20_io_redo_counters.csv' = 'COLLECTION_UTC,DBID,INST_ID,STATISTIC,VALUE'
    '21_workload_start.csv' = 'COLLECTION_UTC,DBID,INST_ID,INSTANCE_NAME,STARTUP_TIME,COUNTER_NAME,COUNTER_VALUE'
    '22_workload_end.csv' = 'COLLECTION_UTC,DBID,INST_ID,INSTANCE_NAME,STARTUP_TIME,COUNTER_NAME,COUNTER_VALUE'
    '21_workload_time_model_start.csv' = 'COLLECTION_UTC,DBID,INST_ID,INSTANCE_NAME,STARTUP_TIME,STAT_NAME,VALUE_MICROSECONDS'
    '22_workload_time_model_end.csv' = 'COLLECTION_UTC,DBID,INST_ID,INSTANCE_NAME,STARTUP_TIME,STAT_NAME,VALUE_MICROSECONDS'
    '23_top_sql_metadata.csv' = 'COLLECTION_UTC,DBID,INST_ID,PARSING_SCHEMA,SQL_ID_OR_ADDRESS,HASH_VALUE,EXECUTIONS,BUFFER_GETS,DISK_READS,ELAPSED_TIME'
    '24_wait_events.csv' = 'COLLECTION_UTC,DBID,INST_ID,EVENT,WAIT_CLASS,TOTAL_WAITS,TIME_WAITED,CAPTURE_SCOPE'
    '24_system_metrics.csv' = 'COLLECTION_UTC,DBID,INST_ID,METRIC_NAME,VALUE,UNIT,INTSIZE_CSEC'
    '25_rac_inventory.csv' = 'COLLECTION_UTC,DBID,INST_ID,ITEM,VALUE'
    '26_asm_inventory.csv' = 'COLLECTION_UTC,DBID,INST_ID,NAME,STATE,TYPE,TOTAL_MB,FREE_MB,USABLE_FILE_MB,STATUS'
    '27_data_guard_inventory.csv' = 'COLLECTION_UTC,DBID,ITEM,VALUE'
    '28_growth_capacity.csv' = 'COLLECTION_UTC,DBID,OWNER,SEGMENT_TYPE,ALLOCATED_BYTES,DATAFILE_MAX_BYTES'
    '29_backup_recovery.csv' = 'COLLECTION_UTC,DBID,ITEM,VALUE'
    '29_rman_backup_jobs.csv' = 'START_TIME,END_TIME,STATUS,INPUT_TYPE,OUTPUT_BYTES,ELAPSED_SECONDS'
    '30_awr_ash_licensing_checkpoint.csv' = 'CHECKPOINT,STATUS,ACTION'
    '33_configuration_risks_<OWNER>.csv' = 'COLLECTION_UTC,DBID,OWNER,RISK_CATEGORY,EVIDENCE,COUNT_OR_VALUE'
}
$script:SumColumns = @('OBJECT_COUNT','INVALID_COUNT','ALLOCATED_BYTES','FREE_BYTES','USED_BYTES','MAX_BYTES','SOURCE_LINES','SOURCE_BYTES')
$script:GroupColumns = @('OBJECT_KIND','DATA_TYPE','CATEGORY','GRANT_TYPE','OBJECT_TYPE')
#endregion

#region Functions
function Add-ReportIssue {
    <# .SYNOPSIS Adds a deduplicated diagnostic without raw data values. #>
    [CmdletBinding()]
    [OutputType([void])]
    param([string]$Severity, [string]$Code, [string]$Source, [string]$Message)
    $Key = "$Severity|$Code|$Source|$Message"
    if ($script:IssueKeys.Add($Key)) {
        $script:Issues.Add([pscustomobject]@{Severity=$Severity; Code=$Code; Source=$Source; Message=$Message})
    }
}

function ConvertTo-HtmlText {
    <# .SYNOPSIS Encodes untrusted evidence for HTML text and attributes. #>
    [CmdletBinding()]
    [OutputType([string])]
    param([AllowNull()][object]$Value)
    if ($null -eq $Value -or [string]$Value -eq '') { return 'Unavailable' }
    return [Net.WebUtility]::HtmlEncode([string]$Value)
}

function ConvertTo-ReportNumber {
    <# .SYNOPSIS Parses invariant numeric evidence; empty is unknown, not zero. #>
    [CmdletBinding()]
    [OutputType([object])]
    param([AllowNull()][object]$Value)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return $null }
    $Number = [decimal]0
    if (-not [decimal]::TryParse(([string]$Value).Trim(), [Globalization.NumberStyles]::Float, $script:Culture, [ref]$Number)) { return $null }
    return $Number
}

function Format-ReportNumber {
    <# .SYNOPSIS Formats valid values without confusing null with zero. #>
    [CmdletBinding()]
    [OutputType([string])]
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { return 'Unavailable' }
    if ([math]::Abs([decimal]$Value) -gt 0 -and [math]::Abs([decimal]$Value) -lt 0.001) {
        return ([decimal]$Value).ToString('0.###E+0',$script:Culture)
    }
    return ([decimal]$Value).ToString('#,##0.###', $script:Culture)
}

function Get-ReportTime {
    <# .SYNOPSIS Parses the collectors' explicit UTC timestamp format. #>
    [CmdletBinding()]
    [OutputType([object])]
    param([AllowNull()][string]$Value)
    $Time = [DateTimeOffset]::MinValue
    if ([DateTimeOffset]::TryParseExact($Value, "yyyy-MM-dd'T'HH:mm:ss'Z'", $script:Culture,
        ([Globalization.DateTimeStyles]::AssumeUniversal -bor [Globalization.DateTimeStyles]::AdjustToUniversal), [ref]$Time)) { return $Time }
    return $null
}

function Get-EvidenceDefinition {
    <# .SYNOPSIS Matches only recognized collector filenames, never executable input. #>
    [CmdletBinding()]
    [OutputType([object])]
    param([string]$Name)
    foreach ($Pattern in ($script:Headers.Keys | Sort-Object)) {
        $Regex = '^' + [regex]::Escape($Pattern).Replace('<OWNER>', '[A-Z][A-Z0-9_$#]*') + '$'
        if ($Name -cmatch $Regex) { return [pscustomobject]@{Pattern=$Pattern; Header=$script:Headers[$Pattern].Split(',')} }
    }
    return $null
}

function Get-EvidenceFile {
    <# .SYNOPSIS Strictly parses CSVs and aggregates all rows while limiting detail previews. #>
    [CmdletBinding()]
    [OutputType([object])]
    param([IO.FileInfo]$File, [object]$Definition, [string]$Scope, [string]$Owner='', [string]$Window='')
    $Relative = [IO.Path]::GetRelativePath($script:Root, $File.FullName).Replace('\','/')
    $Evidence = [pscustomobject]@{
        Name=$File.Name; Relative=$Relative; FullName=$File.FullName; Scope=$Scope; Owner=$Owner; Window=$Window
        Valid=$false; RowCount=0; Rows=[Collections.Generic.List[object]]::new()
        Sums=@{}; InvalidSums=[Collections.Generic.HashSet[string]]::new()
        Groups=@{}; Dbids=[Collections.Generic.HashSet[string]]::new(); OwnerBytes=@{}
        Bytes=$File.Length; Hash=''; Header=$Definition.Header
    }
    if (($File.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        Add-ReportIssue Error LINK_NOT_READ $Relative 'Linked/reparse evidence is not read. Supply a regular local file.'
        return $Evidence
    }
    $Evidence.Hash = (Get-FileHash -LiteralPath $File.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    $Reader = $null
    $Parser = $null
    $KeepAll = $Scope -eq 'Window'
    $SegmentKeys = [Collections.Generic.HashSet[string]]::new()
    $RowKeys = [Collections.Generic.HashSet[string]]::new()
    try {
        $Reader = [IO.StreamReader]::new($File.FullName, $script:Encoding, $true)
        $Parser = [Microsoft.VisualBasic.FileIO.TextFieldParser]::new($Reader)
        $Parser.TextFieldType = [Microsoft.VisualBasic.FileIO.FieldType]::Delimited
        $Parser.SetDelimiters(',')
        $Parser.HasFieldsEnclosedInQuotes = $true
        $Parser.TrimWhiteSpace = $false
        if ($Parser.EndOfData) {
            Add-ReportIssue Error EMPTY_FILE $Relative 'The evidence file is empty.'
            return $Evidence
        }
        $Header = @($Parser.ReadFields() | ForEach-Object { $_.Trim() })
        if (($Header -join ',') -cne ($Definition.Header -join ',')) {
            Add-ReportIssue Error HEADER_MISMATCH $Relative 'CSV columns do not match the bundled collector contract.'
            return $Evidence
        }
        $Evidence.Valid = $true
        while (-not $Parser.EndOfData) {
            $Fields = $Parser.ReadFields()
            $Codes = @([regex]::Matches(($Fields -join ' '), '\b(?:ORA-\d{5}|SP2-\d{4}|TNS-\d{5})\b') | ForEach-Object { $_.Value } | Sort-Object -Unique)
            if ($Fields.Count -ne $Header.Count) {
                Add-ReportIssue Error CSV_ROW_WIDTH $Relative 'A row has missing/extra columns or contains a SQL*Plus diagnostic.'
                if ($Codes.Count) { Add-ReportIssue Error COLLECTOR_ERROR $Relative ('Recorded codes: ' + ($Codes -join ', ')) }
                $Evidence.Valid = $false
                break
            }
            $Record = [ordered]@{}
            for ($Index=0; $Index -lt $Header.Count; $Index++) { $Record[$Header[$Index]] = $Fields[$Index].Trim() }
            if ($Codes.Count) { Add-ReportIssue Warning SOURCE_UNAVAILABLE $Relative ('A structured evidence row records: ' + ($Codes -join ', ')) }
            $Evidence.RowCount++
            if ($KeepAll -and $Evidence.RowCount -gt 100000) {
                Add-ReportIssue Error COUNTER_FILE_TOO_LARGE $Relative 'More than 100,000 performance rows; the dataset is rejected rather than sampled.'
                $Evidence.Valid = $false
                break
            }
            if ($KeepAll -or $Evidence.Rows.Count -lt 100) { $Evidence.Rows.Add([pscustomobject]$Record) }
            if ($Record.Contains('DBID') -and $Record.DBID) { [void]$Evidence.Dbids.Add($Record.DBID) }
            if ($Scope -eq 'Schema' -and $Record.Contains('OWNER') -and
                $File.Name -notin @('15_database_links.csv','16_directories.csv') -and $Record.OWNER -cne $Owner) {
                Add-ReportIssue Error OWNER_MISMATCH $Relative 'A row belongs to a different owner than its scope folder.'
                $Evidence.Valid = $false
            }
            $UniqueColumns=if ($File.Name -match '^08_schema_inventory_') { @('OWNER','OBJECT_TYPE') }
                           elseif ($File.Name -match '^12_data_type_compatibility_') { @('OWNER','TABLE_NAME','COLUMN_NAME') }
                           else { @() }
            if ($UniqueColumns.Count -gt 0) {
                $RowKey=($UniqueColumns | ForEach-Object { $Value=[string]$Record[$_]; "$($Value.Length):$Value" }) -join ';'
                if (-not $RowKeys.Add($RowKey)) {
                    $Evidence.Valid=$false
                    Add-ReportIssue Error DUPLICATE_METADATA $Relative 'Duplicate rows violate the collector aggregation grain; affected summaries are withheld.'
                }
            }
            if ($File.Name -match '^11_lob_inventory_') {
                $LobKey=(@('OWNER','TABLE_NAME','COLUMN_NAME') | ForEach-Object { $Value=[string]$Record[$_]; "$($Value.Length):$Value" }) -join ';'
                $Evidence.Groups['LOB_COLUMN|'+$LobKey]=1
            }
            foreach ($Column in $script:SumColumns) {
                if (-not $Record.Contains($Column)) { continue }
                $Number = ConvertTo-ReportNumber $Record[$Column]
                if ($null -eq $Number -or $Number -lt 0) { [void]$Evidence.InvalidSums.Add($Column); continue }
                try {
                    if (-not $Evidence.Sums.ContainsKey($Column)) { $Evidence.Sums[$Column] = [decimal]0 }
                    $Evidence.Sums[$Column] += $Number
                } catch [OverflowException] {
                    [void]$Evidence.InvalidSums.Add($Column)
                    Add-ReportIssue Error NUMERIC_OVERFLOW $Relative 'A numeric aggregate exceeds the supported decimal range.'
                }
            }
            foreach ($Column in $script:GroupColumns) {
                if ($Record.Contains($Column) -and $Record[$Column]) {
                    $Key = "$Column|$($Record[$Column])"
                    if (-not $Evidence.Groups.ContainsKey($Key)) { $Evidence.Groups[$Key] = 0 }
                    $Evidence.Groups[$Key]++
                }
            }
            if ($File.Name -eq '28_growth_capacity.csv') {
                $Key = $Record.OWNER + '|' + $Record.SEGMENT_TYPE
                $Number = ConvertTo-ReportNumber $Record.ALLOCATED_BYTES
                if (-not $SegmentKeys.Add($Key) -or $null -eq $Number -or $Number -lt 0) {
                    Add-ReportIssue Error INVALID_SEGMENT_SUMMARY $Relative 'Duplicate owner/type or invalid allocation; owner storage totals are withheld.'
                    $Evidence.Valid = $false
                } else {
                    if (-not $Evidence.OwnerBytes.ContainsKey($Record.OWNER)) { $Evidence.OwnerBytes[$Record.OWNER] = [decimal]0 }
                    $Evidence.OwnerBytes[$Record.OWNER] += $Number
                }
            }
            if ($File.Name -eq '07_tablespace_capacity.csv') {
                $Allocated=ConvertTo-ReportNumber $Record.ALLOCATED_BYTES
                $Used=ConvertTo-ReportNumber $Record.USED_BYTES
                $Free=ConvertTo-ReportNumber $Record.FREE_BYTES
                if (-not $SegmentKeys.Add($Record.TABLESPACE) -or $null -eq $Allocated -or
                    $null -eq $Used -or $null -eq $Free -or $Allocated -lt 0 -or
                    $Used -lt 0 -or $Free -lt 0 -or $Used+$Free -ne $Allocated) {
                    $Evidence.Valid=$false
                    Add-ReportIssue Error INVALID_CAPACITY $Relative 'Duplicate tablespaces or inconsistent allocation/free/used values; storage totals are withheld.'
                }
            }
            if ($Record.Contains('STATUS') -and $Record.STATUS -match 'UNAVAILABLE|NO_VISIBLE|VERIFY_') {
                Add-ReportIssue Warning VISIBILITY_GAP $Relative 'Recorded feature visibility is inconclusive; it is not reported as zero usage.'
            }
        }
        if (-not $Evidence.Valid) { $Evidence.Rows.Clear() }
    } catch [Microsoft.VisualBasic.FileIO.MalformedLineException] {
        $Evidence.Valid = $false
        $Evidence.Rows.Clear()
        Add-ReportIssue Error CSV_PARSE_ERROR $Relative 'Malformed CSV quoting; values from this file are withheld.'
    } catch [Text.DecoderFallbackException] {
        $Evidence.Valid = $false
        $Evidence.Rows.Clear()
        Add-ReportIssue Error CSV_ENCODING $Relative 'Invalid source encoding. Select the correct CsvEncoding; raw evidence was not changed.'
    } finally {
        if ($null -ne $Parser) { $Parser.Dispose() }
        if ($null -ne $Reader) { $Reader.Dispose() }
    }
    return $Evidence
}

function Get-ScopeFiles {
    <# .SYNOPSIS Enumerates only known scope folders without following links. #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param()
    $Scopes = [Collections.Generic.List[object]]::new()
    $Scopes.Add([pscustomobject]@{Path=(Join-Path $script:Root 'oracle\database'); Scope='Database'; Owner=''; Window=''})
    foreach ($Kind in @('oracle\schemas','performance')) {
        $Parent = Join-Path $script:Root $Kind
        if (-not (Test-Path -LiteralPath $Parent -PathType Container)) { continue }
        $ParentItem = Get-Item -LiteralPath $Parent
        if (($ParentItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Scope directories must not be links/reparse points.' }
        foreach ($Directory in (Get-ChildItem -LiteralPath $Parent -Directory | Sort-Object Name)) {
            if (($Directory.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $Directory.Name -ieq 'internal') {
                Add-ReportIssue Error SCOPE_LINK_NOT_READ $Kind 'A linked or restricted scope folder was not read.'
                continue
            }
            if ($Kind -eq 'oracle\schemas') {
                $Scopes.Add([pscustomobject]@{Path=$Directory.FullName; Scope='Schema'; Owner=$Directory.Name; Window=''})
            } else {
                $Scopes.Add([pscustomobject]@{Path=$Directory.FullName; Scope='Window'; Owner=''; Window=$Directory.Name})
            }
        }
    }
    return $Scopes.ToArray()
}

function Get-SelectedOwner {
    <# .SYNOPSIS Reads owner selections as data, never executes the generated driver. #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param([object[]]$Scopes)
    $Owners = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $Driver = Join-Path $script:Root '_collect_schemas.sql'
    if ((Test-Path -LiteralPath $Driver -PathType Leaf) -and
        (((Get-Item -LiteralPath $Driver).Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0)) {
        foreach ($Line in [IO.File]::ReadLines($Driver)) {
            if ($Line -cmatch '^@scripts/oracle/99_collect_schema\.sql ([A-Z][A-Z0-9_$#]{0,127})\s*$') {
                if (-not $Owners.Add($Matches[1])) { Add-ReportIssue Error DUPLICATE_SCOPE '_collect_schemas.sql' 'A schema is declared more than once.' }
            } elseif ($Line.Trim() -and -not $Line.TrimStart().StartsWith('--')) {
                Add-ReportIssue Warning SCOPE_DRIVER_UNRECOGNIZED '_collect_schemas.sql' 'An unrecognized selection line was not interpreted.'
            }
        }
    }
    if ($Owners.Count -eq 0) {
        Add-ReportIssue Warning SCOPE_INFERRED '_collect_schemas.sql' 'Approved selections are unavailable; displayed owners were inferred from scope folders.'
        foreach ($Scope in $Scopes) { if ($Scope.Scope -eq 'Schema') { [void]$Owners.Add($Scope.Owner) } }
    }
    return @($Owners | Sort-Object)
}

function Get-TableEvidence {
    <# .SYNOPSIS Returns a scoped dataset or explicitly marks it unavailable. #>
    [CmdletBinding()]
    [OutputType([object])]
    param([string]$Relative)
    if ($script:Evidence.ContainsKey($Relative) -and $script:Evidence[$Relative].Valid) { return $script:Evidence[$Relative] }
    return $null
}

function Get-EvidenceSum {
    <# .SYNOPSIS Exposes an aggregate only if every contributing value was valid. #>
    [CmdletBinding()]
    [OutputType([object])]
    param([AllowNull()][object]$Evidence, [string]$Column)
    if ($null -eq $Evidence -or $Evidence.InvalidSums.Contains($Column) -or -not $Evidence.Sums.ContainsKey($Column)) { return $null }
    return $Evidence.Sums[$Column]
}

function Get-FirstRecord {
    <# .SYNOPSIS Requires a single identity record rather than choosing an arbitrary row. #>
    [CmdletBinding()]
    [OutputType([object])]
    param([string]$Relative)
    $Evidence = Get-TableEvidence $Relative
    if ($null -eq $Evidence -or $Evidence.RowCount -ne 1) {
        Add-ReportIssue Warning IDENTITY_UNAVAILABLE $Relative 'Expected one identity record; identity is unavailable or ambiguous.'
        return $null
    }
    return $Evidence.Rows[0]
}

function Get-ValidatedRate {
    <# .SYNOPSIS Validates a complete instance counter pair before calculating rates. #>
    [CmdletBinding()]
    [OutputType([object])]
    param([object[]]$Start, [object[]]$End, [string]$NameColumn, [string]$ValueColumn, [string]$Source, [string]$Dbid)
    $Result = [pscustomobject]@{Valid=$false; Rates=@{}; Deltas=@{}; Seconds=@{}; Start=''; End=''}
    if (-not $Start.Count -or -not $End.Count) {
        Add-ReportIssue Warning MISSING_PAIR $Source 'START or END rows are missing for this instance.'
        return $Result
    }
    $Identities=@(@($Start)+@($End) | ForEach-Object { "$($_.DBID)|$($_.INST_ID)|$($_.INSTANCE_NAME)|$($_.STARTUP_TIME)" } | Sort-Object -Unique)
    if ($Identities.Count -ne 1 -or $Start[0].INST_ID -notmatch '^[1-9][0-9]*$' -or
        -not $Start[0].INSTANCE_NAME -or $Start[0].STARTUP_TIME -notmatch '^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d$') {
        Add-ReportIssue Error PAIR_IDENTITY_MISMATCH $Source 'Mixed/missing instance identity or startup markers; rates are withheld.'
        return $Result
    }
    $A = @{}
    $B = @{}
    foreach ($Entry in @(@{Rows=$Start; Map=$A}, @{Rows=$End; Map=$B})) {
        foreach ($Row in $Entry.Rows) {
            $Key = [string]$Row.$NameColumn
            if (-not $Key -or $Entry.Map.ContainsKey($Key)) {
                Add-ReportIssue Error DUPLICATE_COUNTER $Source 'Counter names are missing or duplicated within an instance snapshot.'
                return $Result
            }
            $Entry.Map[$Key] = $Row
        }
    }
    if ((@($A.Keys | Sort-Object) -join "`n") -cne (@($B.Keys | Sort-Object) -join "`n")) {
        Add-ReportIssue Error COUNTER_SET_MISMATCH $Source 'START and END contain different counter sets; rates are withheld.'
        return $Result
    }
    $FirstStart = $null
    $LastEnd = $null
    foreach ($Key in $A.Keys) {
        $Left=$A[$Key]; $Right=$B[$Key]
        if (-not $Dbid -or $Left.DBID -cne $Dbid -or $Right.DBID -cne $Dbid -or
            $Left.INST_ID -cne $Right.INST_ID -or $Left.INSTANCE_NAME -cne $Right.INSTANCE_NAME -or
            $Left.STARTUP_TIME -cne $Right.STARTUP_TIME -or -not $Left.STARTUP_TIME) {
            Add-ReportIssue Error PAIR_IDENTITY_MISMATCH $Source 'DBID, instance identity or startup changed; rates are withheld.'
            return $Result
        }
        $StartTime=Get-ReportTime $Left.COLLECTION_UTC; $EndTime=Get-ReportTime $Right.COLLECTION_UTC
        $StartValue=ConvertTo-ReportNumber $Left.$ValueColumn; $EndValue=ConvertTo-ReportNumber $Right.$ValueColumn
        if ($null -eq $StartTime -or $null -eq $EndTime -or $EndTime -le $StartTime -or
            $null -eq $StartValue -or $null -eq $EndValue -or $StartValue -lt 0 -or $EndValue -lt $StartValue) {
            Add-ReportIssue Error INVALID_COUNTER_DELTA $Source 'Invalid timestamps, nonnumeric/negative counters or a reset; rates are withheld.'
            return $Result
        }
        $Seconds=[decimal]($EndTime-$StartTime).TotalSeconds
        $Delta=$EndValue-$StartValue
        $Result.Rates[$Key]=$Delta/$Seconds
        $Result.Deltas[$Key]=$Delta
        $Result.Seconds[$Key]=$Seconds
        if ($null -eq $FirstStart -or $StartTime -lt $FirstStart) { $FirstStart=$StartTime }
        if ($null -eq $LastEnd -or $EndTime -gt $LastEnd) { $LastEnd=$EndTime }
    }
    $Result.Valid=$true
    $Result.Start=$FirstStart.ToString('u')
    $Result.End=$LastEnd.ToString('u')
    return $Result
}

function Get-RateMetric {
    <# .SYNOPSIS Converts a named rate to explicitly declared chart units. #>
    [CmdletBinding()]
    [OutputType([object])]
    param([object]$Pair, [string]$Counter, [string]$Label, [decimal]$Divisor=1, [string]$Source='')
    if (-not $Pair.Valid) { return [pscustomobject]@{Label=$Label; Value=$null} }
    if (-not $Pair.Rates.ContainsKey($Counter)) {
        Add-ReportIssue Warning MISSING_COUNTER $Source ("Chart counter was not captured: "+$Counter+". That metric is unavailable.")
        return [pscustomobject]@{Label=$Label; Value=$null}
    }
    return [pscustomobject]@{Label=$Label; Value=($Pair.Rates[$Counter]/$Divisor)}
}

function ConvertTo-Chart {
    <# .SYNOPSIS Creates an accessible inline SVG; unknown metrics are never zero bars. #>
    [CmdletBinding()]
    [OutputType([string])]
    param([string]$Title, [string]$Unit, [object[]]$Metrics, [string]$Note='')
    $script:ChartId++
    $Id="chart-$($script:ChartId)"
    $Available=@($Metrics | Where-Object { $null -ne $_.Value })
    $Html=[Text.StringBuilder]::new()
    [void]$Html.Append('<section class="chart"><h4>'+(ConvertTo-HtmlText $Title)+'</h4>')
    if ($Available.Count -eq 0) {
        [void]$Html.Append('<p class="unavailable">Unavailable: no valid metrics for this chart.</p>')
    } else {
        $Maximum=[decimal]0
        foreach ($Metric in $Available) { if ($Metric.Value -gt $Maximum) { $Maximum=$Metric.Value } }
        $Domain=if ($Maximum -gt 0) { $Maximum } else { [decimal]1 }
        $Height=45+($Available.Count*42)
        [void]$Html.Append('<svg role="img" aria-labelledby="'+$Id+'" viewBox="0 0 760 '+$Height+'"><title id="'+$Id+'">'+(ConvertTo-HtmlText "$Title ($Unit)")+'</title>')
        $Y=26
        foreach ($Metric in $Available) {
            $Width=([double]($Metric.Value/$Domain*370)).ToString('0.###',$script:Culture)
            $Number=Format-ReportNumber $Metric.Value
            $ShortLabel=if ($Metric.Label.Length -gt 34) { $Metric.Label.Substring(0,31)+'...' } else { $Metric.Label }
            $ShortNumber=if ($Metric.Value -ge 1000000000) { ([decimal]$Metric.Value).ToString('0.###E+0',$script:Culture) } else { $Number }
            [void]$Html.Append('<text x="0" y="'+($Y+16)+'"><title>'+(ConvertTo-HtmlText $Metric.Label)+'</title>'+(ConvertTo-HtmlText $ShortLabel)+'</text>')
            [void]$Html.Append('<rect class="track" x="260" y="'+$Y+'" width="370" height="22"/>')
            [void]$Html.Append('<rect class="bar" x="260" y="'+$Y+'" width="'+$Width+'" height="22"><title>'+(ConvertTo-HtmlText "$($Metric.Label): $Number $Unit")+'</title></rect>')
            [void]$Html.Append('<text x="640" y="'+($Y+16)+'"><title>'+(ConvertTo-HtmlText $Number)+'</title>'+(ConvertTo-HtmlText $ShortNumber)+'</text>')
            $Y+=42
        }
        [void]$Html.Append('</svg><p class="unit">Unit: '+(ConvertTo-HtmlText $Unit)+'</p>')
        if ($Maximum -eq 0) { [void]$Html.Append('<p>All captured chart values are zero. Interpret them with their scope and instrumentation.</p>') }
    }
    foreach ($Metric in $Metrics) {
        if ($null -eq $Metric.Value) { [void]$Html.Append('<p class="unavailable">'+(ConvertTo-HtmlText $Metric.Label)+': unavailable.</p>') }
    }
    if ($Metrics.Count) {
        $DataRows=@($Metrics | ForEach-Object {
            [pscustomobject]@{Metric=$_.Label; 'Calculated value'=if ($null -eq $_.Value) { 'Unavailable' } else { ([decimal]$_.Value).ToString('G29',$script:Culture) }; Unit=$Unit}
        })
        [void]$Html.Append('<details><summary>Chart data</summary>'+(ConvertTo-ReportTable $DataRows @('Metric','Calculated value','Unit'))+'</details>')
    }
    if ($Note) { [void]$Html.Append('<p class="note">'+(ConvertTo-HtmlText $Note)+'</p>') }
    [void]$Html.Append('</section>')
    return $Html.ToString()
}

function ConvertTo-ReportTable {
    <# .SYNOPSIS Encodes a bounded detail table and identifies its full source size. #>
    [CmdletBinding()]
    [OutputType([string])]
    param([object[]]$Rows, [string[]]$Columns, [int]$Total=-1, [int]$Limit=100)
    if (-not $Rows.Count) { return '<p class="unavailable">No rows available. This is not assumed to be zero usage.</p>' }
    $Html=[Text.StringBuilder]::new()
    [void]$Html.Append('<div class="table-wrap"><table><thead><tr>')
    foreach ($Column in $Columns) { [void]$Html.Append('<th scope="col">'+(ConvertTo-HtmlText $Column)+'</th>') }
    [void]$Html.Append('</tr></thead><tbody>')
    foreach ($Row in @($Rows | Select-Object -First $Limit)) {
        [void]$Html.Append('<tr>')
        foreach ($Column in $Columns) { [void]$Html.Append('<td>'+(ConvertTo-HtmlText $Row.$Column)+'</td>') }
        [void]$Html.Append('</tr>')
    }
    [void]$Html.Append('</tbody></table></div>')
    if ($Total -gt $Limit -or $Rows.Count -gt $Limit) {
        [void]$Html.Append('<p class="note">Showing at most '+$Limit+' detail rows; full evidence remains in the source CSV.</p>')
    }
    return $Html.ToString()
}

function Get-EvidenceLink {
    <# .SYNOPSIS Builds local relative links with escaped URI path components. #>
    [CmdletBinding()]
    [OutputType([string])]
    param([string]$File)
    $Relative=[IO.Path]::GetRelativePath([IO.Path]::GetDirectoryName($script:Destination),$File).Replace('\','/')
    return './'+(($Relative.Split('/') | ForEach-Object { if ($_ -in @('.','..')) { $_ } else { [Uri]::EscapeDataString($_) } }) -join '/')
}

function Get-ContentHash {
    <# .SYNOPSIS Computes CSP hashes for static embedded CSS and JavaScript. #>
    [CmdletBinding()]
    [OutputType([string])]
    param([string]$Content)
    $Algorithm=[Security.Cryptography.SHA256]::Create()
    try { return [Convert]::ToBase64String($Algorithm.ComputeHash([Text.Encoding]::UTF8.GetBytes($Content))) }
    finally { $Algorithm.Dispose() }
}

function Invoke-OracleReport {
    <# .SYNOPSIS Validates a scoped run and atomically writes its offline report. #>
    [CmdletBinding()]
    [OutputType([int])]
    param()
    $script:Issues=[Collections.Generic.List[object]]::new()
    $script:IssueKeys=[Collections.Generic.HashSet[string]]::new()
    $script:Evidence=@{}
    $script:ChartId=0
    $RootItem=Get-Item -LiteralPath $InputPath -ErrorAction Stop
    if (-not $RootItem.PSIsContainer -or $RootItem.PSProvider.Name -ne 'FileSystem' -or
        ($RootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'InputPath must be a regular local run directory.' }
    $script:Root=$RootItem.FullName
    if (-not (Test-Path -LiteralPath (Join-Path $script:Root 'oracle') -PathType Container)) { throw 'Select ONE generated run folder containing oracle, not the package or output parent.' }
    if ((((Get-Item -LiteralPath (Join-Path $script:Root 'oracle')).Attributes) -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'The oracle scope directory must not be a link/reparse point.' }
    $script:Destination=if ($OutputPath) { [IO.Path]::GetFullPath($OutputPath) } else { Join-Path $script:Root 'oracle_report.html' }
    if ([IO.Path]::GetExtension($script:Destination) -notin @('.html','.htm')) { throw 'OutputPath must be an HTML file, never CSV evidence.' }
    if (-not (Test-Path -LiteralPath ([IO.Path]::GetDirectoryName($script:Destination)) -PathType Container)) { throw 'The output directory must already exist.' }
    if (Test-Path -LiteralPath $script:Destination) {
        $Existing=Get-Item -LiteralPath $script:Destination
        if (($Existing.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or
            -not [IO.File]::ReadAllText($Existing.FullName).Contains('name="oracle-report-generator"')) {
            throw 'The destination is linked or is not a generated Oracle report. Choose a different OutputPath.'
        }
    }
    $script:Encoding=if ($CsvEncoding -eq 'utf8') { [Text.UTF8Encoding]::new($false,$true) } else {
        [Text.Encoding]::RegisterProvider([Text.CodePagesEncodingProvider]::Instance)
        [Text.Encoding]::GetEncoding(1252)
    }
    $Contract=Join-Path (Split-Path -Parent $PSScriptRoot) 'validation\required-files.txt'
    if (-not (Test-Path -LiteralPath $Contract -PathType Leaf)) { throw 'The runbook contract scripts\validation\required-files.txt is missing. Keep the complete runbook scripts folder together.' }
    $GeneratorHash=(Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $ContractHash=(Get-FileHash -LiteralPath $Contract -Algorithm SHA256).Hash.ToLowerInvariant()
    $Scopes=@(Get-ScopeFiles)
    $Owners=@(Get-SelectedOwner $Scopes)
    $Unknown=0
    foreach ($Scope in $Scopes) {
        if ($Scope.Scope -eq 'Schema' -and $Scope.Owner -cnotin $Owners) {
            Add-ReportIssue Warning UNDECLARED_SCOPE 'oracle/schemas' 'An owner folder outside the recorded selected scope was not read.'
            continue
        }
        if (-not (Test-Path -LiteralPath $Scope.Path -PathType Container)) { continue }
        if (((Get-Item -LiteralPath $Scope.Path).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            Add-ReportIssue Error SCOPE_LINK_NOT_READ $Scope.Scope 'Linked scope was not read.'
            continue
        }
        foreach ($File in (Get-ChildItem -LiteralPath $Scope.Path -File -Filter '*.csv' | Sort-Object Name)) {
            $Definition=Get-EvidenceDefinition $File.Name
            if ($null -eq $Definition) { $Unknown++; continue }
            $Evidence=Get-EvidenceFile $File $Definition $Scope.Scope $Scope.Owner $Scope.Window
            $script:Evidence[$Evidence.Relative]=$Evidence
        }
    }
    if ($Unknown) { Add-ReportIssue Info UNKNOWN_FILES '' "$Unknown unrecognized CSV files were not read." }
    $Database=Get-FirstRecord 'oracle/database/02_database_identity.csv'
    $Dbid=if ($null -ne $Database) { [string]$Database.DBID } else { '' }
    if ($Dbid -notmatch '^[0-9]+$') {
        $Dbid=''
        Add-ReportIssue Error INVALID_DBID 'oracle/database/02_database_identity.csv' 'A numeric Oracle DBID is required to validate scope and counter pairs.'
    }
    foreach ($Evidence in $script:Evidence.Values) {
        if ($Evidence.Dbids.Count -gt 0 -and (-not $Dbid -or $Evidence.Dbids.Count -ne 1 -or -not $Evidence.Dbids.Contains($Dbid))) {
            $Evidence.Valid=$false
            $Evidence.Rows.Clear()
            Add-ReportIssue Error DBID_MISMATCH $Evidence.Relative 'Evidence DBID differs from the run identity; values are withheld.'
        }
    }
    $Precheck=Get-FirstRecord 'oracle/database/01_assessment_precheck.csv'
    $Environment=Get-FirstRecord 'oracle/database/run_environment.csv'
    $Containers=Get-TableEvidence 'oracle/database/04_cdb_pdb_inventory.csv'
    $Active=@(if ($null -ne $Containers) { $Containers.Rows | Where-Object { $_.CONTAINER_TYPE -eq 'ACTIVE' } })
    $Container=if ($Active.Count -eq 1) { $Active[0].ACTIVE_CONTAINER } else { $null }
    if ($null -eq $Container) { Add-ReportIssue Warning CONTAINER_UNAVAILABLE 'oracle/database/04_cdb_pdb_inventory.csv' 'Active container is unavailable or ambiguous.' }
    $Windows=@($Scopes | Where-Object { $_.Scope -eq 'Window' } | Select-Object -ExpandProperty Window)
    if (-not $Windows.Count) { Add-ReportIssue Warning NO_WORKLOAD_WINDOW 'performance' 'No workload window folder was collected.' }
    $Required=[Collections.Generic.HashSet[string]]::new()
    foreach ($Pattern in [IO.File]::ReadLines($Contract)) {
        if (-not $Pattern.Trim()) { continue }
        if ($Pattern -eq '99_run_complete_assessment.txt') { [void]$Required.Add($Pattern) }
        elseif ($Pattern.Contains('<OWNER>')) {
            foreach ($Owner in $Owners) { [void]$Required.Add("oracle/schemas/$Owner/"+$Pattern.Replace('<OWNER>',$Owner)) }
        } elseif ($Pattern -match '^(21_|22_|23_|24_)') {
            foreach ($Window in $Windows) { [void]$Required.Add("performance/$Window/$Pattern") }
        } elseif ($Pattern -eq '15_database_links.csv') {
            foreach ($Owner in $Owners) { [void]$Required.Add("oracle/schemas/$Owner/$Pattern") }
        } else { [void]$Required.Add("oracle/database/$Pattern") }
    }
    $Present=0
    foreach ($Relative in $Required) {
        if ($Relative.EndsWith('.txt')) {
            $Marker=Join-Path $script:Root $Relative
            if ((Test-Path -LiteralPath $Marker -PathType Leaf) -and
                (((Get-Item -LiteralPath $Marker).Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) -and
                [IO.File]::ReadAllText($Marker).Contains('ORACLE_COLLECTORS_INVOKED')) { $Present++ }
            else { Add-ReportIssue Warning INCOMPLETE_RUN $Relative 'No current full-collection marker. The report remains a partial evidence view.' }
        } elseif ($script:Evidence.ContainsKey($Relative) -and $script:Evidence[$Relative].Valid) { $Present++ }
        else { Add-ReportIssue Warning MISSING_OR_INVALID $Relative 'Required evidence is missing or invalid; it is not interpreted as zero.' }
    }
    $Body=[Text.StringBuilder]::new()
    [void]$Body.Append('<nav><a href="#overview">Overview</a><a href="#schemas">Schemas</a><a href="#storage">Storage</a><a href="#performance">Performance</a><a href="#issues">Review issues</a><a href="#evidence">Evidence</a></nav>')
    [void]$Body.Append('<section id="overview"><h2>Run overview</h2><dl>')
    $Identity=[ordered]@{'Run folder'=$RootItem.Name; 'Database / CDB'=$Database.DB_NAME; 'DBID'=$Dbid; 'Database unique name'=$Database.DB_UNIQUE_NAME; 'Identity snapshot (UTC)'=$Database.COLLECTION_UTC; 'Active container/PDB'=$Container; 'Session login'=$Precheck.SESSION_USER; 'Initial current schema'=$Environment.CURRENT_SCHEMA; 'Selected owners'=($Owners -join ', ')}
    foreach ($Key in $Identity.Keys) { [void]$Body.Append('<dt>'+(ConvertTo-HtmlText $Key)+'</dt><dd>'+(ConvertTo-HtmlText $Identity[$Key])+'</dd>') }
    [void]$Body.Append('</dl><p>Recognized evidence coverage: <strong>'+ $Present+' / '+$Required.Count+'</strong> required files valid/present. A completion marker is not proof every query passed.</p><p class="note">One report covers one run. Do not add repeated capacity inventories across runs or schemas. This is an evidence report, not a migration-readiness score or production sizing recommendation.</p>')
    foreach ($Spec in @(
        @{File='03_instance_configuration.csv'; Title='Instances and hosts at capture'; Columns=@('INST_ID','INSTANCE_NAME','HOST_NAME','VERSION','STARTUP_TIME','STATUS')},
        @{File='19_sga_pga_memory.csv'; Title='Instance memory at capture (units retained)'; Columns=@('INST_ID','METRIC','VALUE','UNIT')},
        @{File='18_session_limits.csv'; Title='Connection and resource limits'; Columns=@('INST_ID','RESOURCE_NAME','CURRENT_UTILIZATION','MAX_UTILIZATION','LIMIT_VALUE')}
    )) {
        $Table=Get-TableEvidence ('oracle/database/'+$Spec.File)
        [void]$Body.Append('<h3>'+(ConvertTo-HtmlText $Spec.Title)+'</h3>')
        [void]$Body.Append((ConvertTo-ReportTable $(if ($null -ne $Table) { $Table.Rows.ToArray() } else { @() }) $Spec.Columns $(if ($null -ne $Table) { $Table.RowCount } else { 0 })))
    }
    [void]$Body.Append('<p class="note">Instance/host figures are not summed across shared RAC hosts. Startup timestamps are Oracle-reported local times; collection timestamps ending in Z are UTC.</p></section>')
    [void]$Body.Append('<section id="schemas"><h2>Selected application schemas</h2><p class="note">Counts reflect metadata visible to the assessment account. Verify scope and privileges against DBA expectations; an empty optional detail set is not proof a feature is absent.</p>')
    $SchemaSummary=[Collections.Generic.List[object]]::new()
    $Growth=Get-TableEvidence 'oracle/database/28_growth_capacity.csv'
    foreach ($Owner in $Owners) {
        $Prefix="oracle/schemas/$Owner/"
        $Inventory=Get-TableEvidence ($Prefix+"08_schema_inventory_$Owner.csv")
        $Objects=Get-EvidenceSum $Inventory 'OBJECT_COUNT'
        $Invalid=Get-EvidenceSum $Inventory 'INVALID_COUNT'
        if ($null -eq $Objects) { Add-ReportIssue Warning SCHEMA_INVENTORY_UNAVAILABLE ($Prefix+"08_schema_inventory_$Owner.csv") 'Object counts are unavailable for a selected owner.' }
        if ($null -ne $Invalid -and $Invalid -gt 0) { Add-ReportIssue Warning INVALID_OBJECTS ($Prefix+"08_schema_inventory_$Owner.csv") 'The schema contains invalid objects requiring review.' }
        $Tables=Get-TableEvidence ($Prefix+"10_table_index_partition_$Owner.csv")
        $Types=Get-TableEvidence ($Prefix+"12_data_type_compatibility_$Owner.csv")
        $Lobs=Get-TableEvidence ($Prefix+"11_lob_inventory_$Owner.csv")
        $Storage=$null
        if ($null -ne $Growth -and $Growth.OwnerBytes.ContainsKey($Owner)) { $Storage=$Growth.OwnerBytes[$Owner]/1GB }
        $SchemaSummary.Add([pscustomobject]@{Owner=$Owner; Objects=(Format-ReportNumber $Objects); Invalid=(Format-ReportNumber $Invalid); 'Allocated GiB'=(Format-ReportNumber $Storage); 'LOB columns'=if ($null -ne $Lobs) { @($Lobs.Groups.Keys | Where-Object { $_.StartsWith('LOB_COLUMN|') }).Count } else { 'Unavailable' }})
        [void]$Body.Append('<details><summary>'+(ConvertTo-HtmlText $Owner)+' - metadata details</summary>')
        if ($null -ne $Tables) {
            $Kinds=@($Tables.Groups.Keys | Where-Object { $_.StartsWith('OBJECT_KIND|') } | Sort-Object | ForEach-Object { [pscustomobject]@{Kind=$_.Substring(12); Rows=$Tables.Groups[$_]} })
            [void]$Body.Append((ConvertTo-ReportTable $Kinds @('Kind','Rows')))
        }
        if ($null -ne $Types) {
            $TypeRows=@($Types.Groups.Keys | Where-Object { $_.StartsWith('DATA_TYPE|') } | Sort-Object | ForEach-Object { [pscustomobject]@{Type=$_.Substring(10); Columns=$Types.Groups[$_]} })
            [void]$Body.Append('<h4>Column types</h4>'+(ConvertTo-ReportTable $TypeRows @('Type','Columns')))
        }
        foreach ($Spec in @(
            @{File="13_code_object_inventory_$Owner.csv"; Title='Code metadata (no source text)'; Columns=@('NAME','TYPE','SOURCE_LINES','SOURCE_BYTES','STATIC_PATTERN_SCAN')},
            @{File="14_feature_usage_$Owner.csv"; Title='Recorded Oracle features'; Columns=@('FEATURE_GROUP','ATTRIBUTE','OBJECT_COUNT')},
            @{File="15_dependencies_$Owner.csv"; Title='Dependency metadata'; Columns=@('DIRECTION','OWNER','NAME','TYPE','REFERENCED_OWNER','REFERENCED_NAME','REFERENCED_TYPE')},
            @{File="16_jobs_queues_directories_$Owner.csv"; Title='Jobs, queues and external tables'; Columns=@('CATEGORY','OBJECT_NAME','DETAIL')},
            @{File="17_security_summary_$Owner.csv"; Title='Privilege metadata'; Columns=@('GRANTEE','GRANT_TYPE','PRIVILEGE','OBJECT_OWNER','OBJECT_NAME','GRANTABLE')},
            @{File="33_configuration_risks_$Owner.csv"; Title='Recorded review flags (not a readiness verdict)'; Columns=@('RISK_CATEGORY','EVIDENCE','COUNT_OR_VALUE')}
        )) {
            $Table=Get-TableEvidence ($Prefix+$Spec.File)
            [void]$Body.Append('<h4>'+(ConvertTo-HtmlText $Spec.Title)+'</h4>')
            [void]$Body.Append((ConvertTo-ReportTable $(if ($null -ne $Table) { $Table.Rows.ToArray() } else { @() }) $Spec.Columns $(if ($null -ne $Table) { $Table.RowCount } else { 0 })))
        }
        [void]$Body.Append('<p class="note">NUM_ROWS in table metadata is an optimizer estimate, not a row-data count. LOB columns are distinct owner/table/column keys: partition segment rows are not extra columns or added to storage totals. Features and privileges are inventory, not license entitlement or conversion certification.</p></details>')
    }
    [void]$Body.Append((ConvertTo-ReportTable $SchemaSummary.ToArray() @('Owner','Objects','Invalid','Allocated GiB','LOB columns')))
    [void]$Body.Append('</section><section id="storage"><h2>Container storage</h2><p>Tablespace figures are used once. DATAFILE_MAX_BYTES repeated in owner/type rows is never summed. MAX_BYTES is a configured datafile limit, not free disk, a growth forecast or an Azure sizing recommendation.</p>')
    $Capacity=Get-TableEvidence 'oracle/database/07_tablespace_capacity.csv'
    $StorageMetrics=@()
    foreach ($Field in @('ALLOCATED_BYTES','USED_BYTES')) {
        $Number=Get-EvidenceSum $Capacity $Field
        $StorageMetrics += [pscustomobject]@{Label=$Field.Replace('_BYTES','').ToLowerInvariant(); Value=if ($null -ne $Number) { $Number/1GB } else { $null }}
    }
    if ($null -ne $Capacity) {
        foreach ($Row in $Capacity.Rows) {
            $Allocated=ConvertTo-ReportNumber $Row.ALLOCATED_BYTES; $Used=ConvertTo-ReportNumber $Row.USED_BYTES
            if ($null -eq $Allocated -or $null -eq $Used -or $Used -lt 0 -or $Used -gt $Allocated) {
                Add-ReportIssue Error INVALID_CAPACITY $Capacity.Relative 'Inconsistent allocation/usage; the storage chart is withheld.'
                $StorageMetrics=@()
                break
            }
        }
    }
    [void]$Body.Append((ConvertTo-Chart 'Allocated and used space' 'GiB (1,073,741,824 bytes)' $StorageMetrics))
    if ($null -ne $Capacity) { [void]$Body.Append((ConvertTo-ReportTable $Capacity.Rows.ToArray() @('TABLESPACE','ALLOCATED_BYTES','FREE_BYTES','USED_BYTES','MAX_BYTES','AUTOEXTENSIBLE') $Capacity.RowCount)) }
    [void]$Body.Append('</section><section id="performance"><h2>Performance windows</h2><p class="note">START/END pairs give interval averages, not a timeline. A two-minute average cannot reveal a ten-second spike. No trend line or host CPU percentage is inferred. Rates use each pair''s actual UTC timestamps, not the requested minutes.</p><p class="note">The active PDB comes from scope evidence. Counter files do not include CON_ID; these charts are not proof of PDB-exclusive resource attribution. Preserve the execution record and do not combine duplicate instance-wide counters from separate PDB runs.</p>')
    $Cards=[Text.StringBuilder]::new()
    $InstanceOptions=[Collections.Generic.HashSet[string]]::new()
    foreach ($Window in ($Windows | Sort-Object)) {
        $Prefix="performance/$Window/"
        $Start=Get-TableEvidence ($Prefix+'21_workload_start.csv'); $End=Get-TableEvidence ($Prefix+'22_workload_end.csv')
        $TimeStart=Get-TableEvidence ($Prefix+'21_workload_time_model_start.csv'); $TimeEnd=Get-TableEvidence ($Prefix+'22_workload_time_model_end.csv')
        $InstanceIds=@(@($Start,$End,$TimeStart,$TimeEnd) | Where-Object { $null -ne $_ } | ForEach-Object { $_.Rows | ForEach-Object { $_.INST_ID } } | Sort-Object -Unique)
        if (-not $InstanceIds.Count) { Add-ReportIssue Warning EMPTY_WINDOW $Prefix 'No valid START/END instance rows are available.' }
        foreach ($Instance in $InstanceIds) {
            [void]$InstanceOptions.Add($Instance)
            $A=@(if ($null -ne $Start) { $Start.Rows | Where-Object { $_.INST_ID -ceq $Instance } })
            $B=@(if ($null -ne $End) { $End.Rows | Where-Object { $_.INST_ID -ceq $Instance } })
            $C=@(if ($null -ne $TimeStart) { $TimeStart.Rows | Where-Object { $_.INST_ID -ceq $Instance } })
            $D=@(if ($null -ne $TimeEnd) { $TimeEnd.Rows | Where-Object { $_.INST_ID -ceq $Instance } })
            $Pair=Get-ValidatedRate $A $B 'COUNTER_NAME' 'COUNTER_VALUE' ($Prefix+"instance-$Instance SYSSTAT") $Dbid
            $TimePair=Get-ValidatedRate $C $D 'STAT_NAME' 'VALUE_MICROSECONDS' ($Prefix+"instance-$Instance time-model") $Dbid
            if (-not $Pair.Valid) { $TimePair.Valid=$false }
            if ($Pair.Valid -and $TimePair.Valid) {
                $Identities=@(@($A)+@($B)+@($C)+@($D) | ForEach-Object { "$($_.DBID)|$($_.INST_ID)|$($_.INSTANCE_NAME)|$($_.STARTUP_TIME)" } | Sort-Object -Unique)
                if ($Identities.Count -ne 1 -or
                    [DateTimeOffset]::Parse($TimePair.End,$script:Culture) -le [DateTimeOffset]::Parse($Pair.Start,$script:Culture) -or
                    [DateTimeOffset]::Parse($TimePair.Start,$script:Culture) -ge [DateTimeOffset]::Parse($Pair.End,$script:Culture)) {
                    $TimePair.Valid=$false
                    Add-ReportIssue Error TIME_MODEL_WINDOW_MISMATCH $Prefix 'Time-model identity/window does not overlap its SYSSTAT pair; CPU metrics are withheld.'
                }
            }
            [void]$Cards.Append('<article class="window-card" data-window="'+(ConvertTo-HtmlText $Window)+'" data-instance="'+(ConvertTo-HtmlText $Instance)+'"><h3>'+(ConvertTo-HtmlText "$Window - instance $Instance")+'</h3>')
            if ($Pair.Valid) {
                $Durations=@($Pair.Seconds.Values | Sort-Object -Unique | ForEach-Object { Format-ReportNumber $_ })
                [void]$Cards.Append('<p class="interval">UTC '+(ConvertTo-HtmlText $Pair.Start)+' to '+(ConvertTo-HtmlText $Pair.End)+'; actual counter intervals: '+(ConvertTo-HtmlText ($Durations -join ', '))+' seconds.</p>')
            } else { [void]$Cards.Append('<p class="unavailable">Invalid or incomplete counter pair. SYSSTAT rates are withheld.</p>') }
            [void]$Cards.Append('<div class="chart-grid">')
            foreach ($Spec in @(
                @{Title='Storage throughput'; Unit='MiB/s'; Divisor=[decimal]1MB; Counters=[ordered]@{'physical read total bytes'='Read';'physical write total bytes'='Write'}},
                @{Title='Storage operations'; Unit='I/O requests/s'; Divisor=[decimal]1; Counters=[ordered]@{'physical read total IO requests'='Read';'physical write total IO requests'='Write'}},
                @{Title='Redo generation'; Unit='MiB/s'; Divisor=[decimal]1MB; Counters=[ordered]@{'redo size'='Redo'}},
                @{Title='Database activity'; Unit='operations/s'; Divisor=[decimal]1; Counters=[ordered]@{'execute count'='Executions';'user commits'='Commits';'user rollbacks'='Rollbacks';'session logical reads'='Logical reads'}}
            )) {
                $Metrics=@(foreach ($Counter in $Spec.Counters.Keys) { Get-RateMetric $Pair $Counter $Spec.Counters[$Counter] $Spec.Divisor $Prefix })
                [void]$Cards.Append((ConvertTo-Chart $Spec.Title $Spec.Unit $Metrics))
            }
            $Cpu=@((Get-RateMetric $TimePair 'DB time' 'DB time (total)' 1000000 $Prefix),(Get-RateMetric $TimePair 'DB CPU' 'DB CPU (component)' 1000000 $Prefix))
            if ($null -ne $Cpu[0].Value -and $null -ne $Cpu[1].Value -and $Cpu[1].Value -gt $Cpu[0].Value) {
                Add-ReportIssue Warning INCONSISTENT_TIME_MODEL $Prefix 'DB CPU exceeds DB time; CPU/time-model chart is withheld.'
                $Cpu=@()
            }
            [void]$Cards.Append((ConvertTo-Chart 'Database CPU and DB time' 'seconds per elapsed second' $Cpu 'DB CPU is part of DB time: bars are not additive. This is database activity, not total server CPU utilization.'))
            [void]$Cards.Append('</div>')
            $Waits=Get-TableEvidence ($Prefix+'24_wait_events.csv')
            $WaitMetrics=[Collections.Generic.List[object]]::new()
            if ($null -ne $Waits) {
                foreach ($Row in @($Waits.Rows | Where-Object { $_.INST_ID -ceq $Instance })) {
                    $Value=ConvertTo-ReportNumber $Row.TIME_WAITED
                    if (-not $Row.EVENT -or $Row.CAPTURE_SCOPE -cne 'CUMULATIVE_SINCE_STARTUP' -or $null -eq $Value -or $Value -lt 0) {
                        Add-ReportIssue Warning INVALID_WAIT_SCOPE $Waits.Relative 'Wait scope/value is unavailable; that row is not charted.'
                        continue
                    }
                    $WaitMetrics.Add([pscustomobject]@{Label=$Row.EVENT; Value=($Value/100)})
                }
            }
            $TopWaits=@($WaitMetrics | Sort-Object Value -Descending | Select-Object -First 8)
            [void]$Cards.Append((ConvertTo-Chart 'Top waits - cumulative since instance startup' 'seconds (TIME_WAITED / 100)' $TopWaits 'Not the selected workload interval. A single cumulative wait snapshot cannot provide interval wait rates.'))
            $Top=Get-TableEvidence ($Prefix+'23_top_sql_metadata.csv')
            $SqlMetrics=@(if ($null -ne $Top) {
                foreach ($Row in @($Top.Rows | Where-Object { $_.INST_ID -ceq $Instance })) {
                    $Value=ConvertTo-ReportNumber $Row.BUFFER_GETS
                    if ($Row.SQL_ID_OR_ADDRESS -and $null -ne $Value -and $Value -ge 0) { [pscustomobject]@{Label=$Row.SQL_ID_OR_ADDRESS; Value=$Value} }
                    else { Add-ReportIssue Warning INVALID_SQL_METRIC $Top.Relative 'Cached-SQL identity or buffer-get count is unavailable; that row is not charted.' }
                }
            })
            [void]$Cards.Append((ConvertTo-Chart 'Top cached SQL at capture' 'cumulative buffer gets' @($SqlMetrics | Sort-Object Value -Descending | Select-Object -First 8) 'Counters accumulate while cursors are cached, not necessarily since startup. Not interval-only SQL or SQL text; aged-out cursors are absent.'))
            [void]$Cards.Append('<p class="note">24_system_metrics.csv contains Oracle''s own short rolling windows, not the entire selected interval. See its source evidence rather than treating it as a time series.</p></article>')
        }
    }
    [void]$Body.Append('<div class="filters"><label>Window <select id="window-filter"><option value="">All windows</option>')
    foreach ($Window in ($Windows | Sort-Object)) { [void]$Body.Append('<option value="'+(ConvertTo-HtmlText $Window)+'">'+(ConvertTo-HtmlText $Window)+'</option>') }
    [void]$Body.Append('</select></label><label>Instance <select id="instance-filter"><option value="">All instances</option>')
    foreach ($Instance in ($InstanceOptions | Sort-Object)) { [void]$Body.Append('<option value="'+(ConvertTo-HtmlText $Instance)+'">'+(ConvertTo-HtmlText $Instance)+'</option>') }
    [void]$Body.Append('</select></label></div>')
    if ($Cards.Length) { [void]$Body.Append($Cards.ToString()) } else { [void]$Body.Append('<p class="unavailable">No chartable workload instance was collected.</p>') }
    [void]$Body.Append('</section><section id="issues"><h2>Review issues and evidence gaps</h2>')
    $IssueRows=@($script:Issues | Sort-Object @{Expression={switch ($_.Severity) {'Error' {0} 'Warning' {1} default {2}}}},Code,Source,Message)
    if ($IssueRows.Count) { [void]$Body.Append((ConvertTo-ReportTable $IssueRows @('Severity','Code','Source','Message') $IssueRows.Count ([int]::MaxValue))) }
    else { [void]$Body.Append('<p>No missing/invalid evidence was detected by these checks. This is not a database health, licensing or migration certification.</p>') }
    [void]$Body.Append('</section><section id="evidence"><h2>Source evidence and lineage</h2><p>CSV files remain authoritative and unchanged. Links are local; keep this report with its run folder. Whitespace padding is normalized for display. Only known collector fields are interpreted; credentials, source code and arbitrary unknown CSVs are not loaded.</p><div class="table-wrap"><table><thead><tr><th>Source CSV</th><th>Status</th><th>Rows</th><th>Bytes</th><th>SHA-256</th></tr></thead><tbody>')
    foreach ($Evidence in ($script:Evidence.Values | Sort-Object Relative)) {
        $SourceLabel=ConvertTo-HtmlText $Evidence.Relative
        if ($Evidence.Hash) { $SourceLabel='<a href="'+(ConvertTo-HtmlText (Get-EvidenceLink $Evidence.FullName))+'">'+$SourceLabel+'</a>' }
        [void]$Body.Append('<tr><td>'+$SourceLabel+'</td><td>'+$(if ($Evidence.Valid) {'Parsed'} else {'Invalid / withheld'})+'</td><td>'+$Evidence.RowCount+'</td><td>'+$Evidence.Bytes+'</td><td class="hash">'+(ConvertTo-HtmlText $Evidence.Hash)+'</td></tr>')
    }
    [void]$Body.Append('</tbody></table></div></section>')
    $Review=@($script:Issues | Where-Object { $_.Severity -in @('Error','Warning') }).Count -gt 0
    $Status=if ($Review) { 'REVIEW REQUIRED - see findings and evidence gaps' } else { 'Evidence checks complete - interpretation still required' }
    $Css=@'
:root{font-family:"Segoe UI",Arial,sans-serif;color:#173047;background:#eef3f8}*{box-sizing:border-box}body{margin:0}header{background:#12324d;color:white;padding:2rem max(1rem,calc((100vw - 1200px)/2))}h1{margin:.2rem 0}main{max-width:1240px;margin:auto;padding:1rem}nav{display:flex;flex-wrap:wrap;gap:1rem;padding:1rem;background:white;border-radius:8px}a{color:#086492}header p{max-width:75ch}section,article,details{margin:1rem 0}main>section{padding:1.3rem;background:white;border-radius:10px;border:1px solid #d6e0e9}h2{border-bottom:2px solid #dbe6ef;padding-bottom:.5rem}dl{display:grid;grid-template-columns:minmax(160px,230px) 1fr;gap:.45rem}dt{font-weight:650}dd{margin:0;overflow-wrap:anywhere}.note,.unit{color:#4d6275;font-size:.92rem}.unavailable{color:#874800;background:#fff3dc;padding:.7rem;border-radius:5px}.banner{padding:.8rem;border:1px solid #ffc861;background:#fff1d2;color:#583900}.ok{background:#dff4e7;border-color:#76c096;color:#153f29}.table-wrap{overflow:auto;max-height:34rem}table{border-collapse:collapse;width:100%;font-size:.9rem}th,td{text-align:left;vertical-align:top;padding:.55rem;border-bottom:1px solid #dbe3eb;overflow-wrap:anywhere}th{position:sticky;top:0;background:#e9f1f8}tr:nth-child(even){background:#f8fafc}.hash{font-family:monospace;font-size:.75rem;min-width:12rem}summary{cursor:pointer;font-weight:650;padding:.65rem;background:#edf4fa}details[open]{border:1px solid #d5e1ec;padding:.5rem}.chart-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(360px,1fr));gap:1rem}.chart{border:1px solid #dbe5ed;border-radius:8px;padding:.8rem;min-width:0}.chart h4{margin:.2rem 0 .7rem}.chart svg{width:100%;height:auto}.chart text{font:13px "Segoe UI",Arial,sans-serif;fill:#173047}.bar{fill:#12829a}.track{fill:#e9f0f5}.window-card{border:2px solid #c9dce9;padding:1rem;border-radius:8px}.interval{font-weight:600}.filters{display:flex;gap:1rem;flex-wrap:wrap}select{font:inherit;padding:.45rem;margin-left:.4rem}footer{padding:1rem;color:#52687c;font-size:.85rem}[hidden]{display:none!important}@media(max-width:600px){dl{grid-template-columns:1fr}dd{margin-bottom:.5rem}.chart-grid{grid-template-columns:1fr}}@media print{body{background:white}header{background:white;color:black;padding:1rem}main{padding:0}nav,.filters{display:none}.table-wrap{max-height:none;overflow:visible}section,article,.chart{break-inside:avoid}a{color:inherit}}
'@
    $Css += "`n.chart text{font-size:17px}@media(max-width:600px){.chart{overflow-x:auto}.chart svg{min-width:680px}}@media print{.chart svg{min-width:0}}"
    $Js=@'
const windowFilter=document.getElementById('window-filter');
const instanceFilter=document.getElementById('instance-filter');
function filterWindows(){
  for(const card of document.querySelectorAll('.window-card')){
    card.hidden=Boolean((windowFilter.value&&card.dataset.window!==windowFilter.value)||
      (instanceFilter.value&&card.dataset.instance!==instanceFilter.value));
  }
}
windowFilter.addEventListener('change',filterWindows);
instanceFilter.addEventListener('change',filterWindows);
'@
    # Browsers normalize inline line endings before evaluating CSP hashes.
    $Css=$Css.Replace("`r`n","`n").Replace("`r","`n")
    $Js=$Js.Replace("`r`n","`n").Replace("`r","`n")
    $Csp="default-src 'none'; style-src 'sha256-$(Get-ContentHash $Css)'; script-src 'sha256-$(Get-ContentHash $Js)'; base-uri 'none'; form-action 'none'"
    $Html='<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="oracle-report-generator" content="'+$script:Version+'"><meta http-equiv="Content-Security-Policy" content="'+(ConvertTo-HtmlText $Csp)+'"><title>Oracle assessment - '+(ConvertTo-HtmlText $RootItem.Name)+'</title><style>'+$Css+'</style></head><body><header><p>OFFLINE ORACLE ASSESSMENT EVIDENCE</p><h1>Oracle assessment report</h1><p>'+(ConvertTo-HtmlText $RootItem.Name)+'</p><p class="banner '+$(if (-not $Review) {'ok'} else {''})+'">'+(ConvertTo-HtmlText $Status)+'</p></header><main>'+$Body.ToString()+'</main><footer>Generator '+$script:Version+' | PowerShell '+$PSVersionTable.PSVersion.ToString()+' | CSV encoding '+(ConvertTo-HtmlText $CsvEncoding)+'<p class="hash">Generator SHA-256: '+$GeneratorHash+'<br>Contract SHA-256: '+$ContractHash+'</p>No live database queries, AI scoring, external libraries or network calls. Treat this report as sensitive metadata.</footer><script>'+$Js+'</script></body></html>'
    $Temporary=Join-Path ([IO.Path]::GetDirectoryName($script:Destination)) ('.oracle-report-'+[guid]::NewGuid().ToString('N')+'.tmp')
    try {
        [IO.File]::WriteAllText($Temporary,$Html,[Text.UTF8Encoding]::new($false))
        [IO.File]::Move($Temporary,$script:Destination,$true)
    } finally {
        if (Test-Path -LiteralPath $Temporary -PathType Leaf) { Remove-Item -LiteralPath $Temporary -Force }
    }
    Write-Host ('Report written: '+$script:Destination)
    Write-Host ('Evidence status: '+$Status)
    Write-Host ("Recognized CSVs: $($script:Evidence.Count); required coverage: $Present/$($Required.Count); issues: $($script:Issues.Count).")
    if ($Review) { return 2 }
    return 0
}
#endregion

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {
    try {
        exit (Invoke-OracleReport)
    } catch {
        Write-Error -ErrorAction Continue ('Oracle report generation failed: '+$_.Exception.Message)
        exit 1
    }
}
#endregion
