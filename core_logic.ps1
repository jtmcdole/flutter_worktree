# Source this file in your PowerShell Profile
# Usage: . "$SwitchFile"

# Reset root to ensure no stale values
$global:FlutterRepoRoot = $null

if ($PSScriptRoot) {
    $global:FlutterRepoRoot = $PSScriptRoot
}
else {
    $global:FlutterRepoRoot = Get-Location | Select-Object -ExpandProperty Path
}

function Get-FlutterWorktrees {
    if (Test-Path "$global:FlutterRepoRoot" -PathType Container) {
        $gitArgs = @("-C", "$global:FlutterRepoRoot", "worktree", "list")
        try {
            $output = & git $gitArgs 2>$null
            if ($LASTEXITCODE -eq 0) {
                $output | Where-Object { $_ -notmatch "\(bare\)" } | ForEach-Object {
                    if ($_ -match '^(?<path>.*?)\s+[0-9a-f]+\s+(?<extra>.*)$') {
                        $fullPath = $matches['path']
                        $extra = $matches['extra']
                        $dirName = Split-Path -Leaf $fullPath
                        $branch = ""

                        if ($extra -match '\[(?<br>.*?)\]') {
                            $branch = $matches['br']
                        }

                        [PSCustomObject]@{
                            Path    = $fullPath
                            DirName = $dirName
                            Branch  = $branch
                        }
                    }
                }
            }
        }
        catch {
            Write-Warning "Could not execute 'git worktree list'. Ensure git is installed and in your PATH."
        }
    }
}

function fswitch {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $worktrees = Get-FlutterWorktrees
                $targets = @()
                if ($worktrees) {
                    $targets += $worktrees.DirName
                    $targets += $worktrees.Branch
                }
                $targets | Where-Object { $_ -like "$wordToComplete*" } | Sort-Object -Unique | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [string]$Target
    )

    $worktrees = Get-FlutterWorktrees
    $resolvedDir = $null

    if ($worktrees) {
        foreach ($wt in $worktrees) {
            if ($Target -eq $wt.DirName -or ($wt.Branch -and $Target -eq $wt.Branch)) {
                $resolvedDir = $wt.DirName
                break
            }
        }
    }

    if ([string]::IsNullOrEmpty($resolvedDir)) {
        Write-Error "❌ Invalid target: '$Target'"
        Write-Host "   Available contexts:"
        if ($worktrees) {
            foreach ($wt in $worktrees) {
                $bInfo = if ($wt.Branch) { $wt.Branch } else { "detached" }
                Write-Host "   - $($wt.DirName) ($bInfo)"
            }
        }
        else {
            Write-Host "   (No worktrees found. Check if git is installed and '$global:FlutterRepoRoot' is a valid repo.)"
        }
        return
    }

    # 1. Clean Path
    if ($IsWindows) {
        $sepChar = ';'
    }
    else {
        $sepChar = ':'
    }

    if ($null -ne $env:PATH) {
        $currentPath = $env:PATH.Split($sepChar, [System.StringSplitOptions]::RemoveEmptyEntries)
    }
    else {
        $currentPath = @()
    }

    $cleanPath = @($currentPath) | Where-Object {
        $path = $_
        if ([string]::IsNullOrWhiteSpace($path)) {
            return $false
        }

        if (-not [string]::IsNullOrEmpty($global:FlutterRepoRoot)) {
            $normPath = $path.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
            $normRoot = $global:FlutterRepoRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
            if ($normPath.StartsWith($normRoot)) {
                return $false
            }
        }
        return $true
    }

    # 2. Update Path
    $newBin = Join-Path $global:FlutterRepoRoot $resolvedDir "bin"

    if (-not $IsWindows) {
        $flutterBin = Join-Path $newBin "flutter"
        if (Test-Path $flutterBin) {
            if (Get-Command chmod -ErrorAction SilentlyContinue) {
                chmod +x "$flutterBin" 2>$null
            }
        }
    }

    if ($cleanPath.Count -gt 0) {
        $env:PATH = "$newBin$sepChar" + ($cleanPath -join $sepChar)
    }
    else {
        $env:PATH = "$newBin"
    }


    # 3. Verify
    Write-Host "✅ Switched to Flutter $resolvedDir" -ForegroundColor Green

    $flutterPath = (Get-Command flutter -ErrorAction SilentlyContinue).Source
    $dartPath = (Get-Command dart -ErrorAction SilentlyContinue).Source

    Write-Host "   Flutter: $flutterPath"
    Write-Host "   Dart:    $dartPath"

    # Run flutter --version to confirm the PATH is set correctly
    if ((Get-Command flutter -ErrorAction SilentlyContinue)) {
        $prevEncoding = [Console]::OutputEncoding
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        try {
            flutter --version | Select-Object -First 1
        }
        finally {
            [Console]::OutputEncoding = $prevEncoding
        }
    }
    else {
        Write-Warning "   'flutter' command not found in the new PATH."
    }
}

# Optional: Default to a version on load if no flutter is found
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    # Switch to master
    fswitch master
}
