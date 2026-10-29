param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,
    [string]$RequiredFilesPath = (Join-Path $PSScriptRoot 'required-files.txt')
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $InputPath).Path
$issues = [System.Collections.Generic.List[string]]::new()
$results = [System.Collections.Generic.List[object]]::new()
$secretPatterns = [ordered]@{
    Password = '(?i)\b(password|passwd|pwd)\b\s*[:=]\s*["'']?[^,;''"\s]+'
    ApiKey = '(?i)\b(api[_-]?key|client[_-]?secret|access[_-]?token)\b\s*[:=]\s*["'']?[^,;''"\s]+'
    ConnectionSecret = '(?i)(password|pwd)=[^;\s]+'
}

foreach ($relative in Get-Content -LiteralPath $RequiredFilesPath) {
    $relative = $relative.Trim()
    if (-not $relative) { continue }
    if (Test-Path -LiteralPath (Join-Path $root $relative) -PathType Leaf) {
        continue
    }
    $filePattern = (Split-Path -Leaf $relative).Replace('<OWNER>', '*')
    $found = Get-ChildItem -LiteralPath $root -File -Recurse -Filter $filePattern |
        Select-Object -First 1
    if (-not $found) {
        $issues.Add("MISSING_REQUIRED_FILE:$relative")
    }
}

Get-ChildItem -LiteralPath $root -File -Recurse |
    Where-Object { $_.Name -ne 'validation_summary.csv' } |
    ForEach-Object {
        $file = $_
        $relative = [IO.Path]::GetRelativePath($root, $file.FullName)
        $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        $results.Add([pscustomobject]@{
            File = $relative
            Bytes = $file.Length
            SHA256 = $hash
            Status = 'OK'
        })
        if ($file.Length -eq 0) { $issues.Add("ZERO_BYTE_FILE:$relative") }
        if ($file.Extension -in @('.csv', '.txt', '.log', '.sql', '.md', '.json')) {
            $lineNumber = 0
            foreach ($line in [IO.File]::ReadLines($file.FullName)) {
                $lineNumber++
                if ($line -match '(?i)\b(ORA-\d{5}|SP2-\d{4}|TNS-\d{5})\b') {
                    $issues.Add("ORACLE_ERROR_MARKER:$relative`:$lineNumber")
                }
                foreach ($entry in $secretPatterns.GetEnumerator()) {
                    if ($line -match $entry.Value) {
                        $issues.Add("SECRET_PATTERN_$($entry.Key):$relative`:$lineNumber")
                    }
                }
            }
        }
    }

$summary = Join-Path $root 'validation_summary.csv'
$results | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $summary
if ($issues.Count -gt 0) {
    $issues | ForEach-Object { Write-Output "ISSUE=$_"}
    Write-Output "Validation failed with $($issues.Count) issue(s). No content values were printed."
    exit 1
}
Write-Output "Validation passed for $($results.Count) files. Hashes: $summary"
