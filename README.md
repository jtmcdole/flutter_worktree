# Flutter Worktree Setup

This repository contains scripts to automate a robust development environment for [Flutter](https://github.com/flutter/flutter) using **Git Worktrees** with a **Bare Repository**.

Instead of cloning the massive Flutter monorepo multiple times or constantly switching branches (which triggers expensive artifact downloading and engine rebuilds), this setup uses a shared git history with isolated working directories.

* **Zero Context Switching Costs**: Keep master and stable checked out simultaneously in separate folders.
* **Shared History**: All worktrees share a single .bare git history folder, saving significant disk space.
* **Isolated Builds**: Each worktree has its own bin/cache and build artifacts. You can run a Flutter 3.19 app and a Flutter 3.22 app at the same time without cache conflicts.
* **Path Management**: Includes a shell utility (fswitch) to cleanly swap your PATH environment variable between worktrees.

## Installation

To get started, simply run the appropriate one-liner for your operating system. The script will guide you through providing your Flutter fork's Git URL.

**Bash / Zsh (Linux & macOS):**

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/jtmcdole/flutter_worktree/main/dist/setup_flutter.sh)"
```

**PowerShell (Windows):**

```powershell
irm https://raw.githubusercontent.com/jtmcdole/flutter_worktree/main/dist/setup_flutter.ps1 | iex
```

## Directory Structure

After running the setup script, your development folder will be organized as follows:

```shell
~/dev/flutter/                  <-- Root Container (Not a git repo itself)
├── .bare/                      <-- The actual Git history (Hidden, Bare Repo)
├── .git                        <-- Git pointer file (allows git commands in root)
├── fswitch.sh (or .ps1)        <-- Script to swap PATH variables
├── master/                     <-- Worktree: Bleeding edge (upstream/master)
│   ├── bin/
│   ├── packages/
└── stable/                     <-- Worktree: Stable release candidate
    ├── bin/
    └── packages/
```

## Use it

```shell
# switch to TOT
fswitch main

✅ Switched to Flutter master
   Flutter: C:\dev\flutter\master\bin\flutter.bat
Flutter 3.39.0-1.0.pre-303 • channel master • https://github.com/flutter/flutter.git

# or use Stable
fswitch stable
✅ Switched to Flutter stable
   Flutter: C:\dev\flutter\stable\bin\flutter.bat
Flutter 3.38.3 • channel stable • https://github.com/flutter/flutter.git   
```
