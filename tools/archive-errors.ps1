# Archive the current errors.log into the fix history, then empty it.
# Run after fixing the errors Claude found, so the live log only ever holds
# problems that are still outstanding.
#
#   powershell -ExecutionPolicy Bypass -File tools\archive-errors.ps1 -Note "what was fixed"

param(
    [string]$Note = ''
)

$ErrorActionPreference = 'Stop'

$ProjectDir = Split-Path -Parent $PSScriptRoot
$LogDir     = Join-Path $ProjectDir 'logs'
$ErrorsLog  = Join-Path $LogDir 'errors.log'
$FixLog     = Join-Path $LogDir 'fixed-history.log'

if (-not (Test-Path $ErrorsLog)) {
    Write-Host "No errors.log to archive."
    exit 0
}

$content = @(Get-Content $ErrorsLog | Where-Object { $_.Trim() -ne '' })
if ($content.Count -eq 0) {
    Write-Host "errors.log is already empty."
    exit 0
}

$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$entry = @(
    "########################################################",
    "# RESOLVED $stamp",
    "# fix: $(if ($Note) { $Note } else { '(no note given)' })",
    "########################################################",
    ""
) + $content + @('')

Add-Content -Path $FixLog -Value $entry -Encoding utf8
Set-Content -Path $ErrorsLog -Value '' -Encoding utf8

Write-Host "Archived $($content.Count) line(s) to logs\fixed-history.log and cleared errors.log." -ForegroundColor Green
