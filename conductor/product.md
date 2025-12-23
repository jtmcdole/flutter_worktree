# Initial Concept
An existing project has been detected. It is a set of automation scripts (Bash, PowerShell) and a Dart utility to manage Flutter development environments using Git Worktrees.

# Product Guide

## Overview
Flutter Worktree Setup is a collection of automation scripts and utilities designed to simplify and optimize the management of multiple Flutter development environments on a single machine. By leveraging Git Worktrees and a Bare Repository, it allows developers to maintain multiple branches (like master and stable) simultaneously without the disk space and performance overhead of multiple full clones.

## Target Audience
- **Flutter contributors:** Developers who frequently switch between feature branches and upstream branches.
- **Advanced Flutter developers:** Users who need to test their applications against different Flutter versions quickly.
- **Teams managing multiple Flutter versions:** Groups working on diverse projects that target different Flutter releases.

## Core Goals
- **Reduce disk space usage:** Share Git history across multiple working directories using a single bare repository.
- **Eliminate context-switching costs:** Avoid expensive artifact downloads and engine rebuilds when switching branches.
- **Simplify path management:** Provide easy-to-use utilities for swapping the `PATH` environment variable between active worktrees.
- **Automate setup:** Provide a one-liner installation process to configure a robust bare repository and worktree environment.

## Key Features
- **Automated installation scripts:** Support for both Windows (PowerShell) and Linux/macOS (Bash/Zsh).
- **Path switching utility (fswitch):** A shell utility to cleanly update environment variables to point to the desired Flutter worktree.
- **Unattended installation:** Support for environment variables (e.g., `ORIGIN_URL`, `SETUP_STABLE`) to allow for scripted deployments without interactive prompts.

## Design Philosophy
- **Minimal dependencies:** Rely primarily on standard shell environments and Git, ensuring portability across systems.
- **Reliability:** Ensure isolated builds and caches for each worktree to prevent conflicts and ensure consistent development experiences.
