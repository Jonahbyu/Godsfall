# Godsfall launcher
# Runs the game via the Godot console build so stdout/stderr can be captured,
# writes a full session log, and extracts errors/warnings into errors.log
# for Claude to read.

$ErrorActionPreference = 'Stop'

$ProjectDir = Split-Path -Parent $PSScriptRoot
$LogDir     = Join-Path $ProjectDir 'logs'
$HistoryDir = Join-Path $LogDir 'history'
$ErrorsLog  = Join-Path $LogDir 'errors.log'

# Locate the Godot *console* build -- the GUI build detaches from the console
# and produces no capturable stdout/stderr, so error logging depends on this one.
$GodotOverride = Join-Path $PSScriptRoot 'godot-path.txt'
$Godot = $null

if (Test-Path $GodotOverride) {
    $candidate = (Get-Content $GodotOverride -Raw).Trim()
    if ($candidate -and (Test-Path $candidate -PathType Leaf)) { $Godot = $candidate }
}

if (-not $Godot) {
    $searchRoots = @(
        (Join-Path $env:USERPROFILE 'Downloads'),
        (Join-Path $env:LOCALAPPDATA 'Programs'),
        'C:\Program Files',
        'C:\Program Files (x86)'
    ) | Where-Object { Test-Path $_ }

    foreach ($root in $searchRoots) {
        $hit = Get-ChildItem -Path $root -Filter 'Godot*console.exe' -Recurse -File `
                   -Depth 3 -ErrorAction SilentlyContinue |
               Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($hit) { $Godot = $hit.FullName; break }
    }
}

if (-not $Godot) {
    # This is the one failure that must be visible: the game never appears, so a
    # silent exit would look like the shortcut is simply broken. There is no
    # console to print to, hence the message box.
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(
        "Could not find a Godot console build (Godot*console.exe).`n`n" +
        "Put the full path to it in:`n$GodotOverride",
        "Godsfall", 'OK', 'Error') | Out-Null
    exit 1
}

foreach ($d in @($LogDir, $HistoryDir)) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

$Stamp      = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$SessionLog = Join-Path $HistoryDir "session_$Stamp.log"


# Run Godot, capturing both streams to temp files. Native stderr is redirected
# at the process level (not via PowerShell 2>&1) to avoid NativeCommandError
# wrapping in PS 5.1.
#
# Nothing is echoed anywhere: this script runs with no console attached, so the
# only output that matters is what lands in the log files below.
$OutFile = Join-Path $env:TEMP "godsfall_out_$Stamp.txt"
$ErrFile = Join-Path $env:TEMP "godsfall_err_$Stamp.txt"

$proc = Start-Process -FilePath $Godot `
    -ArgumentList @('--path', $ProjectDir) `
    -RedirectStandardOutput $OutFile `
    -RedirectStandardError  $ErrFile `
    -NoNewWindow -PassThru

$proc.WaitForExit()
# Re-read the process handle: .ExitCode can come back empty on a killed process
# unless the object is refreshed.
$proc.Refresh()
$ExitCode = $proc.ExitCode
if ($null -eq $ExitCode) { $ExitCode = -1 }

# Assemble the full session log.
$header = @(
    "=== Godsfall session $Stamp ===",
    "exit code : $ExitCode",
    "godot     : $Godot",
    "project   : $ProjectDir",
    ""
)
$stdout = if (Test-Path $OutFile) { @(Get-Content $OutFile -ErrorAction SilentlyContinue) } else { @() }
$stderr = if (Test-Path $ErrFile) { @(Get-Content $ErrFile -ErrorAction SilentlyContinue) } else { @() }

$body = @()
if ($stdout.Count) { $body += '--- stdout ---'; $body += $stdout; $body += '' }
if ($stderr.Count) { $body += '--- stderr ---'; $body += $stderr; $body += '' }

($header + $body) | Out-File -FilePath $SessionLog -Encoding utf8

Remove-Item $OutFile, $ErrFile -Force -ErrorAction SilentlyContinue

# Extract problems. Godot reports script errors on stderr and via
# "SCRIPT ERROR" / "ERROR:" / "WARNING:" prefixes on stdout.
$all = $stdout + $stderr
$problemPattern = 'SCRIPT ERROR|^ERROR:|^WARNING:|^USER ERROR|^USER WARNING|Parse Error|Invalid call|Cannot call method|Nonexistent function|Attempt to call|null instance|Condition ".*" is (true|false)|Failed to load|res:\/\/.*\.gd:\d+'

$problems = @()
for ($i = 0; $i -lt $all.Count; $i++) {
    if ($all[$i] -match $problemPattern) {
        $problems += $all[$i]
        # Godot puts the "at: ..." source location on the following line.
        if ($i + 1 -lt $all.Count -and $all[$i + 1] -match '^\s+at:') {
            $problems += $all[$i + 1]
            $i++
        }
    }
}

# A crash is only worth logging if Godot actually said something. Closing the
# window (or killing the process) yields a nonzero exit with no error output,
# which is not a bug worth recording.
$crashed = ($ExitCode -gt 0 -and $ExitCode -ne 255)

if ($problems.Count -gt 0 -or ($crashed -and $stderr.Count -gt 0)) {
    $entry = @(
        "=== $Stamp (exit $ExitCode) ===",
        "session log: logs/history/session_$Stamp.log",
        ""
    ) + $problems + @('')
    Add-Content -Path $ErrorsLog -Value $entry -Encoding utf8
}
