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
SWITCH_FILE="$ROOT_PATH/env_switch.sh"

PAYLOAD="IyBTb3VyY2UgdGhpcyBmaWxlIGluIHlvdXIgLmJhc2hyYyBvciAuenNocmMKIyBVc2FnZTogc291cmNlICRTV0lUQ0hfRklMRQoKIyBBdXRvLWRldGVjdCB0aGUgcmVwbyByb290IGJhc2VkIG9uIHRoaXMgc2NyaXB0J3MgbG9jYXRpb24KaWYgWyAtbiAiJEJBU0hfU09VUkNFIiBdOyB0aGVuCiAgICBfU0NSSVBUX1BBVEg9IiR7QkFTSF9TT1VSQ0VbMF19IgplbGlmIFsgLW4gIiRaU0hfVkVSU0lPTiIgXTsgdGhlbgogICAgX1NDUklQVF9QQVRIPSIkeyglKTotJXh9IgplbHNlCiAgICBfU0NSSVBUX1BBVEg9IiQwIgpmaQoKZXhwb3J0IEZMVVRURVJfUkVQT19ST09UPSIkKGNkICIkKGRpcm5hbWUgIiRfU0NSSVBUX1BBVEgiKSIgPi9kZXYvbnVsbCAyPiYxICYmIHB3ZCkiCgpfZnN3aXRjaF9nZXRfd29ya3RyZWVfZGF0YSgpIHsKICAgIGlmIGNvbW1hbmQgLXYgZ2l0ICY+IC9kZXYvbnVsbCAmJiBbIC1kICIkRkxVVFRFUl9SRVBPX1JPT1QiIF07IHRoZW4KICAgICAgICBnaXQgLUMgIiRGTFVUVEVSX1JFUE9fUk9PVCIgd29ya3RyZWUgbGlzdCAyPi9kZXYvbnVsbCB8IGdyZXAgLXYgIihiYXJlKSIKICAgIGZpCn0KCl9mc3dpdGNoX3Jlc29sdmUoKSB7CiAgICBsb2NhbCB0YXJnZXQ9JDEKICAgIGxvY2FsIHJlc29sdmVkPSIiCiAgICAKICAgIHdoaWxlIHJlYWQgLXIgcGF0aCBoYXNoIGJyYW5jaF9pbmZvIHJlc3Q7IGRvCiAgICAgICAgbG9jYWwgcmVsX3BhdGg9IiR7cGF0aCMkRkxVVFRFUl9SRVBPX1JPT1QvfSIKICAgICAgICBsb2NhbCBpc19yb290PTAKICAgICAgICBpZiBbWyAiJHJlbF9wYXRoIiA9PSAiJHBhdGgiICYmICIkcGF0aCIgPT0gIiRGTFVUVEVSX1JFUE9fUk9PVCIgXV07IHRoZW4KICAgICAgICAgICAgcmVsX3BhdGg9Ii4iCiAgICAgICAgICAgIGlzX3Jvb3Q9MQogICAgICAgIGZpCgogICAgICAgIGxvY2FsIGJyYW5jaF9uYW1lPSIke2JyYW5jaF9pbmZvI1xbfSIKICAgICAgICBicmFuY2hfbmFtZT0iJHticmFuY2hfbmFtZSVcXX0iCiAgICAgICAgCiAgICAgICAgaWYgW1sgIiR0YXJnZXQiID09ICIkcmVsX3BhdGgiIF1dIHx8IFtbICIkdGFyZ2V0IiA9PSAiJGJyYW5jaF9uYW1lIiBdXTsgdGhlbgogICAgICAgICAgICByZXNvbHZlZD0iJHJlbF9wYXRoIgogICAgICAgICAgICBicmVhawogICAgICAgIGZpCiAgICAgICAgCiAgICAgICAgIyBBbGxvdyBtYXRjaGluZyBieSByb290IGRpcmVjdG9yeSBuYW1lCiAgICAgICAgaWYgW1sgJGlzX3Jvb3QgLWVxIDEgXV07IHRoZW4KICAgICAgICAgICAgIGxvY2FsIHJvb3RfbmFtZT0iJHtwYXRoIyMqL30iCiAgICAgICAgICAgICBpZiBbWyAiJHRhcmdldCIgPT0gIiRyb290X25hbWUiIF1dOyB0aGVuCiAgICAgICAgICAgICAgICAgIHJlc29sdmVkPSIkcmVsX3BhdGgiCiAgICAgICAgICAgICAgICAgIGJyZWFrCiAgICAgICAgICAgICBmaQogICAgICAgIGZpCiAgICBkb25lIDwgPChfZnN3aXRjaF9nZXRfd29ya3RyZWVfZGF0YSkKICAgIAogICAgZWNobyAiJHJlc29sdmVkIgp9Cgpmc3dpdGNoKCkgewogICAgbG9jYWwgdGFyZ2V0PSQxCiAgICAKICAgICMgUmVzb2x2ZSB0YXJnZXQgdG8gZGlyZWN0b3J5IChyZWxhdGl2ZSBwYXRoIGZyb20gcm9vdCwgb3IgIi4iKQogICAgbG9jYWwgZGlyX25hbWU9JChfZnN3aXRjaF9yZXNvbHZlICIkdGFyZ2V0IikKICAgIAogICAgaWYgW1sgLXogIiRkaXJfbmFtZSIgXV07IHRoZW4KICAgICAgICBlY2hvICLinYwgSW52YWxpZCB0YXJnZXQ6ICckdGFyZ2V0JyIKICAgICAgICBlY2hvICIgICBBdmFpbGFibGUgY29udGV4dHM6IgogICAgICAgIF9mc3dpdGNoX2dldF93b3JrdHJlZV9kYXRhIHwgd2hpbGUgcmVhZCAtciBwYXRoIGhhc2ggYnJhbmNoX2luZm8gcmVzdDsgZG8KICAgICAgICAgICAgIGxvY2FsIGQ9IiR7cGF0aCMkRkxVVFRFUl9SRVBPX1JPT1QvfSIKICAgICAgICAgICAgIGlmIFtbICIkZCIgPT0gIiRwYXRoIiAmJiAiJHBhdGgiID09ICIkRkxVVFRFUl9SRVBPX1JPT1QiIF1dOyB0aGVuCiAgICAgICAgICAgICAgICAgZD0iLiIKICAgICAgICAgICAgIGZpCiAgICAgICAgICAgICBsb2NhbCBiPSIke2JyYW5jaF9pbmZvI1xbfSIKICAgICAgICAgICAgIGI9IiR7YiVcXX0iCiAgICAgICAgICAgICBlY2hvICIgICAtICRkICgkYikiCiAgICAgICAgZG9uZQogICAgICAgIHJldHVybiAxCiAgICBmaQogICAgCiAgICAjIENoZWNrIGlmIHRhcmdldCBiaW4gZXhpc3RzIEJFRk9SRSBkZXN0cm95aW5nIFBBVEgKICAgIGxvY2FsIGZ1bGxfYmluX3BhdGg9IiRGTFVUVEVSX1JFUE9fUk9PVC8kZGlyX25hbWUvYmluIgogICAgIyBOb3JtYWxpemUgcGF0aCBzbGlnaHRseSBmb3IgZGlzcGxheS9jaGVjayAocmVtb3ZlIC8uLykKICAgIGlmIFtbICIkZGlyX25hbWUiID09ICIuIiBdXTsgdGhlbgogICAgICAgIGZ1bGxfYmluX3BhdGg9IiRGTFVUVEVSX1JFUE9fUk9PVC9iaW4iCiAgICBmaQoKICAgIGlmIFtbICEgLWQgIiRmdWxsX2Jpbl9wYXRoIiBdXTsgdGhlbgogICAgICAgIGVjaG8gIuKdjCBFcnJvcjogRmx1dHRlciBiaW4gZGlyZWN0b3J5IG5vdCBmb3VuZCBhdDoiCiAgICAgICAgZWNobyAiICAgJGZ1bGxfYmluX3BhdGgiCiAgICAgICAgcmV0dXJuIDEKICAgIGZpCgogICAgIyAyLiBDbGVhbiBQQVRICiAgICAjIFdlIHJlbW92ZSBhbnkgcGF0aCBjb250YWluaW5nIHRoZSBGTFVUVEVSX1JFUE9fUk9PVCB0byBhdm9pZCBjb25mbGljdHMKICAgICMgVGhpcyBwcmV2ZW50cyBoYXZpbmcgYm90aCAnbWFzdGVyJyBhbmQgJ3N0YWJsZScgaW4gUEFUSCBhdCB0aGUgc2FtZSB0aW1lCiAgICBsb2NhbCBuZXdfcGF0aD0kKGVjaG8gIiRQQVRIIiB8IHRyICc6JyAnXG4nIHwgZ3JlcCAtdiAiJEZMVVRURVJfUkVQT19ST09UIiB8IHRyICdcbicgJzonIHwgc2VkICdzLzokLy8nKQoKICAgICMgMy4gVXBkYXRlIFBBVEgKICAgICMgUHJlcGVuZCB0aGUgbmV3IHRhcmdldCdzIGJpbiBkaXJlY3RvcnkKICAgIGV4cG9ydCBQQVRIPSIkZnVsbF9iaW5fcGF0aDokbmV3X3BhdGgiCgogICAgIyA0LiBWZXJpZnkKICAgIGVjaG8gIuKchSBTd2l0Y2hlZCB0byBGbHV0dGVyICRkaXJfbmFtZSIKICAgIGVjaG8gIiAgIEZsdXR0ZXI6ICQod2hpY2ggZmx1dHRlcikiCiAgICBlY2hvICIgICBEYXJ0OiAgICAkKHdoaWNoIGRhcnQpIgp9CgpfZnN3aXRjaF9jb21wbGV0aW9uKCkgewogICAgbG9jYWwgY3VyPSIke0NPTVBfV09SRFNbQ09NUF9DV09SRF19IgogICAgbG9jYWwgdGFyZ2V0cz0oKQogICAgCiAgICB3aGlsZSByZWFkIC1yIHBhdGggaGFzaCBicmFuY2hfaW5mbyByZXN0OyBkbwogICAgICAgIGxvY2FsIGRpcl9uYW1lPSIke3BhdGgjJEZMVVRURVJfUkVQT19ST09UL30iCiAgICAgICAgaWYgW1sgIiRkaXJfbmFtZSIgPT0gIiRwYXRoIiAmJiAiJHBhdGgiID09ICIkRkxVVFRFUl9SRVBPX1JPT1QiIF1dOyB0aGVuCiAgICAgICAgICAgIGRpcl9uYW1lPSIke3BhdGgjIyovfSIKICAgICAgICBmaQogICAgICAgIGxvY2FsIGJyYW5jaF9uYW1lPSIke2JyYW5jaF9pbmZvI1xbfSIKICAgICAgICBicmFuY2hfbmFtZT0iJHticmFuY2hfbmFtZSVcXX0iCiAgICAgICAgCiAgICAgICAgdGFyZ2V0cys9KCIkZGlyX25hbWUiKQogICAgICAgIGlmIFsgLW4gIiRicmFuY2hfbmFtZSIgXTsgdGhlbgogICAgICAgICAgICB0YXJnZXRzKz0oIiRicmFuY2hfbmFtZSIpCiAgICAgICAgZmkKICAgIGRvbmUgPCA8KF9mc3dpdGNoX2dldF93b3JrdHJlZV9kYXRhKQogICAgCiAgICAjIERlZHVwbGljYXRlIGFuZCBnZW5lcmF0ZSBjb21wbGV0aW9uCiAgICBsb2NhbCB1bmlxdWVfdGFyZ2V0cz0kKGVjaG8gIiR7dGFyZ2V0c1tAXX0iIHwgdHIgJyAnICdcbicgfCBzb3J0IC11IHwgdHIgJ1xuJyAnICcpCiAgICBDT01QUkVQTFk9KCAkKGNvbXBnZW4gLVcgIiR7dW5pcXVlX3RhcmdldHN9IiAtLSAke2N1cn0pICkKfQpjb21wbGV0ZSAtRiBfZnN3aXRjaF9jb21wbGV0aW9uIGZzd2l0Y2gKCiMgT3B0aW9uYWw6IERlZmF1bHQgdG8gbWFzdGVyIG9uIGxvYWQgaWYgbm8gZmx1dHRlciBpcyBmb3VuZAppZiAhIGNvbW1hbmQgLXYgZmx1dHRlciAmPiAvZGV2L251bGw7IHRoZW4KICAgIGZzd2l0Y2ggbWFzdGVyCiAgICBlY2hvICLihLnvuI8gIEZsdXR0ZXIgZW52aXJvbm1lbnQgbG9hZGVkLiBVc2UgJ2Zzd2l0Y2ggc3RhYmxlJyBvciAnZnN3aXRjaCBtYXN0ZXInIHRvIGFjdGl2YXRlLiIKZmkK"
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
