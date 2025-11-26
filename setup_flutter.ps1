# Requires -Version 7.0
$ErrorActionPreference = "Stop"
# This makes native commands (git) throw exceptions on failure, acting like 'set -e'
$PSNativeCommandUseErrorActionPreference = $true

# --- Configuration ---
$OriginUrl     = "git@github.com:jtmcdole/flutter.git"
$UpstreamUrl   = "https://github.com/flutter/flutter.git"

# Specific refs
$RefStable = "stable" 

Write-Host "🚀 Starting Flutter Worktree Setup (PS 7.5)..." -ForegroundColor Cyan

# 1. Create root directory
if (Test-Path -Path flutter -PathType Container) {
    Write-Error "❌ Error: Directory 'flutter' already exists. Aborting."
    exit 1
}
New-Item -ItemType Directory -Path flutter
Set-Location flutter
$RootPath = Get-Location

# 2. Clone Bare Repo
Write-Host "📦 Cloning origin as bare repository..." -ForegroundColor Yellow
git clone --bare "$OriginUrl" .bare

# Create .git pointer (Ascii is safest for git, though PS7 UTF8NoBOM works too)
Set-Content -Path .git -Value "gitdir: ./.bare" -Encoding Ascii

# 3. Configure Remotes
Set-Location .bare
Write-Host "⚙️  Configuring remotes..." -ForegroundColor Yellow

# Fix Origin and Add Upstream
git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
git remote add upstream "$UpstreamUrl"
git config remote.upstream.fetch "+refs/heads/*:refs/remotes/upstream/*"

# 4. Fetch All
Write-Host "⬇️  Fetching everything (--all --tags --prune)..." -ForegroundColor Yellow
git fetch --all --tags --prune

# 5. Create Worktrees
Set-Location ..

# --- Setup MASTER ---
Write-Host "🌲 Creating 'master' worktree..." -ForegroundColor Green

# Use a try-catch block for more idiomatic error handling.
try {
    git branch -D master 2>$null
}
catch {
    Write-Host "   (No existing master branch to delete, continuing...)" -ForegroundColor DarkGray
}

# Create new master worktree tracking upstream
git worktree add -b master master upstream/master

# --- Setup STABLE ---
Write-Host "🌲 Creating 'stable' worktree (based on upstream/$RefStable)..." -ForegroundColor Green
git worktree add -b stable stable upstream/"$RefStable"

# 6. Pre-load Artifacts
# Note: On Windows we must call flutter.bat
Write-Host "🛠️  Hydrating 'stable' artifacts..." -ForegroundColor Magenta
Set-Location stable
.\bin\flutter.bat --version | Out-Null
Set-Location ..

Write-Host "🛠️  Hydrating 'master' artifacts..." -ForegroundColor Magenta
Set-Location master
.\bin\flutter.bat --version | Out-Null
Set-Location ..

# 7. Generate The Switcher Script
Write-Host "🔗 Generating context switcher..." -ForegroundColor Cyan
$SwitchFile = Join-Path $RootPath "env_switch.ps1"

$ScriptContent = @"
# Source this file in your PowerShell Profile
# Usage: . "$SwitchFile"

`$global:FlutterRepoRoot = "$RootPath"

function fswitch {
    param([string]`$target)
    
    `$validTargets = @("master", "stable")

    if (`$target -notin `$validTargets) {
        Write-Error "❌ Invalid target: '`$target'"
        Write-Host "   Available contexts: master, stable"
        return
    }

    # 1. Clean Path
    # Split the path, filter out any entry containing the repo root
    `$currentPath = `$env:Path -split ';'
    `$cleanPath = `$currentPath | Where-Object { `$_ -notlike "*`$global:FlutterRepoRoot*" }

    # 2. Update Path
    # Prepend the new target bin directory
    `$newBin = Join-Path `$global:FlutterRepoRoot `$target "bin"
    `$env:Path = "`$newBin;\" + (`$cleanPath -join ';')

    # 3. Verify
    Write-Host "✅ Switched to Flutter `$target" -ForegroundColor Green
    Write-Host "   Flutter: `$(Get-Command flutter | Select-Object -ExpandProperty Source)"
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    flutter --version | Select-Object -First 1
}
"@

# PS 7 defaults Set-Content to UTF-8 (No BOM), which is perfect.
Set-Content -Path $SwitchFile -Value $ScriptContent

Write-Host ""
Write-Host "✅ Setup Complete!" -ForegroundColor Green
Write-Host "------------------------------------------------------"
Write-Host "📂 Root:      $RootPath"
Write-Host "👉 To enable the switcher, add this to your PowerShell Profile:"
Write-Host "   . '$SwitchFile'"
Write-Host ""
Write-Host "Usage:"
Write-Host "   PS> fswitch master   -> Activates master branch"
Write-Host "   PS> fswitch stable   -> Activates stable branch"
Write-Host "------------------------------------------------------"