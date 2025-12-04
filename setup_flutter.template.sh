#!/bin/bash
set -e

# --- Configuration ---
ORIGIN_URL="git@github.com:jtmcdole/flutter.git"
UPSTREAM_URL="https://github.com/flutter/flutter.git"

# Specific refs
REF_STABLE="flutter-3.38-candidate.0" # stable candidate branch

# echo "🚀 Starting Flutter Worktree Setup..."

# 1. Create root directory
if [ -d "flutter" ]; then
    echo "❌ Error: Directory 'flutter' already exists. Aborting."
    exit 1
fi
mkdir -p "flutter"
cd "flutter"
ROOT_PATH=$(pwd)

# 2. Clone Bare Repo
echo "📦 Cloning origin as bare repository..."
git clone --bare "$ORIGIN_URL" .bare
echo "gitdir: ./.bare" > .git

# 3. Configure Remotes
cd .bare
echo "⚙️  Configuring remotes..."
git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
git remote add upstream "$UPSTREAM_URL"
git config remote.upstream.fetch "+refs/heads/*:refs/remotes/upstream/*"

# 4. Fetch tags / branches
echo "⬇️  Fetching everything (--all --tags --prune)..."
git fetch --all --tags --prune

# 5. Create Worktrees
cd ..

# --- Setup MASTER ---
echo "🌲 Creating 'master' worktree (tracking upstream/master)..."
git worktree add -B master master --track upstream/master

# --- Setup STABLE ---
echo "🌲 Creating 'stable' worktree (based on upstream/$REF_STABLE)..."
# We create a local branch named 'stable' based on the upstream ref
git worktree add -B stable stable --track upstream/"$REF_STABLE"

# 6. Pre-load Artifacts
# We run --version to download the engine/dart-sdk for both immediately
echo "🛠️  Hydrating 'stable' artifacts..."
cd stable
./bin/flutter --version > /dev/null
cd ..

echo "🛠️  Hydrating 'master' artifacts..."
cd master
./bin/flutter --version > /dev/null
cd ..

# 7. Generate The Switcher Script
echo "🔗 Generating context switcher..."
SWITCH_FILE="$ROOT_PATH/env_switch.sh"

PAYLOAD="REPLACE_ME"
echo "$PAYLOAD" | base64 --decode > "$SWITCH_FILE"
chmod +x "$SWITCH_FILE"

echo ""
echo "✅ Setup Complete!"
echo "------------------------------------------------------"
echo "📂 Root:      $ROOT_PATH"
echo "👉 To enable the switcher, add this to your .zshrc / .bashrc:"
echo "   source $SWITCH_FILE > /dev/null 2>&1"
echo ""
echo "Usage:"
echo "   $ fswitch master   -> Activates master branch"
echo "   $ fswitch stable   -> Activates stable branch"
echo "------------------------------------------------------"
