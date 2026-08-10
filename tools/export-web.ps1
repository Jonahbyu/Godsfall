# Export the Web build and publish it to the `gh-pages` branch.
#
#   powershell -ExecutionPolicy Bypass -File tools\export-web.ps1
#   powershell -ExecutionPolicy Bypass -File tools\export-web.ps1 -NoPush
#
# The build is written to `build/web/`, which is gitignored on master: a 39MB
# wasm regenerated on every export has no business in the history of a source
# branch. Publishing copies it onto `gh-pages`, which holds nothing else, so the
# two branches never share a file and the game build can never clobber the
# design docs in `docs/`.
#
# `-NoPush` builds without touching git — use it to check an export locally
# before deciding to publish.

param(
    [switch]$NoPush
)

$ErrorActionPreference = 'Stop'

$ProjectDir = Split-Path -Parent $PSScriptRoot
$BuildDir   = Join-Path $ProjectDir 'build\web'
$GodotPath  = Join-Path $PSScriptRoot 'godot-path.txt'

# Reuse the pinned Godot the launcher already found, so this script and the game
# always run the same build.
if (-not (Test-Path $GodotPath)) {
    Write-Error "No tools/godot-path.txt. Launch the game once so it is written."
}
$Godot = (Get-Content $GodotPath -Raw).Trim()
if (-not (Test-Path $Godot)) {
    Write-Error "Godot not found at '$Godot' (from tools/godot-path.txt)."
}

# The page's mobile CSS and the fullscreen button live in tools/web-head.html
# and are written into the preset's html/head_include here. Keeping them in a
# real .html file means they can be edited as HTML with a real editor, instead
# of as one backslash-escaped line inside a .cfg - and it keeps the export
# reproducible: whatever that file says is what ships.
$HeadFile = Join-Path $PSScriptRoot 'web-head.html'
if (-not (Test-Path $HeadFile)) {
    Write-Error "Missing tools/web-head.html - it holds the page's mobile styles and fullscreen button."
}

$PresetFile = Join-Path $ProjectDir 'export_presets.cfg'
$head = Get-Content $HeadFile -Raw

# The .cfg holds the value as one double-quoted string, so backslashes, quotes
# and newlines all have to be escaped the way Godot writes them. Order matters:
# backslashes first, or the backslashes introduced by the later two get escaped
# a second time. Done with .Replace() (literal) rather than -replace (regex), so
# nothing in the HTML is interpreted as a pattern.
$escaped = $head.Replace('\', '\\').Replace('"', '\"')
$escaped = $escaped.Replace("`r`n", '\n').Replace("`n", '\n')

$line = 'html/head_include="' + $escaped + '"'

# Rebuilt line by line rather than with a regex replace: the replacement text is
# arbitrary HTML, and a dollar sign in a regex replacement is a capture-group
# reference, so one anywhere in the CSS or script would corrupt the output.
$out = foreach ($l in (Get-Content $PresetFile)) {
    if ($l -like 'html/head_include=*') { $line } else { $l }
}

$updated = ($out -join "`n") + "`n"
if ($updated -ne (Get-Content $PresetFile -Raw)) {
    # Written through .NET rather than Set-Content because PowerShell 5.1's
    # `-Encoding utf8` always emits a BOM, and Godot does not skip one: the BOM
    # lands in front of `[preset.0]`, the section header stops matching, and the
    # export fails with "Invalid export preset name: Web" - which says nothing
    # about encoding and sends you looking in the wrong place entirely.
    [System.IO.File]::WriteAllText(
        $PresetFile, $updated, (New-Object System.Text.UTF8Encoding $false))
    Write-Host "Updated html/head_include from tools/web-head.html" -ForegroundColor Cyan
}

Write-Host "Exporting Web build..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force $BuildDir | Out-Null

# --import first: a fresh checkout has no .godot/, and exporting without it
# silently ships a build with no imported textures.
& $Godot --headless --path $ProjectDir --import | Out-Null
& $Godot --headless --path $ProjectDir --export-release 'Web' | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Error "Godot export failed with exit code $LASTEXITCODE."
}
if (-not (Test-Path (Join-Path $BuildDir 'index.wasm'))) {
    Write-Error "Export reported success but produced no index.wasm."
}

$size = [math]::Round((Get-ChildItem $BuildDir -File | Measure-Object Length -Sum).Sum / 1MB, 1)
Write-Host "Build OK - $size MB in build/web" -ForegroundColor Green

if ($NoPush) {
    Write-Host "-NoPush set; stopping before git." -ForegroundColor Yellow
    exit 0
}

# Publish to gh-pages via a temporary worktree. A worktree is what keeps this
# safe to run with uncommitted work in progress: the orphan branch is checked
# out in its own directory, so the working tree on master is never touched.
$Work = Join-Path $env:TEMP "godsfall-ghpages-$(Get-Random)"

# Does gh-pages exist yet? `git rev-parse --verify` writes to stderr when it
# does not, and under $ErrorActionPreference='Stop' PowerShell turns a native
# command's stderr into a terminating error — so ask a command that answers with
# output instead of a failure.
$branches = @(git -C $ProjectDir branch --list gh-pages)
$hasBranch = $branches.Count -gt 0

if ($hasBranch) {
    git -C $ProjectDir worktree add $Work gh-pages | Out-Null
} else {
    git -C $ProjectDir worktree add --detach $Work | Out-Null
    git -C $Work checkout --orphan gh-pages | Out-Null
    git -C $Work reset | Out-Null
}

try {
    Get-ChildItem $Work -Exclude '.git' | Remove-Item -Recurse -Force
    Copy-Item "$BuildDir\*" $Work -Recurse -Force

    # .nojekyll stops GitHub Pages running the files through Jekyll, which
    # ignores paths beginning with an underscore and would drop parts of a
    # Godot build without reporting anything.
    New-Item -ItemType File -Path (Join-Path $Work '.nojekyll') -Force | Out-Null

    git -C $Work add -A | Out-Null

    # `git commit` exits non-zero when there is nothing staged, which is the
    # normal "rebuilt, nothing changed" case rather than a failure — so check
    # for staged changes first and only commit when there are some.
    $staged = @(git -C $Work diff --cached --name-only)

    if ($staged.Count -gt 0) {
        $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
        git -C $Work commit -m "Web build $stamp" | Out-Null
        git -C $Work push origin gh-pages
        Write-Host "Published to gh-pages." -ForegroundColor Green
    } else {
        Write-Host "No change since the last published build." -ForegroundColor Yellow
    }
} finally {
    git -C $ProjectDir worktree remove $Work --force 2>$null | Out-Null
}
