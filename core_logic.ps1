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
                        
                        # Calculate DirName (Relative path or Leaf name)
                        $dirName = ""
                        # Normalize for comparison (Git output usually has forward slashes or matches system)
                        # We use simple string operations. 
                        # Assuming $global:FlutterRepoRoot is normalized to system separators by PSScriptRoot logic usually?
                        # But git output might use forward slashes even on Windows.
                        
                        $normFull = $fullPath -replace '[\\/]', [System.IO.Path]::DirectorySeparatorChar
                        $normRoot = $global:FlutterRepoRoot -replace '[\\/]', [System.IO.Path]::DirectorySeparatorChar
                        
                        if ($normFull -eq $normRoot) {
                            $dirName = Split-Path -Leaf $normFull
                        }
                        elseif ($normFull.StartsWith($normRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
                            # Remove root prefix and leading slash
                            $dirName = $normFull.Substring($normRoot.Length).TrimStart([System.IO.Path]::DirectorySeparatorChar)
                        }
                        else {
                            # Fallback
                            $dirName = Split-Path -Leaf $normFull
                        }

                        $branch = ""
                        if ($extra -match '\[(?<br>.*?)\]') {
                            $branch = $matches['br']
                        }

                        [PSCustomObject]@{
                            Path    = $normFull
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
    $resolvedWt = $null

    if ($worktrees) {
        foreach ($wt in $worktrees) {
            if ($Target -eq $wt.DirName -or ($wt.Branch -and $Target -eq $wt.Branch)) {
                $resolvedWt = $wt
                break
            }
        }
    }

    if ($null -eq $resolvedWt) {
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
    # Use the FULL PATH from the resolved worktree
    $newBin = Join-Path $resolvedWt.Path "bin"
    $etBin = Join-Path $resolvedWt.Path "engine\src\flutter\bin"

    if (-not (Test-Path $newBin -PathType Container)) {
        Write-Error "❌ Error: Flutter bin directory not found at '$newBin'"
        return
    }

    if (-not $IsWindows) {
        $flutterBin = Join-Path $newBin "flutter"
        if (Test-Path $flutterBin) {
            if (Get-Command chmod -ErrorAction SilentlyContinue) {
                chmod +x "$flutterBin" 2>$null
            }
        }
    }

    $pathsToAdd = @($newBin)
    if (Test-Path $etBin -PathType Container) {
        $pathsToAdd += $etBin
    }

    if ($cleanPath.Count -gt 0) {
        $env:PATH = ($pathsToAdd -join $sepChar) + $sepChar + ($cleanPath -join $sepChar)
    }
    else {
        $env:PATH = ($pathsToAdd -join $sepChar)
    }

    # 3. Verify
    Write-Host "✅ Switched to Flutter $($resolvedWt.DirName)" -ForegroundColor Green

    $flutterPath = (Get-Command flutter -ErrorAction SilentlyContinue).Source
    $dartPath = (Get-Command dart -ErrorAction SilentlyContinue).Source

    Write-Host "   Flutter: $flutterPath"
    Write-Host "   Dart:    $dartPath"
}

function fcd {
    $flutterPath = Get-Command flutter -ErrorAction SilentlyContinue
    if ($null -eq $flutterPath) {
        Write-Error "❌ Flutter command not found. Run 'fswitch <target>' first."
        return
    }

    # flutterPath.Source will be something like ...\flutter_repo\master\bin\flutter.bat
    $binDir = Split-Path $flutterPath.Source -Parent

    # We expect 'bin' to be the parent. Go one level up.
    if ((Split-Path $binDir -Leaf) -eq "bin") {
        $rootDir = Split-Path $binDir -Parent
        Set-Location $rootDir
    }
    else {
        # Fallback if structure is weird, though fswitch enforces bin
        Set-Location $binDir
    }
}

Set-Alias -Name froot -Value fcd

# Optional: Default to a version on load if no flutter is found
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    # Switch to master
    fswitch master
}

