#!/bin/bash
set -e

# --- Configuration ---
# Check if ORIGIN_URL is provided (e.g. via environment variable)
# If not, prompt the user interactively.
if [ -z "$ORIGIN_URL" ]; then
    echo "Don't have a fork yet? https://github.com/flutter/flutter/fork"
    echo "Please enter your Flutter fork URL (e.g. git@github.com:username/flutter.git)"
    read -r -p "Origin URL: " ORIGIN_URL
fi

if [ -z "$ORIGIN_URL" ]; then
    echo "❌ Error: Origin URL is required. Aborting."
    exit 1
fi

UPSTREAM_URL="https://github.com/flutter/flutter.git"

# Specific refs
REF_STABLE="stable"

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
read -p "Do you want to setup the 'stable' worktree? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    SETUP_STABLE=true
    echo "🌲 Creating 'stable' worktree (based on upstream/$REF_STABLE)..."
    # We create a local branch named 'stable' based on the upstream ref
    git worktree add -B stable stable --track upstream/"$REF_STABLE"
else
    SETUP_STABLE=false
fi

# 6. Pre-load Artifacts
# We run --version to download the engine/dart-sdk for both immediately
if [ "$SETUP_STABLE" = true ]; then
    echo "🛠️  Hydrating 'stable' artifacts..."
    cd stable
    ./bin/flutter --version > /dev/null
    cd ..
fi

echo "🛠️  Hydrating 'master' artifacts..."
cd master
./bin/flutter --version > /dev/null
cd ..

# 7. Generate The Switcher Script
echo "🔗 Generating context switcher..."
SWITCH_FILE="$ROOT_PATH/fswitch.sh"

PAYLOAD="IyBTb3VyY2UgdGhpcyBmaWxlIGluIHlvdXIgLmJhc2hyYyBvciAuenNocmMKIyBVc2FnZTogc291cmNlICRTV0lUQ0hfRklMRQoKIyBBdXRvLWRldGVjdCB0aGUgcmVwbyByb290IGJhc2VkIG9uIHRoaXMgc2NyaXB0J3MgbG9jYXRpb24KaWYgWyAtbiAiJEJBU0hfU09VUkNFIiBdOyB0aGVuCiAgICBfU0NSSVBUX1BBVEg9IiR7QkFTSF9TT1VSQ0VbMF19IgplbGlmIFsgLW4gIiRaU0hfVkVSU0lPTiIgXTsgdGhlbgogICAgX1NDUklQVF9QQVRIPSIkeyglKTotJXh9IgplbHNlCiAgICBfU0NSSVBUX1BBVEg9IiQwIgpmaQoKRkxVVFRFUl9SRVBPX1JPT1Q9IiQoY2QgIiQoZGlybmFtZSAiJF9TQ1JJUFRfUEFUSCIpIiA+L2Rldi9udWxsIDI+JjEgJiYgcHdkKSIKCl9mc3dpdGNoX2dldF93b3JrdHJlZV9kYXRhKCkgewogICAgaWYgY29tbWFuZCAtdiBnaXQgJj4gL2Rldi9udWxsICYmIFsgLWQgIiRGTFVUVEVSX1JFUE9fUk9PVCIgXTsgdGhlbgogICAgICAgIGdpdCAtQyAiJEZMVVRURVJfUkVQT19ST09UIiB3b3JrdHJlZSBsaXN0IDI+L2Rldi9udWxsIHwgZ3JlcCAtdiAiKGJhcmUpIgogICAgZmkKfQoKX2Zzd2l0Y2hfcmVzb2x2ZSgpIHsKICAgIGxvY2FsIHRhcmdldD0kMQogICAgaWYgW1sgLXogIiRGTFVUVEVSX1JFUE9fUk9PVCIgXV07IHRoZW4KICAgICAgICByZXR1cm4KICAgIGZpCiAgICBsb2NhbCByZXNvbHZlZD0iIgogICAgCiAgICB3aGlsZSByZWFkIC1yIHd0X3BhdGggaGFzaCBicmFuY2hfaW5mbyByZXN0OyBkbwogICAgICAgIGxvY2FsIHJlbF9wYXRoPSIke3d0X3BhdGgjJEZMVVRURVJfUkVQT19ST09UL30iCiAgICAgICAgbG9jYWwgaXNfcm9vdD0wCiAgICAgICAgaWYgW1sgIiRyZWxfcGF0aCIgPT0gIiR3dF9wYXRoIiAmJiAiJHd0X3BhdGgiID09ICIkRkxVVFRFUl9SRVBPX1JPT1QiIF1dOyB0aGVuCiAgICAgICAgICAgIHJlbF9wYXRoPSIuIgogICAgICAgICAgICBpc19yb290PTEKICAgICAgICBmaQoKICAgICAgICBsb2NhbCBicmFuY2hfbmFtZT0iJHticmFuY2hfaW5mbyNcW30iCiAgICAgICAgYnJhbmNoX25hbWU9IiR7YnJhbmNoX25hbWUlXF19IgogICAgICAgIAogICAgICAgIGlmIFtbICIkdGFyZ2V0IiA9PSAiJHJlbF9wYXRoIiBdXSB8fCBbWyAiJHRhcmdldCIgPT0gIiRicmFuY2hfbmFtZSIgXV07IHRoZW4KICAgICAgICAgICAgcmVzb2x2ZWQ9IiRyZWxfcGF0aCIKICAgICAgICAgICAgYnJlYWsKICAgICAgICBmaQogICAgZG9uZSA8IDwoX2Zzd2l0Y2hfZ2V0X3dvcmt0cmVlX2RhdGEpCiAgICAKICAgIGVjaG8gIiRyZXNvbHZlZCIKfQoKZnN3aXRjaCgpIHsKICAgIGxvY2FsIHRhcmdldD0kMQogICAgaWYgW1sgLXogIiRGTFVUVEVSX1JFUE9fUk9PVCIgXV07IHRoZW4KICAgICAgICBlY2hvICLinYwgRXJyb3I6IEZMVVRURVJfUkVQT19ST09UIGlzIG5vdCBzZXQuIENvdWxkIG5vdCBkZXRlY3QgcmVwbyByb290LiIKICAgICAgICByZXR1cm4gMQogICAgZmkKICAgIAogICAgIyBSZXNvbHZlIHRhcmdldCB0byBkaXJlY3RvcnkgKHJlbGF0aXZlIHBhdGggZnJvbSByb290LCBvciAiLiIpCiAgICBsb2NhbCBkaXJfbmFtZT0kKF9mc3dpdGNoX3Jlc29sdmUgIiR0YXJnZXQiKQogICAgCiAgICBpZiBbWyAteiAiJGRpcl9uYW1lIiBdXTsgdGhlbgogICAgICAgIGVjaG8gIuKdjCBJbnZhbGlkIHRhcmdldDogJyR0YXJnZXQnIgogICAgICAgIGVjaG8gIiAgIEF2YWlsYWJsZSBjb250ZXh0czoiCiAgICAgICAgX2Zzd2l0Y2hfZ2V0X3dvcmt0cmVlX2RhdGEgfCB3aGlsZSByZWFkIC1yIHd0X3BhdGggaGFzaCBicmFuY2hfaW5mbyByZXN0OyBkbwogICAgICAgICAgICAgbG9jYWwgZD0iJHt3dF9wYXRoIyRGTFVUVEVSX1JFUE9fUk9PVC99IgogICAgICAgICAgICAgaWYgW1sgIiRkIiA9PSAiJHd0X3BhdGgiICYmICIkd3RfcGF0aCIgPT0gIiRGTFVUVEVSX1JFUE9fUk9PVCIgXV07IHRoZW4KICAgICAgICAgICAgICAgICBkPSIuIgogICAgICAgICAgICAgZmkKICAgICAgICAgICAgIGxvY2FsIGI9IiR7YnJhbmNoX2luZm8jXFt9IgogICAgICAgICAgICAgYj0iJHtiJVxdfSIKICAgICAgICAgICAgIGVjaG8gIiAgIC0gJGQgKCRiKSIKICAgICAgICBkb25lCiAgICAgICAgcmV0dXJuIDEKICAgIGVsc2UKICAgICAgICAjIFRhcmdldCByZXNvbHZlZCwgY2hlY2sgYmluCiAgICAgICAgbG9jYWwgZnVsbF9iaW5fcGF0aD0iJEZMVVRURVJfUkVQT19ST09ULyRkaXJfbmFtZS9iaW4iCiAgICAgICAgaWYgW1sgIiRkaXJfbmFtZSIgPT0gIi4iIF1dOyB0aGVuCiAgICAgICAgICAgIGZ1bGxfYmluX3BhdGg9IiRGTFVUVEVSX1JFUE9fUk9PVC9iaW4iCiAgICAgICAgZmkKICAgIAogICAgICAgIGlmIFtbICEgLWQgIiRmdWxsX2Jpbl9wYXRoIiBdXTsgdGhlbgogICAgICAgICAgICBlY2hvICLinYwgRXJyb3I6IEZsdXR0ZXIgYmluIGRpcmVjdG9yeSBub3QgZm91bmQgYXQ6IgogICAgICAgICAgICBlY2hvICIgICAkZnVsbF9iaW5fcGF0aCIKICAgICAgICAgICAgcmV0dXJuIDEKICAgICAgICBlbHNlCiAgICAgICAgICAgICMgMi4gQ2xlYW4gUEFUSAogICAgICAgICAgICAjIFdlIHJlbW92ZSBhbnkgcGF0aCBjb250YWluaW5nIHRoZSBGTFVUVEVSX1JFUE9fUk9PVCB0byBhdm9pZCBjb25mbGljdHMKICAgICAgICAgICAgIyBUaGlzIHByZXZlbnRzIGhhdmluZyBib3RoICdtYXN0ZXInIGFuZCAnc3RhYmxlJyBpbiBQQVRIIGF0IHRoZSBzYW1lIHRpbWUKICAgICAgICAgICAgIyBVc2UgLUYgdG8gZW5zdXJlIGZpeGVkIHN0cmluZyBtYXRjaGluZyAobm8gcmVnZXgpCiAgICAgICAgICAgIGxvY2FsIG5ld19wYXRoPSQoZWNobyAiJFBBVEgiIHwgdHIgJzonICdcbicgfCBncmVwIC12RiAiJEZMVVRURVJfUkVQT19ST09UIiB8IHRyICdcbicgJzonIHwgc2VkICdzLzokLy8nKQogICAgICAgIAogICAgICAgICAgICAjIDMuIFVwZGF0ZSBQQVRICiAgICAgICAgICAgICMgUHJlcGVuZCB0aGUgbmV3IHRhcmdldCdzIGJpbiBkaXJlY3RvcnkKICAgICAgICAgICAgZXhwb3J0IFBBVEg9IiRmdWxsX2Jpbl9wYXRoOiRuZXdfcGF0aCIKICAgICAgICAKICAgICAgICAgICAgIyA0LiBWZXJpZnkKICAgICAgICAgICAgZWNobyAi4pyFIFN3aXRjaGVkIHRvIEZsdXR0ZXIgJGRpcl9uYW1lIgogICAgICAgICAgICBlY2hvICIgICBGbHV0dGVyOiAkKHdoaWNoIGZsdXR0ZXIpIgogICAgICAgICAgICBlY2hvICIgICBEYXJ0OiAgICAkKHdoaWNoIGRhcnQpIgogICAgICAgIGZpCiAgICBmaQp9CgpfZnN3aXRjaF9jb21wbGV0aW9uKCkgewogICAgbG9jYWwgY3VyPSIke0NPTVBfV09SRFNbQ09NUF9DV09SRF19IgogICAgbG9jYWwgdGFyZ2V0cz0oKQogICAgCiAgICB3aGlsZSByZWFkIC1yIHd0X3BhdGggaGFzaCBicmFuY2hfaW5mbyByZXN0OyBkbwogICAgICAgIGxvY2FsIGRpcl9uYW1lPSIke3d0X3BhdGgjJEZMVVRURVJfUkVQT19ST09UL30iCiAgICAgICAgaWYgW1sgIiRkaXJfbmFtZSIgPT0gIiR3dF9wYXRoIiAmJiAiJHd0X3BhdGgiID09ICIkRkxVVFRFUl9SRVBPX1JPT1QiIF1dOyB0aGVuCiAgICAgICAgICAgIGRpcl9uYW1lPSIke3d0X3BhdGgjIyovfSIKICAgICAgICBmaQogICAgICAgIGxvY2FsIGJyYW5jaF9uYW1lPSIke2JyYW5jaF9pbmZvI1xbfSIKICAgICAgICBicmFuY2hfbmFtZT0iJHticmFuY2hfbmFtZSVcXX0iCiAgICAgICAgCiAgICAgICAgdGFyZ2V0cys9KCIkZGlyX25hbWUiKQogICAgICAgIGlmIFsgLW4gIiRicmFuY2hfbmFtZSIgXTsgdGhlbgogICAgICAgICAgICB0YXJnZXRzKz0oIiRicmFuY2hfbmFtZSIpCiAgICAgICAgZmkKICAgIGRvbmUgPCA8KF9mc3dpdGNoX2dldF93b3JrdHJlZV9kYXRhKQogICAgCiAgICAjIERlZHVwbGljYXRlIGFuZCBnZW5lcmF0ZSBjb21wbGV0aW9uCiAgICBsb2NhbCB1bmlxdWVfdGFyZ2V0cz0kKGVjaG8gIiR7dGFyZ2V0c1tAXX0iIHwgdHIgJyAnICdcbicgfCBzb3J0IC11IHwgdHIgJ1xuJyAnICcpCiAgICBDT01QUkVQTFk9KCAkKGNvbXBnZW4gLVcgIiR7dW5pcXVlX3RhcmdldHN9IiAtLSAke2N1cn0pICkKfQpjb21wbGV0ZSAtRiBfZnN3aXRjaF9jb21wbGV0aW9uIGZzd2l0Y2gKCiMgT3B0aW9uYWw6IERlZmF1bHQgdG8gbWFzdGVyIG9uIGxvYWQgaWYgbm8gZmx1dHRlciBpcyBmb3VuZAppZiAhIGNvbW1hbmQgLXYgZmx1dHRlciAmPiAvZGV2L251bGw7IHRoZW4KICAgIGZzd2l0Y2ggbWFzdGVyCiAgICBlY2hvICLihLnvuI8gIEZsdXR0ZXIgZW52aXJvbm1lbnQgbG9hZGVkLiBVc2UgJ2Zzd2l0Y2ggc3RhYmxlJyBvciAnZnN3aXRjaCBtYXN0ZXInIHRvIGFjdGl2YXRlLiIKZmkK"
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
echo ""
echo "Want to create a new worktree?"
echo "   $ git worktree add my_feature"
echo "------------------------------------------------------"
