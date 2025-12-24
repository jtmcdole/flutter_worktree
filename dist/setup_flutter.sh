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

PAYLOAD="IyBTb3VyY2UgdGhpcyBmaWxlIGluIHlvdXIgLmJhc2hyYyBvciAuenNocmMKIyBVc2FnZTogc291cmNlICRTV0lUQ0hfRklMRQoKIyBBdXRvLWRldGVjdCB0aGUgcmVwbyByb290IGJhc2VkIG9uIHRoaXMgc2NyaXB0J3MgbG9jYXRpb24KaWYgWyAtbiAiJEJBU0hfU09VUkNFIiBdOyB0aGVuCiAgICBfU0NSSVBUX1BBVEg9IiR7QkFTSF9TT1VSQ0VbMF19IgplbGlmIFsgLW4gIiRaU0hfVkVSU0lPTiIgXTsgdGhlbgogICAgX1NDUklQVF9QQVRIPSIkeyglKTotJXh9IgplbHNlCiAgICBfU0NSSVBUX1BBVEg9IiQwIgpmaQoKIyBVc2UgcHdkIC1QIHRvIHJlc29sdmUgc3ltbGlua3MgdG8gcGh5c2ljYWwgcGF0aApGTFVUVEVSX1JFUE9fUk9PVD0iJChjZCAiJChkaXJuYW1lICIkX1NDUklQVF9QQVRIIikiID4vZGV2L251bGwgMj4mMSAmJiBwd2QgLVApIgoKX2Zzd2l0Y2hfZ2V0X3dvcmt0cmVlX2RhdGEoKSB7CiAgICBpZiBjb21tYW5kIC12IGdpdCAmPiAvZGV2L251bGwgJiYgWyAtZCAiJEZMVVRURVJfUkVQT19ST09UIiBdOyB0aGVuCiAgICAgICAgZ2l0IC1DICIkRkxVVFRFUl9SRVBPX1JPT1QiIHdvcmt0cmVlIGxpc3QgMj4vZGV2L251bGwgfCBncmVwIC12ICIoYmFyZSkiCiAgICBmaQp9CgpfZnN3aXRjaF9yZXNvbHZlKCkgewogICAgbG9jYWwgdGFyZ2V0PSQxCiAgICBpZiBbWyAteiAiJEZMVVRURVJfUkVQT19ST09UIiBdXTsgdGhlbgogICAgICAgIHJldHVybgogICAgZmkKICAgIGxvY2FsIHJlc29sdmVkPSIiCgogICAgd2hpbGUgcmVhZCAtciB3dF9wYXRoIGhhc2ggYnJhbmNoX2luZm8gcmVzdDsgZG8KICAgICAgICBsb2NhbCByZWxfcGF0aD0iJHt3dF9wYXRoIyRGTFVUVEVSX1JFUE9fUk9PVC99IgogICAgICAgIGxvY2FsIGlzX3Jvb3Q9MAogICAgICAgIGlmIFtbICIkcmVsX3BhdGgiID09ICIkd3RfcGF0aCIgJiYgIiR3dF9wYXRoIiA9PSAiJEZMVVRURVJfUkVQT19ST09UIiBdXTsgdGhlbgogICAgICAgICAgICByZWxfcGF0aD0iLiIKICAgICAgICAgICAgaXNfcm9vdD0xCiAgICAgICAgZmkKCiAgICAgICAgbG9jYWwgYnJhbmNoX25hbWU9IiR7YnJhbmNoX2luZm8jXFt9IgogICAgICAgIGJyYW5jaF9uYW1lPSIke2JyYW5jaF9uYW1lJVxdfSIKCiAgICAgICAgaWYgW1sgIiR0YXJnZXQiID09ICIkcmVsX3BhdGgiIF1dIHx8IFtbICIkdGFyZ2V0IiA9PSAiJGJyYW5jaF9uYW1lIiBdXTsgdGhlbgogICAgICAgICAgICByZXNvbHZlZD0iJHJlbF9wYXRoIgogICAgICAgICAgICBicmVhawogICAgICAgIGZpCiAgICBkb25lIDwgPChfZnN3aXRjaF9nZXRfd29ya3RyZWVfZGF0YSkKCiAgICBlY2hvICIkcmVzb2x2ZWQiCn0KCmZzd2l0Y2goKSB7CiAgICBsb2NhbCB0YXJnZXQ9JDEKICAgIGlmIFtbIC16ICIkRkxVVFRFUl9SRVBPX1JPT1QiIF1dOyB0aGVuCiAgICAgICAgZWNobyAi4p2MIEVycm9yOiBGTFVUVEVSX1JFUE9fUk9PVCBpcyBub3Qgc2V0LiBDb3VsZCBub3QgZGV0ZWN0IHJlcG8gcm9vdC4iCiAgICAgICAgcmV0dXJuIDEKICAgIGZpCgogICAgIyBSZXNvbHZlIHRhcmdldCB0byBkaXJlY3RvcnkgKHJlbGF0aXZlIHBhdGggZnJvbSByb290LCBvciAiLiIpCiAgICBsb2NhbCBkaXJfbmFtZT0kKF9mc3dpdGNoX3Jlc29sdmUgIiR0YXJnZXQiKQoKICAgIGlmIFtbIC16ICIkZGlyX25hbWUiIF1dOyB0aGVuCiAgICAgICAgZWNobyAi4p2MIEludmFsaWQgdGFyZ2V0OiAnJHRhcmdldCciCiAgICAgICAgZWNobyAiICAgQXZhaWxhYmxlIGNvbnRleHRzOiIKICAgICAgICBfZnN3aXRjaF9nZXRfd29ya3RyZWVfZGF0YSB8IHdoaWxlIHJlYWQgLXIgd3RfcGF0aCBoYXNoIGJyYW5jaF9pbmZvIHJlc3Q7IGRvCiAgICAgICAgICAgICBsb2NhbCBkPSIke3d0X3BhdGgjJEZMVVRURVJfUkVQT19ST09UL30iCiAgICAgICAgICAgICBpZiBbWyAiJGQiID09ICIkd3RfcGF0aCIgJiYgIiR3dF9wYXRoIiA9PSAiJEZMVVRURVJfUkVQT19ST09UIiBdXTsgdGhlbgogICAgICAgICAgICAgICAgIGQ9Ii4iCiAgICAgICAgICAgICBmaQogICAgICAgICAgICAgbG9jYWwgYj0iJHticmFuY2hfaW5mbyNcW30iCiAgICAgICAgICAgICBiPSIke2IlXF19IgogICAgICAgICAgICAgZWNobyAiICAgLSAkZCAoJGIpIgogICAgICAgIGRvbmUKICAgICAgICByZXR1cm4gMQogICAgZWxzZQogICAgICAgICMgVGFyZ2V0IHJlc29sdmVkLCBjaGVjayBiaW4KICAgICAgICBsb2NhbCBmdWxsX2Jpbl9wYXRoCiAgICAgICAgbG9jYWwgZXRfYmluX3BhdGgKCiAgICAgICAgIyBIYW5kbGUgYWJzb2x1dGUgcGF0aHMgKGUuZy4gc3ltbGluayByZXNvbHV0aW9uIG1pc21hdGNoZXMgb3IgZXh0ZXJuYWwgd29ya3RyZWVzKQogICAgICAgIGlmIFtbICIkZGlyX25hbWUiID09IC8qIF1dOyB0aGVuCiAgICAgICAgICAgIGZ1bGxfYmluX3BhdGg9IiRkaXJfbmFtZS9iaW4iCiAgICAgICAgICAgIGV0X2Jpbl9wYXRoPSIkZGlyX25hbWUvZW5naW5lL3NyYy9mbHV0dGVyL2JpbiIKICAgICAgICBlbGlmIFtbICIkZGlyX25hbWUiID09ICIuIiBdXTsgdGhlbgogICAgICAgICAgICBmdWxsX2Jpbl9wYXRoPSIkRkxVVFRFUl9SRVBPX1JPT1QvYmluIgogICAgICAgICAgICBldF9iaW5fcGF0aD0iJEZMVVRURVJfUkVQT19ST09UL2VuZ2luZS9zcmMvZmx1dHRlci9iaW4iCiAgICAgICAgZWxzZQogICAgICAgICAgICBmdWxsX2Jpbl9wYXRoPSIkRkxVVFRFUl9SRVBPX1JPT1QvJGRpcl9uYW1lL2JpbiIKICAgICAgICAgICAgZXRfYmluX3BhdGg9IiRGTFVUVEVSX1JFUE9fUk9PVC8kZGlyX25hbWUvZW5naW5lL3NyYy9mbHV0dGVyL2JpbiIKICAgICAgICBmaQoKICAgICAgICBpZiBbWyAhIC1kICIkZnVsbF9iaW5fcGF0aCIgXV07IHRoZW4KICAgICAgICAgICAgZWNobyAi4p2MIEVycm9yOiBGbHV0dGVyIGJpbiBkaXJlY3Rvcnkgbm90IGZvdW5kIGF0OiIKICAgICAgICAgICAgZWNobyAiICAgJGZ1bGxfYmluX3BhdGgiCiAgICAgICAgICAgIHJldHVybiAxCiAgICAgICAgZWxzZQogICAgICAgICAgICAjIDIuIENsZWFuIFBBVEgKICAgICAgICAgICAgIyBXZSByZW1vdmUgYW55IHBhdGggY29udGFpbmluZyB0aGUgRkxVVFRFUl9SRVBPX1JPT1QgdG8gYXZvaWQgY29uZmxpY3RzCiAgICAgICAgICAgICMgVGhpcyBwcmV2ZW50cyBoYXZpbmcgYm90aCAnbWFzdGVyJyBhbmQgJ3N0YWJsZScgaW4gUEFUSCBhdCB0aGUgc2FtZSB0aW1lCiAgICAgICAgICAgICMgVXNlIC1GIHRvIGVuc3VyZSBmaXhlZCBzdHJpbmcgbWF0Y2hpbmcgKG5vIHJlZ2V4KQogICAgICAgICAgICBsb2NhbCBuZXdfcGF0aD0kKGVjaG8gIiRQQVRIIiB8IHRyICc6JyAnXG4nIHwgZ3JlcCAtdkYgIiRGTFVUVEVSX1JFUE9fUk9PVCIgfCB0ciAnXG4nICc6JyB8IHNlZCAncy86JC8vJykKCiAgICAgICAgICAgICMgMy4gVXBkYXRlIFBBVEgKICAgICAgICAgICAgIyBQcmVwZW5kIHRoZSBuZXcgdGFyZ2V0J3MgYmluIGRpcmVjdG9yeSAoYW5kIGV0IHBhdGggaWYgaXQgZXhpc3RzKQogICAgICAgICAgICBpZiBbWyAtZCAiJGV0X2Jpbl9wYXRoIiBdXTsgdGhlbgogICAgICAgICAgICAgICAgZXhwb3J0IFBBVEg9IiRmdWxsX2Jpbl9wYXRoOiRldF9iaW5fcGF0aDokbmV3X3BhdGgiCiAgICAgICAgICAgIGVsc2UKICAgICAgICAgICAgICAgIGV4cG9ydCBQQVRIPSIkZnVsbF9iaW5fcGF0aDokbmV3X3BhdGgiCiAgICAgICAgICAgIGZpCgogICAgICAgICAgICAjIDQuIFZlcmlmeQogICAgICAgICAgICBlY2hvICLinIUgU3dpdGNoZWQgdG8gRmx1dHRlciAkZGlyX25hbWUiCiAgICAgICAgICAgIGVjaG8gIiAgIEZsdXR0ZXI6ICQod2hpY2ggZmx1dHRlcikiCiAgICAgICAgICAgIGVjaG8gIiAgIERhcnQ6ICAgICQod2hpY2ggZGFydCkiCiAgICAgICAgZmkKICAgIGZpCn0KCl9mc3dpdGNoX2NvbXBsZXRpb24oKSB7CiAgICBsb2NhbCBjdXI9IiR7Q09NUF9XT1JEU1tDT01QX0NXT1JEXX0iCiAgICBsb2NhbCB0YXJnZXRzPSgpCgogICAgd2hpbGUgcmVhZCAtciB3dF9wYXRoIGhhc2ggYnJhbmNoX2luZm8gcmVzdDsgZG8KICAgICAgICBsb2NhbCBkaXJfbmFtZT0iJHt3dF9wYXRoIyRGTFVUVEVSX1JFUE9fUk9PVC99IgogICAgICAgIGlmIFtbICIkZGlyX25hbWUiID09ICIkd3RfcGF0aCIgJiYgIiR3dF9wYXRoIiA9PSAiJEZMVVRURVJfUkVQT19ST09UIiBdXTsgdGhlbgogICAgICAgICAgICBkaXJfbmFtZT0iJHt3dF9wYXRoIyMqL30iCiAgICAgICAgZmkKICAgICAgICBsb2NhbCBicmFuY2hfbmFtZT0iJHticmFuY2hfaW5mbyNcW30iCiAgICAgICAgYnJhbmNoX25hbWU9IiR7YnJhbmNoX25hbWUlXF19IgoKICAgICAgICB0YXJnZXRzKz0oIiRkaXJfbmFtZSIpCiAgICAgICAgaWYgWyAtbiAiJGJyYW5jaF9uYW1lIiBdOyB0aGVuCiAgICAgICAgICAgIHRhcmdldHMrPSgiJGJyYW5jaF9uYW1lIikKICAgICAgICBmaQogICAgZG9uZSA8IDwoX2Zzd2l0Y2hfZ2V0X3dvcmt0cmVlX2RhdGEpCgogICAgIyBEZWR1cGxpY2F0ZSBhbmQgZ2VuZXJhdGUgY29tcGxldGlvbgogICAgbG9jYWwgdW5pcXVlX3RhcmdldHM9JChlY2hvICIke3RhcmdldHNbQF19IiB8IHRyICcgJyAnXG4nIHwgc29ydCAtdSB8IHRyICdcbicgJyAnKQogICAgQ09NUFJFUExZPSggJChjb21wZ2VuIC1XICIke3VuaXF1ZV90YXJnZXRzfSIgLS0gJHtjdXJ9KSApCn0KY29tcGxldGUgLUYgX2Zzd2l0Y2hfY29tcGxldGlvbiBmc3dpdGNoCgpmY2QoKSB7CiAgICBsb2NhbCBmbHV0dGVyX3BhdGgKICAgIGZsdXR0ZXJfcGF0aD0kKGNvbW1hbmQgLXYgZmx1dHRlcikKCiAgICBpZiBbWyAteiAiJGZsdXR0ZXJfcGF0aCIgXV07IHRoZW4KICAgICAgICBlY2hvICLinYwgRmx1dHRlciBjb21tYW5kIG5vdCBmb3VuZC4gUnVuICdmc3dpdGNoIDx0YXJnZXQ+JyBmaXJzdC4iCiAgICAgICAgcmV0dXJuIDEKICAgIGZpCgogICAgbG9jYWwgYmluX2RpcgogICAgYmluX2Rpcj0kKGRpcm5hbWUgIiRmbHV0dGVyX3BhdGgiKQoKICAgICMgQ2hlY2sgaWYgd2UgYXJlIGluICdiaW4nIGFuZCBnbyB1cCBvbmUgbGV2ZWwKICAgIGlmIFtbICIkKGJhc2VuYW1lICIkYmluX2RpciIpIiA9PSAiYmluIiBdXTsgdGhlbgogICAgICAgIGNkICIkKGRpcm5hbWUgIiRiaW5fZGlyIikiCiAgICBlbHNlCiAgICAgICAgY2QgIiRiaW5fZGlyIgogICAgZmkKfQoKYWxpYXMgZnJvb3Q9ZmNkCgojIE9wdGlvbmFsOiBEZWZhdWx0IHRvIG1hc3RlciBvbiBsb2FkIGlmIG5vIGZsdXR0ZXIgaXMgZm91bmQKaWYgISBjb21tYW5kIC12IGZsdXR0ZXIgJj4gL2Rldi9udWxsOyB0aGVuCiAgICBmc3dpdGNoIG1hc3RlcgogICAgZWNobyAi4oS577iPICBGbHV0dGVyIGVudmlyb25tZW50IGxvYWRlZC4gVXNlICdmc3dpdGNoIHN0YWJsZScgb3IgJ2Zzd2l0Y2ggbWFzdGVyJyB0byBhY3RpdmF0ZS4iCmZpCg=="
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
