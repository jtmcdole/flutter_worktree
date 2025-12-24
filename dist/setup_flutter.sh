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

PAYLOAD="IyBTb3VyY2UgdGhpcyBmaWxlIGluIHlvdXIgLmJhc2hyYyBvciAuenNocmMKIyBVc2FnZTogc291cmNlICRTV0lUQ0hfRklMRQoKIyBBdXRvLWRldGVjdCB0aGUgcmVwbyByb290IGJhc2VkIG9uIHRoaXMgc2NyaXB0J3MgbG9jYXRpb24KaWYgWyAtbiAiJEJBU0hfU09VUkNFIiBdOyB0aGVuCiAgICBfU0NSSVBUX1BBVEg9IiR7QkFTSF9TT1VSQ0VbMF19IgplbGlmIFsgLW4gIiRaU0hfVkVSU0lPTiIgXTsgdGhlbgogICAgX1NDUklQVF9QQVRIPSIkeyglKTotJXh9IgplbHNlCiAgICBfU0NSSVBUX1BBVEg9IiQwIgpmaQoKRkxVVFRFUl9SRVBPX1JPT1Q9IiQoY2QgIiQoZGlybmFtZSAiJF9TQ1JJUFRfUEFUSCIpIiA+L2Rldi9udWxsIDI+JjEgJiYgcHdkKSIKCl9mc3dpdGNoX2dldF93b3JrdHJlZV9kYXRhKCkgewogICAgaWYgY29tbWFuZCAtdiBnaXQgJj4gL2Rldi9udWxsICYmIFsgLWQgIiRGTFVUVEVSX1JFUE9fUk9PVCIgXTsgdGhlbgogICAgICAgIGdpdCAtQyAiJEZMVVRURVJfUkVQT19ST09UIiB3b3JrdHJlZSBsaXN0IDI+L2Rldi9udWxsIHwgZ3JlcCAtdiAiKGJhcmUpIgogICAgZmkKfQoKX2Zzd2l0Y2hfcmVzb2x2ZSgpIHsKICAgIGxvY2FsIHRhcmdldD0kMQogICAgaWYgW1sgLXogIiRGTFVUVEVSX1JFUE9fUk9PVCIgXV07IHRoZW4KICAgICAgICByZXR1cm4KICAgIGZpCiAgICBsb2NhbCByZXNvbHZlZD0iIgoKICAgIHdoaWxlIHJlYWQgLXIgd3RfcGF0aCBoYXNoIGJyYW5jaF9pbmZvIHJlc3Q7IGRvCiAgICAgICAgbG9jYWwgcmVsX3BhdGg9IiR7d3RfcGF0aCMkRkxVVFRFUl9SRVBPX1JPT1QvfSIKICAgICAgICBsb2NhbCBpc19yb290PTAKICAgICAgICBpZiBbWyAiJHJlbF9wYXRoIiA9PSAiJHd0X3BhdGgiICYmICIkd3RfcGF0aCIgPT0gIiRGTFVUVEVSX1JFUE9fUk9PVCIgXV07IHRoZW4KICAgICAgICAgICAgcmVsX3BhdGg9Ii4iCiAgICAgICAgICAgIGlzX3Jvb3Q9MQogICAgICAgIGZpCgogICAgICAgIGxvY2FsIGJyYW5jaF9uYW1lPSIke2JyYW5jaF9pbmZvI1xbfSIKICAgICAgICBicmFuY2hfbmFtZT0iJHticmFuY2hfbmFtZSVcXX0iCgogICAgICAgIGlmIFtbICIkdGFyZ2V0IiA9PSAiJHJlbF9wYXRoIiBdXSB8fCBbWyAiJHRhcmdldCIgPT0gIiRicmFuY2hfbmFtZSIgXV07IHRoZW4KICAgICAgICAgICAgcmVzb2x2ZWQ9IiRyZWxfcGF0aCIKICAgICAgICAgICAgYnJlYWsKICAgICAgICBmaQogICAgZG9uZSA8IDwoX2Zzd2l0Y2hfZ2V0X3dvcmt0cmVlX2RhdGEpCgogICAgZWNobyAiJHJlc29sdmVkIgp9Cgpmc3dpdGNoKCkgewogICAgbG9jYWwgdGFyZ2V0PSQxCiAgICBpZiBbWyAteiAiJEZMVVRURVJfUkVQT19ST09UIiBdXTsgdGhlbgogICAgICAgIGVjaG8gIuKdjCBFcnJvcjogRkxVVFRFUl9SRVBPX1JPT1QgaXMgbm90IHNldC4gQ291bGQgbm90IGRldGVjdCByZXBvIHJvb3QuIgogICAgICAgIHJldHVybiAxCiAgICBmaQoKICAgICMgUmVzb2x2ZSB0YXJnZXQgdG8gZGlyZWN0b3J5IChyZWxhdGl2ZSBwYXRoIGZyb20gcm9vdCwgb3IgIi4iKQogICAgbG9jYWwgZGlyX25hbWU9JChfZnN3aXRjaF9yZXNvbHZlICIkdGFyZ2V0IikKCiAgICBpZiBbWyAteiAiJGRpcl9uYW1lIiBdXTsgdGhlbgogICAgICAgIGVjaG8gIuKdjCBJbnZhbGlkIHRhcmdldDogJyR0YXJnZXQnIgogICAgICAgIGVjaG8gIiAgIEF2YWlsYWJsZSBjb250ZXh0czoiCiAgICAgICAgX2Zzd2l0Y2hfZ2V0X3dvcmt0cmVlX2RhdGEgfCB3aGlsZSByZWFkIC1yIHd0X3BhdGggaGFzaCBicmFuY2hfaW5mbyByZXN0OyBkbwogICAgICAgICAgICAgbG9jYWwgZD0iJHt3dF9wYXRoIyRGTFVUVEVSX1JFUE9fUk9PVC99IgogICAgICAgICAgICAgaWYgW1sgIiRkIiA9PSAiJHd0X3BhdGgiICYmICIkd3RfcGF0aCIgPT0gIiRGTFVUVEVSX1JFUE9fUk9PVCIgXV07IHRoZW4KICAgICAgICAgICAgICAgICBkPSIuIgogICAgICAgICAgICAgZmkKICAgICAgICAgICAgIGxvY2FsIGI9IiR7YnJhbmNoX2luZm8jXFt9IgogICAgICAgICAgICAgYj0iJHtiJVxdfSIKICAgICAgICAgICAgIGVjaG8gIiAgIC0gJGQgKCRiKSIKICAgICAgICBkb25lCiAgICAgICAgcmV0dXJuIDEKICAgIGVsc2UKICAgICAgICAjIFRhcmdldCByZXNvbHZlZCwgY2hlY2sgYmluCiAgICAgICAgbG9jYWwgZnVsbF9iaW5fcGF0aD0iJEZMVVRURVJfUkVQT19ST09ULyRkaXJfbmFtZS9iaW4iCiAgICAgICAgbG9jYWwgZXRfYmluX3BhdGg9IiRGTFVUVEVSX1JFUE9fUk9PVC8kZGlyX25hbWUvZW5naW5lL3NyYy9mbHV0dGVyL2JpbiIKCiAgICAgICAgaWYgW1sgIiRkaXJfbmFtZSIgPT0gIi4iIF1dOyB0aGVuCiAgICAgICAgICAgIGZ1bGxfYmluX3BhdGg9IiRGTFVUVEVSX1JFUE9fUk9PVC9iaW4iCiAgICAgICAgICAgIGV0X2Jpbl9wYXRoPSIkRkxVVFRFUl9SRVBPX1JPT1QvZW5naW5lL3NyYy9mbHV0dGVyL2JpbiIKICAgICAgICBmaQoKICAgICAgICBpZiBbWyAhIC1kICIkZnVsbF9iaW5fcGF0aCIgXV07IHRoZW4KICAgICAgICAgICAgZWNobyAi4p2MIEVycm9yOiBGbHV0dGVyIGJpbiBkaXJlY3Rvcnkgbm90IGZvdW5kIGF0OiIKICAgICAgICAgICAgZWNobyAiICAgJGZ1bGxfYmluX3BhdGgiCiAgICAgICAgICAgIHJldHVybiAxCiAgICAgICAgZWxzZQogICAgICAgICAgICAjIDIuIENsZWFuIFBBVEgKICAgICAgICAgICAgIyBXZSByZW1vdmUgYW55IHBhdGggY29udGFpbmluZyB0aGUgRkxVVFRFUl9SRVBPX1JPT1QgdG8gYXZvaWQgY29uZmxpY3RzCiAgICAgICAgICAgICMgVGhpcyBwcmV2ZW50cyBoYXZpbmcgYm90aCAnbWFzdGVyJyBhbmQgJ3N0YWJsZScgaW4gUEFUSCBhdCB0aGUgc2FtZSB0aW1lCiAgICAgICAgICAgICMgVXNlIC1GIHRvIGVuc3VyZSBmaXhlZCBzdHJpbmcgbWF0Y2hpbmcgKG5vIHJlZ2V4KQogICAgICAgICAgICBsb2NhbCBuZXdfcGF0aD0kKGVjaG8gIiRQQVRIIiB8IHRyICc6JyAnXG4nIHwgZ3JlcCAtdkYgIiRGTFVUVEVSX1JFUE9fUk9PVCIgfCB0ciAnXG4nICc6JyB8IHNlZCAncy86JC8vJykKCiAgICAgICAgICAgICMgMy4gVXBkYXRlIFBBVEgKICAgICAgICAgICAgIyBQcmVwZW5kIHRoZSBuZXcgdGFyZ2V0J3MgYmluIGRpcmVjdG9yeSAoYW5kIGV0IHBhdGggaWYgaXQgZXhpc3RzKQogICAgICAgICAgICBpZiBbWyAtZCAiJGV0X2Jpbl9wYXRoIiBdXTsgdGhlbgogICAgICAgICAgICAgICAgZXhwb3J0IFBBVEg9IiRmdWxsX2Jpbl9wYXRoOiRldF9iaW5fcGF0aDokbmV3X3BhdGgiCiAgICAgICAgICAgIGVsc2UKICAgICAgICAgICAgICAgIGV4cG9ydCBQQVRIPSIkZnVsbF9iaW5fcGF0aDokbmV3X3BhdGgiCiAgICAgICAgICAgIGZpCgogICAgICAgICAgICAjIDQuIFZlcmlmeQogICAgICAgICAgICBlY2hvICLinIUgU3dpdGNoZWQgdG8gRmx1dHRlciAkZGlyX25hbWUiCiAgICAgICAgICAgIGVjaG8gIiAgIEZsdXR0ZXI6ICQod2hpY2ggZmx1dHRlcikiCiAgICAgICAgICAgIGVjaG8gIiAgIERhcnQ6ICAgICQod2hpY2ggZGFydCkiCiAgICAgICAgZmkKICAgIGZpCn0KCl9mc3dpdGNoX2NvbXBsZXRpb24oKSB7CiAgICBsb2NhbCBjdXI9IiR7Q09NUF9XT1JEU1tDT01QX0NXT1JEXX0iCiAgICBsb2NhbCB0YXJnZXRzPSgpCgogICAgd2hpbGUgcmVhZCAtciB3dF9wYXRoIGhhc2ggYnJhbmNoX2luZm8gcmVzdDsgZG8KICAgICAgICBsb2NhbCBkaXJfbmFtZT0iJHt3dF9wYXRoIyRGTFVUVEVSX1JFUE9fUk9PVC99IgogICAgICAgIGlmIFtbICIkZGlyX25hbWUiID09ICIkd3RfcGF0aCIgJiYgIiR3dF9wYXRoIiA9PSAiJEZMVVRURVJfUkVQT19ST09UIiBdXTsgdGhlbgogICAgICAgICAgICBkaXJfbmFtZT0iJHt3dF9wYXRoIyMqL30iCiAgICAgICAgZmkKICAgICAgICBsb2NhbCBicmFuY2hfbmFtZT0iJHticmFuY2hfaW5mbyNcW30iCiAgICAgICAgYnJhbmNoX25hbWU9IiR7YnJhbmNoX25hbWUlXF19IgoKICAgICAgICB0YXJnZXRzKz0oIiRkaXJfbmFtZSIpCiAgICAgICAgaWYgWyAtbiAiJGJyYW5jaF9uYW1lIiBdOyB0aGVuCiAgICAgICAgICAgIHRhcmdldHMrPSgiJGJyYW5jaF9uYW1lIikKICAgICAgICBmaQogICAgZG9uZSA8IDwoX2Zzd2l0Y2hfZ2V0X3dvcmt0cmVlX2RhdGEpCgogICAgIyBEZWR1cGxpY2F0ZSBhbmQgZ2VuZXJhdGUgY29tcGxldGlvbgogICAgbG9jYWwgdW5pcXVlX3RhcmdldHM9JChlY2hvICIke3RhcmdldHNbQF19IiB8IHRyICcgJyAnXG4nIHwgc29ydCAtdSB8IHRyICdcbicgJyAnKQogICAgQ09NUFJFUExZPSggJChjb21wZ2VuIC1XICIke3VuaXF1ZV90YXJnZXRzfSIgLS0gJHtjdXJ9KSApCn0KY29tcGxldGUgLUYgX2Zzd2l0Y2hfY29tcGxldGlvbiBmc3dpdGNoCgpmY2QoKSB7CiAgICBsb2NhbCBmbHV0dGVyX3BhdGgKICAgIGZsdXR0ZXJfcGF0aD0kKGNvbW1hbmQgLXYgZmx1dHRlcikKCiAgICBpZiBbWyAteiAiJGZsdXR0ZXJfcGF0aCIgXV07IHRoZW4KICAgICAgICBlY2hvICLinYwgRmx1dHRlciBjb21tYW5kIG5vdCBmb3VuZC4gUnVuICdmc3dpdGNoIDx0YXJnZXQ+JyBmaXJzdC4iCiAgICAgICAgcmV0dXJuIDEKICAgIGZpCgogICAgbG9jYWwgYmluX2RpcgogICAgYmluX2Rpcj0kKGRpcm5hbWUgIiRmbHV0dGVyX3BhdGgiKQoKICAgICMgQ2hlY2sgaWYgd2UgYXJlIGluICdiaW4nIGFuZCBnbyB1cCBvbmUgbGV2ZWwKICAgIGlmIFtbICIkKGJhc2VuYW1lICIkYmluX2RpciIpIiA9PSAiYmluIiBdXTsgdGhlbgogICAgICAgIGNkICIkKGRpcm5hbWUgIiRiaW5fZGlyIikiCiAgICBlbHNlCiAgICAgICAgY2QgIiRiaW5fZGlyIgogICAgZmkKfQoKYWxpYXMgZnJvb3Q9ZmNkCgojIE9wdGlvbmFsOiBEZWZhdWx0IHRvIG1hc3RlciBvbiBsb2FkIGlmIG5vIGZsdXR0ZXIgaXMgZm91bmQKaWYgISBjb21tYW5kIC12IGZsdXR0ZXIgJj4gL2Rldi9udWxsOyB0aGVuCiAgICBmc3dpdGNoIG1hc3RlcgogICAgZWNobyAi4oS577iPICBGbHV0dGVyIGVudmlyb25tZW50IGxvYWRlZC4gVXNlICdmc3dpdGNoIHN0YWJsZScgb3IgJ2Zzd2l0Y2ggbWFzdGVyJyB0byBhY3RpdmF0ZS4iCmZpCg=="
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
