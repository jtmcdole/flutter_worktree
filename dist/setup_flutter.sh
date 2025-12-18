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
echo "   Origin: '$OriginUrl'"

git clone --bare "$ORIGIN_URL" .bare
echo "gitdir: ./.bare" > .git

# 3. Configure Remotes
echo "⚙️  Configuring remotes..."
git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
git remote add upstream "$UPSTREAM_URL"
git config remote.upstream.fetch "+refs/heads/*:refs/remotes/upstream/*"

# 4. Fetch tags / branches
echo "⬇️  Fetching everything (--all --tags --prune)..."
git fetch --all --tags --prune

# --- Setup MASTER ---
echo "🌲 Creating 'master' worktree (tracking upstream/master)..."
git worktree add -B master master --track upstream/master

# --- Setup STABLE ---
if [ -z "$SETUP_STABLE" ]; then
    read -p "Do you want to setup the 'stable' worktree? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        SETUP_STABLE=true
    else
        SETUP_STABLE=false
    fi
fi

if [ "$SETUP_STABLE" = true ] || [[ "$SETUP_STABLE" =~ ^[Yy] ]]; then
    SETUP_STABLE=true
    echo "🌲 Creating 'stable' worktree (based on upstream/$REF_STABLE)..."
    # We create a local branch named 'stable' based on the upstream ref
    git worktree add -B stable stable --track upstream/"$REF_STABLE"
else
    SETUP_STABLE=false
fi

# 5. Pre-load Artifacts
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

# 6. Generate The Switcher Script
echo "🔗 Generating context switcher..."
SWITCH_FILE="$ROOT_PATH/fswitch.sh"

PAYLOAD="IyBTb3VyY2UgdGhpcyBmaWxlIGluIHlvdXIgLmJhc2hyYyBvciAuenNocmMKIyBVc2FnZTogc291cmNlICRTV0lUQ0hfRklMRQoKIyBBdXRvLWRldGVjdCB0aGUgcmVwbyByb290IGJhc2VkIG9uIHRoaXMgc2NyaXB0J3MgbG9jYXRpb24KaWYgWyAtbiAiJEJBU0hfU09VUkNFIiBdOyB0aGVuCiAgICBfU0NSSVBUX1BBVEg9IiR7QkFTSF9TT1VSQ0VbMF19IgplbGlmIFsgLW4gIiRaU0hfVkVSU0lPTiIgXTsgdGhlbgogICAgX1NDUklQVF9QQVRIPSIkeyglKTotJXh9IgplbHNlCiAgICBfU0NSSVBUX1BBVEg9IiQwIgpmaQoKRkxVVFRFUl9SRVBPX1JPT1Q9IiQoY2QgIiQoZGlybmFtZSAiJF9TQ1JJUFRfUEFUSCIpIiA+L2Rldi9udWxsIDI+JjEgJiYgcHdkKSIKCl9mc3dpdGNoX2dldF93b3JrdHJlZV9kYXRhKCkgewogICAgaWYgY29tbWFuZCAtdiBnaXQgJj4gL2Rldi9udWxsICYmIFsgLWQgIiRGTFVUVEVSX1JFUE9fUk9PVCIgXTsgdGhlbgogICAgICAgIGdpdCAtQyAiJEZMVVRURVJfUkVQT19ST09UIiB3b3JrdHJlZSBsaXN0IDI+L2Rldi9udWxsIHwgZ3JlcCAtdiAiKGJhcmUpIgogICAgZmkKfQoKX2Zzd2l0Y2hfcmVzb2x2ZSgpIHsKICAgIGxvY2FsIHRhcmdldD0kMQogICAgaWYgW1sgLXogIiRGTFVUVEVSX1JFUE9fUk9PVCIgXV07IHRoZW4KICAgICAgICByZXR1cm4KICAgIGZpCiAgICBsb2NhbCByZXNvbHZlZD0iIgogICAgCiAgICB3aGlsZSByZWFkIC1yIHd0X3BhdGggaGFzaCBicmFuY2hfaW5mbyByZXN0OyBkbwogICAgICAgIGxvY2FsIHJlbF9wYXRoPSIke3d0X3BhdGgjJEZMVVRURVJfUkVQT19ST09UL30iCiAgICAgICAgbG9jYWwgaXNfcm9vdD0wCiAgICAgICAgaWYgW1sgIiRyZWxfcGF0aCIgPT0gIiR3dF9wYXRoIiAmJiAiJHd0X3BhdGgiID09ICIkRkxVVFRFUl9SRVBPX1JPT1QiIF1dOyB0aGVuCiAgICAgICAgICAgIHJlbF9wYXRoPSIuIgogICAgICAgICAgICBpc19yb290PTEKICAgICAgICBmaQoKICAgICAgICBsb2NhbCBicmFuY2hfbmFtZT0iJHticmFuY2hfaW5mbyNcW30iCiAgICAgICAgYnJhbmNoX25hbWU9IiR7YnJhbmNoX25hbWUlXF19IgogICAgICAgIAogICAgICAgIGlmIFtbICIkdGFyZ2V0IiA9PSAiJHJlbF9wYXRoIiBdXSB8fCBbWyAiJHRhcmdldCIgPT0gIiRicmFuY2hfbmFtZSIgXV07IHRoZW4KICAgICAgICAgICAgcmVzb2x2ZWQ9IiRyZWxfcGF0aCIKICAgICAgICAgICAgYnJlYWsKICAgICAgICBmaQogICAgZG9uZSA8IDwoX2Zzd2l0Y2hfZ2V0X3dvcmt0cmVlX2RhdGEpCiAgICAKICAgIGVjaG8gIiRyZXNvbHZlZCIKfQoKZnN3aXRjaCgpIHsKICAgIGxvY2FsIHRhcmdldD0kMQogICAgaWYgW1sgLXogIiRGTFVUVEVSX1JFUE9fUk9PVCIgXV07IHRoZW4KICAgICAgICBlY2hvICLinYwgRXJyb3I6IEZMVVRURVJfUkVQT19ST09UIGlzIG5vdCBzZXQuIENvdWxkIG5vdCBkZXRlY3QgcmVwbyByb290LiIKICAgICAgICByZXR1cm4gMQogICAgZmkKICAgIAogICAgIyBSZXNvbHZlIHRhcmdldCB0byBkaXJlY3RvcnkgKHJlbGF0aXZlIHBhdGggZnJvbSByb290LCBvciAiLiIpCiAgICBsb2NhbCBkaXJfbmFtZT0kKF9mc3dpdGNoX3Jlc29sdmUgIiR0YXJnZXQiKQogICAgCiAgICBpZiBbWyAteiAiJGRpcl9uYW1lIiBdXTsgdGhlbgogICAgICAgIGVjaG8gIuKdjCBJbnZhbGlkIHRhcmdldDogJyR0YXJnZXQnIgogICAgICAgIGVjaG8gIiAgIEF2YWlsYWJsZSBjb250ZXh0czoiCiAgICAgICAgX2Zzd2l0Y2hfZ2V0X3dvcmt0cmVlX2RhdGEgfCB3aGlsZSByZWFkIC1yIHd0X3BhdGggaGFzaCBicmFuY2hfaW5mbyByZXN0OyBkbwogICAgICAgICAgICAgbG9jYWwgZD0iJHt3dF9wYXRoIyRGTFVUVEVSX1JFUE9fUk9PVC99IgogICAgICAgICAgICAgaWYgW1sgIiRkIiA9PSAiJHd0X3BhdGgiICYmICIkd3RfcGF0aCIgPT0gIiRGTFVUVEVSX1JFUE9fUk9PVCIgXV07IHRoZW4KICAgICAgICAgICAgICAgICBkPSIuIgogICAgICAgICAgICAgZmkKICAgICAgICAgICAgIGxvY2FsIGI9IiR7YnJhbmNoX2luZm8jXFt9IgogICAgICAgICAgICAgYj0iJHtiJVxdfSIKICAgICAgICAgICAgIGVjaG8gIiAgIC0gJGQgKCRiKSIKICAgICAgICBkb25lCiAgICAgICAgcmV0dXJuIDEKICAgIGVsc2UKICAgICAgICAjIFRhcmdldCByZXNvbHZlZCwgY2hlY2sgYmluCiAgICAgICAgbG9jYWwgZnVsbF9iaW5fcGF0aD0iJEZMVVRURVJfUkVQT19ST09ULyRkaXJfbmFtZS9iaW4iCiAgICAgICAgbG9jYWwgZXRfYmluX3BhdGg9IiRGTFVUVEVSX1JFUE9fUk9PVC8kZGlyX25hbWUvZW5naW5lL3NyYy9mbHV0dGVyL2JpbiIKCiAgICAgICAgaWYgW1sgIiRkaXJfbmFtZSIgPT0gIi4iIF1dOyB0aGVuCiAgICAgICAgICAgIGZ1bGxfYmluX3BhdGg9IiRGTFVUVEVSX1JFUE9fUk9PVC9iaW4iCiAgICAgICAgICAgIGV0X2Jpbl9wYXRoPSIkRkxVVFRFUl9SRVBPX1JPT1QvZW5naW5lL3NyYy9mbHV0dGVyL2JpbiIKICAgICAgICBmaQogICAgCiAgICAgICAgaWYgW1sgISAtZCAiJGZ1bGxfYmluX3BhdGgiIF1dOyB0aGVuCiAgICAgICAgICAgIGVjaG8gIuKdjCBFcnJvcjogRmx1dHRlciBiaW4gZGlyZWN0b3J5IG5vdCBmb3VuZCBhdDoiCiAgICAgICAgICAgIGVjaG8gIiAgICRmdWxsX2Jpbl9wYXRoIgogICAgICAgICAgICByZXR1cm4gMQogICAgICAgIGVsc2UKICAgICAgICAgICAgIyAyLiBDbGVhbiBQQVRICiAgICAgICAgICAgICMgV2UgcmVtb3ZlIGFueSBwYXRoIGNvbnRhaW5pbmcgdGhlIEZMVVRURVJfUkVQT19ST09UIHRvIGF2b2lkIGNvbmZsaWN0cwogICAgICAgICAgICAjIFRoaXMgcHJldmVudHMgaGF2aW5nIGJvdGggJ21hc3RlcicgYW5kICdzdGFibGUnIGluIFBBVEggYXQgdGhlIHNhbWUgdGltZQogICAgICAgICAgICAjIFVzZSAtRiB0byBlbnN1cmUgZml4ZWQgc3RyaW5nIG1hdGNoaW5nIChubyByZWdleCkKICAgICAgICAgICAgbG9jYWwgbmV3X3BhdGg9JChlY2hvICIkUEFUSCIgfCB0ciAnOicgJ1xuJyB8IGdyZXAgLXZGICIkRkxVVFRFUl9SRVBPX1JPT1QiIHwgdHIgJ1xuJyAnOicgfCBzZWQgJ3MvOiQvLycpCiAgICAgICAgCiAgICAgICAgICAgICMgMy4gVXBkYXRlIFBBVEgKICAgICAgICAgICAgIyBQcmVwZW5kIHRoZSBuZXcgdGFyZ2V0J3MgYmluIGRpcmVjdG9yeSAoYW5kIGV0IHBhdGggaWYgaXQgZXhpc3RzKQogICAgICAgICAgICBpZiBbWyAtZCAiJGV0X2Jpbl9wYXRoIiBdXTsgdGhlbgogICAgICAgICAgICAgICAgZXhwb3J0IFBBVEg9IiRmdWxsX2Jpbl9wYXRoOiRldF9iaW5fcGF0aDokbmV3X3BhdGgiCiAgICAgICAgICAgIGVsc2UKICAgICAgICAgICAgICAgIGV4cG9ydCBQQVRIPSIkZnVsbF9iaW5fcGF0aDokbmV3X3BhdGgiCiAgICAgICAgICAgIGZpCiAgICAgICAgCiAgICAgICAgICAgICMgNC4gVmVyaWZ5CiAgICAgICAgICAgIGVjaG8gIuKchSBTd2l0Y2hlZCB0byBGbHV0dGVyICRkaXJfbmFtZSIKICAgICAgICAgICAgZWNobyAiICAgRmx1dHRlcjogJCh3aGljaCBmbHV0dGVyKSIKICAgICAgICAgICAgZWNobyAiICAgRGFydDogICAgJCh3aGljaCBkYXJ0KSIKICAgICAgICBmaQogICAgZmkKfQoKX2Zzd2l0Y2hfY29tcGxldGlvbigpIHsKICAgIGxvY2FsIGN1cj0iJHtDT01QX1dPUkRTW0NPTVBfQ1dPUkRdfSIKICAgIGxvY2FsIHRhcmdldHM9KCkKICAgIAogICAgd2hpbGUgcmVhZCAtciB3dF9wYXRoIGhhc2ggYnJhbmNoX2luZm8gcmVzdDsgZG8KICAgICAgICBsb2NhbCBkaXJfbmFtZT0iJHt3dF9wYXRoIyRGTFVUVEVSX1JFUE9fUk9PVC99IgogICAgICAgIGlmIFtbICIkZGlyX25hbWUiID09ICIkd3RfcGF0aCIgJiYgIiR3dF9wYXRoIiA9PSAiJEZMVVRURVJfUkVQT19ST09UIiBdXTsgdGhlbgogICAgICAgICAgICBkaXJfbmFtZT0iJHt3dF9wYXRoIyMqL30iCiAgICAgICAgZmkKICAgICAgICBsb2NhbCBicmFuY2hfbmFtZT0iJHticmFuY2hfaW5mbyNcW30iCiAgICAgICAgYnJhbmNoX25hbWU9IiR7YnJhbmNoX25hbWUlXF19IgogICAgICAgIAogICAgICAgIHRhcmdldHMrPSgiJGRpcl9uYW1lIikKICAgICAgICBpZiBbIC1uICIkYnJhbmNoX25hbWUiIF07IHRoZW4KICAgICAgICAgICAgdGFyZ2V0cys9KCIkYnJhbmNoX25hbWUiKQogICAgICAgIGZpCiAgICBkb25lIDwgPChfZnN3aXRjaF9nZXRfd29ya3RyZWVfZGF0YSkKICAgIAogICAgIyBEZWR1cGxpY2F0ZSBhbmQgZ2VuZXJhdGUgY29tcGxldGlvbgogICAgbG9jYWwgdW5pcXVlX3RhcmdldHM9JChlY2hvICIke3RhcmdldHNbQF19IiB8IHRyICcgJyAnXG4nIHwgc29ydCAtdSB8IHRyICdcbicgJyAnKQogICAgQ09NUFJFUExZPSggJChjb21wZ2VuIC1XICIke3VuaXF1ZV90YXJnZXRzfSIgLS0gJHtjdXJ9KSApCn0KY29tcGxldGUgLUYgX2Zzd2l0Y2hfY29tcGxldGlvbiBmc3dpdGNoCgojIE9wdGlvbmFsOiBEZWZhdWx0IHRvIG1hc3RlciBvbiBsb2FkIGlmIG5vIGZsdXR0ZXIgaXMgZm91bmQKaWYgISBjb21tYW5kIC12IGZsdXR0ZXIgJj4gL2Rldi9udWxsOyB0aGVuCiAgICBmc3dpdGNoIG1hc3RlcgogICAgZWNobyAi4oS577iPICBGbHV0dGVyIGVudmlyb25tZW50IGxvYWRlZC4gVXNlICdmc3dpdGNoIHN0YWJsZScgb3IgJ2Zzd2l0Y2ggbWFzdGVyJyB0byBhY3RpdmF0ZS4iCmZpCg=="
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
