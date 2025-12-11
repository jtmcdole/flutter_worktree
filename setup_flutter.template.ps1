# Requires -Version 7.0
$ErrorActionPreference = "Stop"
# This makes native commands (git) throw exceptions on failure, acting like 'set -e'
$PSNativeCommandUseErrorActionPreference = $true

# --- Configuration ---
# Check if OriginUrl is provided (e.g. via environment variable or parameter context)
# If not, prompt the user interactively.
if ([string]::IsNullOrWhiteSpace($OriginUrl)) {
    Write-Host "Don't have a fork yet? https://github.com/flutter/flutter/fork" -ForegroundColor Cyan
    Write-Host "Please enter your Flutter fork URL (e.g. git@github.com:username/flutter.git)" -ForegroundColor Cyan
    $OriginUrl = Read-Host "Origin URL"
}

if ([string]::IsNullOrWhiteSpace($OriginUrl)) {
    Write-Error "❌ Error: Origin URL is required. Aborting."
    exit 1
}

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
git worktree add -B master master --track upstream/master

# --- Setup STABLE ---
$setupStable = Read-Host "Do you want to setup the 'stable' worktree? (y/N)"
if ($setupStable -match "^[yY]") {
    Write-Host "🌲 Creating 'stable' worktree (based on upstream/$RefStable)..." -ForegroundColor Green
    git worktree add -B stable stable --track upstream/"$RefStable"
}

# 6. Pre-load Artifacts
# Determine correct flutter command based on OS for cross-platform compatibility
$flutterCmd = if ($IsWindows) { ".\bin\flutter.bat" } else { "./bin/flutter" }
if ($setupStable -match "^[yY]") {
    Write-Host "🛠️  Hydrating 'stable' artifacts..." -ForegroundColor Magenta
    Set-Location stable
    & $flutterCmd --version | Out-Null
    Set-Location ..
}

Write-Host "🛠️  Hydrating 'master' artifacts..." -ForegroundColor Magenta
Set-Location master
& $flutterCmd --version | Out-Null
Set-Location ..

# 7. Generate The Switcher Script
Write-Host "🔗 Generating context switcher..." -ForegroundColor Cyan
$SwitchFile = Join-Path $RootPath "fswitch.ps1"

$PAYLOAD = "REPLACE_ME"
[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($PAYLOAD)) | Set-Content -Path $SwitchFile -Encoding UTF8

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
Write-Host ""
Write-Host "Want to create a new worktree?"
Write-Host "   PS> git worktree add my_feature"
Write-Host "------------------------------------------------------"
