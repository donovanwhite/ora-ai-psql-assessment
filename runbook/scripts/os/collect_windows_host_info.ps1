#requires -Version 5.1
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$OutputDirectory,
    [ValidateRange(1, 300)]
    [int]$SampleCount = 5,
    [ValidateRange(1, 300)]
    [int]$SampleIntervalSeconds = 1
)

$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') {
    throw 'This collector requires Windows.'
}
$null = New-Item -ItemType Directory -Path $OutputDirectory -Force
$statusPath = Join-Path $OutputDirectory 'host_collection_status.txt'
$timer = [Diagnostics.Stopwatch]::StartNew()
$failures = 0
$skipped = 0
$status = [System.Collections.Generic.List[string]]::new()
$status.Add("COLLECTION_UTC=$([DateTime]::UtcNow.ToString('s'))Z")
$status.Add("HOST=$env:COMPUTERNAME")
$status.Add("POWERSHELL_VERSION=$($PSVersionTable.PSVersion)")
$status.Add("SAMPLE_COUNT=$SampleCount")
$status.Add("SAMPLE_INTERVAL_SECONDS=$SampleIntervalSeconds")
$status.Add('SAMPLING_MODE=PERFORMANCE_COUNTERS_TOGETHER_AFTER_INVENTORY')

function Export-OptionalCsv {
    param([string]$Name, [string[]]$Commands, [scriptblock]$Query)
    $status.Add("COMMAND_START_UTC=$Name,$([DateTime]::UtcNow.ToString('o'))")
    try {
        foreach ($command in $Commands) {
            if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
                $status.Add("SKIPPED=$Name;REASON=COMMAND_UNAVAILABLE:$command")
                $script:skipped++
                return
            }
        }
        $rows = @(& $Query)
        if ($rows.Count -eq 0) {
            $status.Add("SKIPPED=$Name;REASON=NO_VISIBLE_ROWS_VERIFY_APPLICABILITY")
            $script:skipped++
            return
        }
        $rows | Export-Csv -NoTypeInformation -Encoding UTF8 `
            -LiteralPath (Join-Path $OutputDirectory $Name)
        $status.Add("CAPTURED=$Name")
        $status.Add("ROW_COUNT=$Name,$($rows.Count)")
    }
    catch {
        $message = $_.Exception.Message -replace '[\r\n]+', ' '
        $status.Add("FAILED=$Name;REASON=$($_.FullyQualifiedErrorId);MESSAGE=$message")
        $script:failures++
    }
    finally {
        $status.Add("COMMAND_END_UTC=$Name,$([DateTime]::UtcNow.ToString('o'))")
    }
}

Export-OptionalCsv 'os_and_memory.csv' @('Get-CimInstance') {
    $os = Get-CimInstance Win32_OperatingSystem
    $computer = Get-CimInstance Win32_ComputerSystem
    [pscustomobject]@{
        Caption = $os.Caption
        Version = $os.Version
        BuildNumber = $os.BuildNumber
        LastBootUpTimeUtc = $os.LastBootUpTime.ToUniversalTime().ToString('o')
        TotalVisibleMemoryBytes = $os.TotalVisibleMemorySize * 1KB
        FreePhysicalMemoryBytes = $os.FreePhysicalMemory * 1KB
        TotalVirtualMemoryBytes = $os.TotalVirtualMemorySize * 1KB
        Manufacturer = $computer.Manufacturer
        Model = $computer.Model
        NumberOfProcessors = $computer.NumberOfProcessors
        NumberOfLogicalProcessors = $computer.NumberOfLogicalProcessors
    }
}
Export-OptionalCsv 'cpu_inventory.csv' @('Get-CimInstance') {
    Get-CimInstance Win32_Processor | Select-Object DeviceID, Name, Manufacturer,
        NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed
}
Export-OptionalCsv 'disk_layout.csv' @('Get-Disk') {
    Get-Disk | Select-Object Number, FriendlyName, BusType, PartitionStyle,
        @{Name = 'OperationalStatus'; Expression = { $_.OperationalStatus -join ';' }},
        HealthStatus, Size
}
Export-OptionalCsv 'volume_capacity.csv' @('Get-Volume') {
    Get-Volume | Select-Object DriveLetter, FileSystemLabel, FileSystem,
        HealthStatus, Size, SizeRemaining
}
Export-OptionalCsv 'pagefile_usage.csv' @('Get-CimInstance') {
    Get-CimInstance Win32_PageFileUsage | Select-Object Name, AllocatedBaseSize,
        CurrentUsage, PeakUsage
}
Export-OptionalCsv 'network_interfaces.csv' @('Get-NetAdapter') {
    Get-NetAdapter | Select-Object Name, InterfaceDescription, Status, LinkSpeed
}
Export-OptionalCsv 'numa_inventory.csv' @('Get-CimInstance') {
    Get-CimInstance Win32_PerfFormattedData_PerfOS_NUMANodeMemory |
        Where-Object { $_.Name -ne '_Total' } |
        Select-Object Name, TotalMBytes, AvailableMBytes
}

Export-OptionalCsv 'performance_samples.csv' @('Get-Counter') {
    $counterPaths = @(
        '\Processor(_Total)\% Processor Time',
        '\Memory\Available MBytes',
        '\PhysicalDisk(_Total)\Disk Read Bytes/sec',
        '\PhysicalDisk(_Total)\Disk Write Bytes/sec',
        '\PhysicalDisk(_Total)\Disk Reads/sec',
        '\PhysicalDisk(_Total)\Disk Writes/sec',
        '\PhysicalDisk(_Total)\Avg. Disk sec/Read',
        '\PhysicalDisk(_Total)\Avg. Disk sec/Write',
        '\PhysicalDisk(_Total)\Current Disk Queue Length'
    )
    $samples = @(Get-Counter -Counter $counterPaths -SampleInterval $SampleIntervalSeconds `
        -MaxSamples $SampleCount)
    if ($samples.Count -ne $SampleCount) {
        throw "Expected $SampleCount performance sample sets; received $($samples.Count)."
    }
    for ($index = 0; $index -lt $samples.Count; $index++) {
        $counters = @($samples[$index].CounterSamples)
        if ($counters.Count -ne $counterPaths.Count -or
            @($counters.Path | Sort-Object -Unique).Count -ne $counterPaths.Count) {
            throw "Performance sample set $($index + 1) has missing or duplicate counters."
        }
        foreach ($counter in $counters) {
            if ($counter.Status -notin @(0, 1) -or
                [double]::IsNaN($counter.CookedValue) -or
                [double]::IsInfinity($counter.CookedValue)) {
                throw "Invalid performance counter sample: $($counter.Path); status=$($counter.Status)."
            }
            [pscustomobject]@{
                SampleNumber = $index + 1
                TimestampUtc = $counter.Timestamp.ToUniversalTime().ToString('o')
                Path = $counter.Path
                CookedValue = ([double]$counter.CookedValue).ToString('R', [Globalization.CultureInfo]::InvariantCulture)
                CounterStatus = $counter.Status
            }
        }
    }
}

$timer.Stop()
$status.Add("COLLECTION_END_UTC=$([DateTime]::UtcNow.ToString('o'))")
$status.Add("ELAPSED_SECONDS=$([math]::Round($timer.Elapsed.TotalSeconds, 3).ToString([Globalization.CultureInfo]::InvariantCulture))")
$status.Add("FAILED_COUNT=$failures")
$status.Add("SKIPPED_COUNT=$skipped")
if ($failures -gt 0) {
    $status.Add('STATUS=PARTIAL_FAILURE')
}
else {
    $status.Add('STATUS=COMPLETE_WITH_REVIEW')
}
$status | Set-Content -Encoding UTF8 -LiteralPath $statusPath
if ($failures -gt 0) {
    [Console]::Error.WriteLine("ERROR: $failures collection query/queries failed; review $statusPath.")
    exit 1
}
Write-Output "Host evidence written to $OutputDirectory"
Write-Output 'Review host_collection_status.txt; redact host/network details before sharing.'
