#!/bin/bash
set -e

# --- Configuration ---
ORIGIN_URL="git@github.com:jtmcdole/flutter.git"
UPSTREAM_URL="https://github.com/flutter/flutter.git"

# Specific refs
REF_MASTER="master"
REF_STABLE="stable" # stable candidate branch

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
git worktree add master upstream/master

# --- Setup STABLE ---
echo "🌲 Creating 'stable' worktree (based on upstream/$REF_STABLE)..."
# We create a local branch named 'stable' based on the upstream ref
git worktree add stable upstream/"$REF_STABLE"

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

cat <<EOT > "$SWITCH_FILE"
# Source this file in your .bashrc or .zshrc
# Usage: source $SWITCH_FILE

# Save the repo root for reference
export FLUTTER_REPO_ROOT="$ROOT_PATH"

fswitch() {
    local target=\$1
    local valid_targets=("master" "stable")

    # 1. Validation
    if [[ ! " \${valid_targets[@]} " =~ " \${target} " ]]; then
        echo "❌ Invalid target: '\$target'"
        echo "   Available contexts: master, stable"
        return 1
    fi

    # 2. Clean PATH
    # We remove any path containing the FLUTTER_REPO_ROOT to avoid conflicts
    # This prevents having both 'master' and 'stable' in PATH at the same time
    local new_path=\$(echo "\$PATH" | tr ':' '\n' | grep -v "\$FLUTTER_REPO_ROOT" | tr '\n' ':' | sed 's/:$//')

    # 3. Update PATH
    # Prepend the new target's bin directory
    export PATH="\$FLUTTER_REPO_ROOT/\$target/bin:\$new_path"

    # 4. Verify
    echo "✅ Switched to Flutter \$target"
    echo "   Flutter: \$(which flutter)"
    echo "   Dart:    \$(which dart)"
    flutter --version | head -n 1
}

# Optional: Default to stable on load if no flutter is found
if ! command -v flutter &> /dev/null; then
    fswitch stable # Uncomment to auto-load stable
    echo "ℹ️  Flutter environment loaded. Use 'fswitch stable' or 'fswitch master' to activate."
fi
EOT

echo ""
echo "✅ Setup Complete!"
echo "------------------------------------------------------"
echo "📂 Root:      $ROOT_PATH"
echo "👉 To enable the switcher, add this to your .zshrc / .bashrc:"
echo "   source $SWITCH_FILE" > /dev/null 2>&1
echo ""
echo "Usage:"
echo "   $ fswitch master   -> Activates master branch"
echo "   $ fswitch stable   -> Activates stable branch"
echo "------------------------------------------------------"