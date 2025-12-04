# Requires -Version 7.0
$ErrorActionPreference = "Stop"
# This makes native commands (git) throw exceptions on failure, acting like 'set -e'
$PSNativeCommandUseErrorActionPreference = $true

# --- Configuration ---
# Check if OriginUrl is provided (e.g. via environment variable or parameter context)
# If not, prompt the user interactively.
if ([string]::IsNullOrWhiteSpace($OriginUrl)) {
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
$SwitchFile = Join-Path $RootPath "env_switch.ps1"

$PAYLOAD = "IyBTb3VyY2UgdGhpcyBmaWxlIGluIHlvdXIgUG93ZXJTaGVsbCBQcm9maWxlCiMgVXNhZ2U6IC4gIiRTd2l0Y2hGaWxlIgoKIyBSZXNldCByb290IHRvIGVuc3VyZSBubyBzdGFsZSB2YWx1ZXMKJGdsb2JhbDpGbHV0dGVyUmVwb1Jvb3QgPSAkbnVsbAoKaWYgKCRQU1NjcmlwdFJvb3QpIHsKICAgICRnbG9iYWw6Rmx1dHRlclJlcG9Sb290ID0gJFBTU2NyaXB0Um9vdAp9CmVsc2UgewogICAgJGdsb2JhbDpGbHV0dGVyUmVwb1Jvb3QgPSBHZXQtTG9jYXRpb24gfCBTZWxlY3QtT2JqZWN0IC1FeHBhbmRQcm9wZXJ0eSBQYXRoCn0KCmZ1bmN0aW9uIEdldC1GbHV0dGVyV29ya3RyZWVzIHsKICAgIGlmIChUZXN0LVBhdGggIiRnbG9iYWw6Rmx1dHRlclJlcG9Sb290IiAtUGF0aFR5cGUgQ29udGFpbmVyKSB7CiAgICAgICAgJGdpdEFyZ3MgPSBAKCItQyIsICIkZ2xvYmFsOkZsdXR0ZXJSZXBvUm9vdCIsICJ3b3JrdHJlZSIsICJsaXN0IikKICAgICAgICB0cnkgewogICAgICAgICAgICAkb3V0cHV0ID0gJiBnaXQgJGdpdEFyZ3MgMj4kbnVsbAogICAgICAgICAgICBpZiAoJExBU1RFWElUQ09ERSAtZXEgMCkgewogICAgICAgICAgICAgICAgJG91dHB1dCB8IFdoZXJlLU9iamVjdCB7ICRfIC1ub3RtYXRjaCAiXChiYXJlXCkiIH0gfCBGb3JFYWNoLU9iamVjdCB7CiAgICAgICAgICAgICAgICAgICAgaWYgKCRfIC1tYXRjaCAnXig/PHBhdGg+Lio/KVxzK1swLTlhLWZdK1xzKyg/PGV4dHJhPi4qKSQnKSB7CiAgICAgICAgICAgICAgICAgICAgICAgICRmdWxsUGF0aCA9ICRtYXRjaGVzWydwYXRoJ10KICAgICAgICAgICAgICAgICAgICAgICAgJGV4dHJhID0gJG1hdGNoZXNbJ2V4dHJhJ10KICAgICAgICAgICAgICAgICAgICAgICAgJGRpck5hbWUgPSBTcGxpdC1QYXRoIC1MZWFmICRmdWxsUGF0aAogICAgICAgICAgICAgICAgICAgICAgICAkYnJhbmNoID0gIiIKCiAgICAgICAgICAgICAgICAgICAgICAgIGlmICgkZXh0cmEgLW1hdGNoICdcWyg/PGJyPi4qPylcXScpIHsKICAgICAgICAgICAgICAgICAgICAgICAgICAgICRicmFuY2ggPSAkbWF0Y2hlc1snYnInXQogICAgICAgICAgICAgICAgICAgICAgICB9CgogICAgICAgICAgICAgICAgICAgICAgICBbUFNDdXN0b21PYmplY3RdQHsKICAgICAgICAgICAgICAgICAgICAgICAgICAgIFBhdGggICAgPSAkZnVsbFBhdGgKICAgICAgICAgICAgICAgICAgICAgICAgICAgIERpck5hbWUgPSAkZGlyTmFtZQogICAgICAgICAgICAgICAgICAgICAgICAgICAgQnJhbmNoICA9ICRicmFuY2gKICAgICAgICAgICAgICAgICAgICAgICAgfQogICAgICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgfQogICAgICAgIH0KICAgICAgICBjYXRjaCB7CiAgICAgICAgICAgIFdyaXRlLVdhcm5pbmcgIkNvdWxkIG5vdCBleGVjdXRlICdnaXQgd29ya3RyZWUgbGlzdCcuIEVuc3VyZSBnaXQgaXMgaW5zdGFsbGVkIGFuZCBpbiB5b3VyIFBBVEguIgogICAgICAgIH0KICAgIH0KfQoKZnVuY3Rpb24gZnN3aXRjaCB7CiAgICBwYXJhbSgKICAgICAgICBbUGFyYW1ldGVyKE1hbmRhdG9yeSA9ICR0cnVlLCBQb3NpdGlvbiA9IDApXQogICAgICAgIFtBcmd1bWVudENvbXBsZXRlcih7CiAgICAgICAgICAgICAgICBwYXJhbSgkY29tbWFuZE5hbWUsICRwYXJhbWV0ZXJOYW1lLCAkd29yZFRvQ29tcGxldGUsICRjb21tYW5kQXN0LCAkZmFrZUJvdW5kUGFyYW1ldGVycykKICAgICAgICAgICAgICAgICR3b3JrdHJlZXMgPSBHZXQtRmx1dHRlcldvcmt0cmVlcwogICAgICAgICAgICAgICAgJHRhcmdldHMgPSBAKCkKICAgICAgICAgICAgICAgIGlmICgkd29ya3RyZWVzKSB7CiAgICAgICAgICAgICAgICAgICAgJHRhcmdldHMgKz0gJHdvcmt0cmVlcy5EaXJOYW1lCiAgICAgICAgICAgICAgICAgICAgJHRhcmdldHMgKz0gJHdvcmt0cmVlcy5CcmFuY2gKICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgICAgICR0YXJnZXRzIHwgV2hlcmUtT2JqZWN0IHsgJF8gLWxpa2UgIiR3b3JkVG9Db21wbGV0ZSoiIH0gfCBTb3J0LU9iamVjdCAtVW5pcXVlIHwgRm9yRWFjaC1PYmplY3QgewogICAgICAgICAgICAgICAgICAgIFtTeXN0ZW0uTWFuYWdlbWVudC5BdXRvbWF0aW9uLkNvbXBsZXRpb25SZXN1bHRdOjpuZXcoJF8sICRfLCAnUGFyYW1ldGVyVmFsdWUnLCAkXykKICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgfSldCiAgICAgICAgW3N0cmluZ10kVGFyZ2V0CiAgICApCgogICAgJHdvcmt0cmVlcyA9IEdldC1GbHV0dGVyV29ya3RyZWVzCiAgICAkcmVzb2x2ZWREaXIgPSAkbnVsbAoKICAgIGlmICgkd29ya3RyZWVzKSB7CiAgICAgICAgZm9yZWFjaCAoJHd0IGluICR3b3JrdHJlZXMpIHsKICAgICAgICAgICAgaWYgKCRUYXJnZXQgLWVxICR3dC5EaXJOYW1lIC1vciAoJHd0LkJyYW5jaCAtYW5kICRUYXJnZXQgLWVxICR3dC5CcmFuY2gpKSB7CiAgICAgICAgICAgICAgICAkcmVzb2x2ZWREaXIgPSAkd3QuRGlyTmFtZQogICAgICAgICAgICAgICAgYnJlYWsKICAgICAgICAgICAgfQogICAgICAgIH0KICAgIH0KCiAgICBpZiAoW3N0cmluZ106OklzTnVsbE9yRW1wdHkoJHJlc29sdmVkRGlyKSkgewogICAgICAgIFdyaXRlLUVycm9yICLinYwgSW52YWxpZCB0YXJnZXQ6ICckVGFyZ2V0JyIKICAgICAgICBXcml0ZS1Ib3N0ICIgICBBdmFpbGFibGUgY29udGV4dHM6IgogICAgICAgIGlmICgkd29ya3RyZWVzKSB7CiAgICAgICAgICAgIGZvcmVhY2ggKCR3dCBpbiAkd29ya3RyZWVzKSB7CiAgICAgICAgICAgICAgICAkYkluZm8gPSBpZiAoJHd0LkJyYW5jaCkgeyAkd3QuQnJhbmNoIH0gZWxzZSB7ICJkZXRhY2hlZCIgfQogICAgICAgICAgICAgICAgV3JpdGUtSG9zdCAiICAgLSAkKCR3dC5EaXJOYW1lKSAoJGJJbmZvKSIKICAgICAgICAgICAgfQogICAgICAgIH0KICAgICAgICBlbHNlIHsKICAgICAgICAgICAgV3JpdGUtSG9zdCAiICAgKE5vIHdvcmt0cmVlcyBmb3VuZC4gQ2hlY2sgaWYgZ2l0IGlzIGluc3RhbGxlZCBhbmQgJyRnbG9iYWw6Rmx1dHRlclJlcG9Sb290JyBpcyBhIHZhbGlkIHJlcG8uKSIKICAgICAgICB9CiAgICAgICAgcmV0dXJuCiAgICB9CgogICAgIyAxLiBDbGVhbiBQYXRoCiAgICBpZiAoJElzV2luZG93cykgewogICAgICAgICRzZXBDaGFyID0gJzsnCiAgICB9CiAgICBlbHNlIHsKICAgICAgICAkc2VwQ2hhciA9ICc6JwogICAgfQoKICAgIGlmICgkbnVsbCAtbmUgJGVudjpQYXRoKSB7CiAgICAgICAgJGN1cnJlbnRQYXRoID0gJGVudjpQYXRoLlNwbGl0KCRzZXBDaGFyLCBbU3lzdGVtLlN0cmluZ1NwbGl0T3B0aW9uc106OlJlbW92ZUVtcHR5RW50cmllcykKICAgIH0KICAgIGVsc2UgewogICAgICAgICRjdXJyZW50UGF0aCA9IEAoKQogICAgfQoKICAgICRjbGVhblBhdGggPSBAKCRjdXJyZW50UGF0aCkgfCBXaGVyZS1PYmplY3QgewogICAgICAgICRwYXRoID0gJF8KICAgICAgICBpZiAoW3N0cmluZ106OklzTnVsbE9yV2hpdGVTcGFjZSgkcGF0aCkpIHsKICAgICAgICAgICAgcmV0dXJuICRmYWxzZQogICAgICAgIH0KCiAgICAgICAgaWYgKC1ub3QgW3N0cmluZ106OklzTnVsbE9yRW1wdHkoJGdsb2JhbDpGbHV0dGVyUmVwb1Jvb3QpKSB7CiAgICAgICAgICAgICRub3JtUGF0aCA9ICRwYXRoLlRyaW1FbmQoW1N5c3RlbS5JTy5QYXRoXTo6RGlyZWN0b3J5U2VwYXJhdG9yQ2hhciwgW1N5c3RlbS5JTy5QYXRoXTo6QWx0RGlyZWN0b3J5U2VwYXJhdG9yQ2hhcikKICAgICAgICAgICAgJG5vcm1Sb290ID0gJGdsb2JhbDpGbHV0dGVyUmVwb1Jvb3QuVHJpbUVuZChbU3lzdGVtLklPLlBhdGhdOjpEaXJlY3RvcnlTZXBhcmF0b3JDaGFyLCBbU3lzdGVtLklPLlBhdGhdOjpBbHREaXJlY3RvcnlTZXBhcmF0b3JDaGFyKQogICAgICAgICAgICBpZiAoJG5vcm1QYXRoLlN0YXJ0c1dpdGgoJG5vcm1Sb290KSkgewogICAgICAgICAgICAgICAgcmV0dXJuICRmYWxzZQogICAgICAgICAgICB9CiAgICAgICAgfQogICAgICAgIHJldHVybiAkdHJ1ZQogICAgfQoKICAgICMgMi4gVXBkYXRlIFBhdGgKICAgICRuZXdCaW4gPSBKb2luLVBhdGggJGdsb2JhbDpGbHV0dGVyUmVwb1Jvb3QgJHJlc29sdmVkRGlyICJiaW4iCgogICAgaWYgKC1ub3QgJElzV2luZG93cykgewogICAgICAgICRmbHV0dGVyQmluID0gSm9pbi1QYXRoICRuZXdCaW4gImZsdXR0ZXIiCiAgICAgICAgaWYgKFRlc3QtUGF0aCAkZmx1dHRlckJpbikgewogICAgICAgICAgICBpZiAoR2V0LUNvbW1hbmQgY2htb2QgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpIHsKICAgICAgICAgICAgICAgIGNobW9kICt4ICIkZmx1dHRlckJpbiIgMj4kbnVsbAogICAgICAgICAgICB9CiAgICAgICAgfQogICAgfQoKICAgIGlmICgkY2xlYW5QYXRoLkNvdW50IC1ndCAwKSB7CiAgICAgICAgJGVudjpQYXRoID0gIiRuZXdCaW4kc2VwQ2hhciIgKyAoJGNsZWFuUGF0aCAtam9pbiAkc2VwQ2hhcikKICAgIH0KICAgIGVsc2UgewogICAgICAgICRlbnY6UGF0aCA9ICIkbmV3QmluIgogICAgfQoKCiAgICAjIDMuIFZlcmlmeQogICAgV3JpdGUtSG9zdCAi4pyFIFN3aXRjaGVkIHRvIEZsdXR0ZXIgJHJlc29sdmVkRGlyIiAtRm9yZWdyb3VuZENvbG9yIEdyZWVuCgogICAgJGZsdXR0ZXJQYXRoID0gKEdldC1Db21tYW5kIGZsdXR0ZXIgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpLlNvdXJjZQogICAgJGRhcnRQYXRoID0gKEdldC1Db21tYW5kIGRhcnQgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpLlNvdXJjZQoKICAgIFdyaXRlLUhvc3QgIiAgIEZsdXR0ZXI6ICRmbHV0dGVyUGF0aCIKICAgIFdyaXRlLUhvc3QgIiAgIERhcnQ6ICAgICRkYXJ0UGF0aCIKCiAgICAjIFJ1biBmbHV0dGVyIC0tdmVyc2lvbiB0byBjb25maXJtIHRoZSBQQVRIIGlzIHNldCBjb3JyZWN0bHkKICAgIGlmICgoR2V0LUNvbW1hbmQgZmx1dHRlciAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkpIHsKICAgICAgICAkcHJldkVuY29kaW5nID0gW0NvbnNvbGVdOjpPdXRwdXRFbmNvZGluZwogICAgICAgIFtDb25zb2xlXTo6T3V0cHV0RW5jb2RpbmcgPSBbU3lzdGVtLlRleHQuRW5jb2RpbmddOjpVVEY4CiAgICAgICAgdHJ5IHsKICAgICAgICAgICAgZmx1dHRlciAtLXZlcnNpb24gfCBTZWxlY3QtT2JqZWN0IC1GaXJzdCAxCiAgICAgICAgfQogICAgICAgIGZpbmFsbHkgewogICAgICAgICAgICBbQ29uc29sZV06Ok91dHB1dEVuY29kaW5nID0gJHByZXZFbmNvZGluZwogICAgICAgIH0KICAgIH0KICAgIGVsc2UgewogICAgICAgIFdyaXRlLVdhcm5pbmcgIiAgICdmbHV0dGVyJyBjb21tYW5kIG5vdCBmb3VuZCBpbiB0aGUgbmV3IFBBVEguIgogICAgfQp9CgojIE9wdGlvbmFsOiBEZWZhdWx0IHRvIGEgdmVyc2lvbiBvbiBsb2FkIGlmIG5vIGZsdXR0ZXIgaXMgZm91bmQKaWYgKC1ub3QgKEdldC1Db21tYW5kIGZsdXR0ZXIgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpKSB7CiAgICAjIFN3aXRjaCB0byBhIHNlbnNpYmxlIGRlZmF1bHQsIGUuZy4gJ3N0YWJsZScuCiAgICAjIFRoaXMgbWF0Y2hlcyB0aGUgYmVoYXZpb3Igb2YgdGhlIC5zaCBzY3JpcHQuCiAgICBmc3dpdGNoIHN0YWJsZQp9Cg=="
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
