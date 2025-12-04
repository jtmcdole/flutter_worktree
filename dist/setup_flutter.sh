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

PAYLOAD="IyBTb3VyY2UgdGhpcyBmaWxlIGluIHlvdXIgLmJhc2hyYyBvciAuenNocmMKIyBVc2FnZTogc291cmNlICRTV0lUQ0hfRklMRQoKIyBBdXRvLWRldGVjdCB0aGUgcmVwbyByb290IGJhc2VkIG9uIHRoaXMgc2NyaXB0J3MgbG9jYXRpb24KaWYgWyAtbiAiJEJBU0hfU09VUkNFIiBdOyB0aGVuCiAgICBfU0NSSVBUX1BBVEg9IiR7QkFTSF9TT1VSQ0VbMF19IgplbGlmIFsgLW4gIiRaU0hfVkVSU0lPTiIgXTsgdGhlbgogICAgX1NDUklQVF9QQVRIPSIkeyglKTotJXh9IgplbHNlCiAgICBfU0NSSVBUX1BBVEg9IiQwIgpmaQoKZXhwb3J0IEZMVVRURVJfUkVQT19ST09UPSIkKGNkICIkKGRpcm5hbWUgIiRfU0NSSVBUX1BBVEgiKSIgPi9kZXYvbnVsbCAyPiYxICYmIHB3ZCkiCgpfZnN3aXRjaF9nZXRfd29ya3RyZWVfZGF0YSgpIHsKICAgIGlmIGNvbW1hbmQgLXYgZ2l0ICY+IC9kZXYvbnVsbCAmJiBbIC1kICIkRkxVVFRFUl9SRVBPX1JPT1QiIF07IHRoZW4KICAgICAgICBnaXQgLUMgIiRGTFVUVEVSX1JFUE9fUk9PVCIgd29ya3RyZWUgbGlzdCAyPi9kZXYvbnVsbCB8IGdyZXAgLXYgIihiYXJlKSIKICAgIGZpCn0KCl9mc3dpdGNoX3Jlc29sdmUoKSB7CiAgICBsb2NhbCB0YXJnZXQ9JDEKICAgIGxvY2FsIHJlc29sdmVkPSIiCiAgICAKICAgIHdoaWxlIHJlYWQgLXIgcGF0aCBoYXNoIGJyYW5jaF9pbmZvIHJlc3Q7IGRvCiAgICAgICAgbG9jYWwgZGlyX25hbWU9IiR7cGF0aCMjKi99IgogICAgICAgIGxvY2FsIGJyYW5jaF9uYW1lPSIke2JyYW5jaF9pbmZvI1xbfSIKICAgICAgICBicmFuY2hfbmFtZT0iJHticmFuY2hfbmFtZSVcXX0iCiAgICAgICAgCiAgICAgICAgaWYgW1sgIiR0YXJnZXQiID09ICIkZGlyX25hbWUiIF1dIHx8IFtbICIkdGFyZ2V0IiA9PSAiJGJyYW5jaF9uYW1lIiBdXTsgdGhlbgogICAgICAgICAgICByZXNvbHZlZD0iJGRpcl9uYW1lIgogICAgICAgICAgICBicmVhawogICAgICAgIGZpCiAgICBkb25lIDwgPChfZnN3aXRjaF9nZXRfd29ya3RyZWVfZGF0YSkKICAgIAogICAgZWNobyAiJHJlc29sdmVkIgp9Cgpmc3dpdGNoKCkgewogICAgbG9jYWwgdGFyZ2V0PSQxCiAgICAKICAgICMgUmVzb2x2ZSB0YXJnZXQgdG8gZGlyZWN0b3J5CiAgICBsb2NhbCBkaXJfbmFtZT0kKF9mc3dpdGNoX3Jlc29sdmUgIiR0YXJnZXQiKQogICAgCiAgICBpZiBbWyAteiAiJGRpcl9uYW1lIiBdXTsgdGhlbgogICAgICAgIGVjaG8gIuKdjCBJbnZhbGlkIHRhcmdldDogJyR0YXJnZXQnIgogICAgICAgIGVjaG8gIiAgIEF2YWlsYWJsZSBjb250ZXh0czoiCiAgICAgICAgX2Zzd2l0Y2hfZ2V0X3dvcmt0cmVlX2RhdGEgfCB3aGlsZSByZWFkIC1yIHBhdGggaGFzaCBicmFuY2hfaW5mbyByZXN0OyBkbwogICAgICAgICAgICAgbG9jYWwgZD0iJHtwYXRoIyMqL30iCiAgICAgICAgICAgICBsb2NhbCBiPSIke2JyYW5jaF9pbmZvI1xbfSIKICAgICAgICAgICAgIGI9IiR7YiVcXX0iCiAgICAgICAgICAgICBlY2hvICIgICAtICRkICgkYikiCiAgICAgICAgZG9uZQogICAgICAgIHJldHVybiAxCiAgICBmaQoKICAgICMgMi4gQ2xlYW4gUEFUSAogICAgIyBXZSByZW1vdmUgYW55IHBhdGggY29udGFpbmluZyB0aGUgRkxVVFRFUl9SRVBPX1JPT1QgdG8gYXZvaWQgY29uZmxpY3RzCiAgICAjIFRoaXMgcHJldmVudHMgaGF2aW5nIGJvdGggJ21hc3RlcicgYW5kICdzdGFibGUnIGluIFBBVEggYXQgdGhlIHNhbWUgdGltZQogICAgbG9jYWwgbmV3X3BhdGg9JChlY2hvICIkUEFUSCIgfCB0ciAnOicgJ1xuJyB8IGdyZXAgLXYgIiRGTFVUVEVSX1JFUE9fUk9PVCIgfCB0ciAnXG4nICc6JyB8IHNlZCAncy86JC8vJykKCiAgICAjIDMuIFVwZGF0ZSBQQVRICiAgICAjIFByZXBlbmQgdGhlIG5ldyB0YXJnZXQncyBiaW4gZGlyZWN0b3J5CiAgICBleHBvcnQgUEFUSD0iJEZMVVRURVJfUkVQT19ST09ULyRkaXJfbmFtZS9iaW46JG5ld19wYXRoIgoKICAgICMgNC4gVmVyaWZ5CiAgICBlY2hvICLinIUgU3dpdGNoZWQgdG8gRmx1dHRlciAkZGlyX25hbWUiCiAgICBlY2hvICIgICBGbHV0dGVyOiAkKHdoaWNoIGZsdXR0ZXIpIgogICAgZWNobyAiICAgRGFydDogICAgJCh3aGljaCBkYXJ0KSIKICAgIGZsdXR0ZXIgLS12ZXJzaW9uIHwgaGVhZCAtbiAxCn0KCl9mc3dpdGNoX2NvbXBsZXRpb24oKSB7CiAgICBsb2NhbCBjdXI9IiR7Q09NUF9XT1JEU1tDT01QX0NXT1JEXX0iCiAgICBsb2NhbCB0YXJnZXRzPSgpCiAgICAKICAgIHdoaWxlIHJlYWQgLXIgcGF0aCBoYXNoIGJyYW5jaF9pbmZvIHJlc3Q7IGRvCiAgICAgICAgbG9jYWwgZGlyX25hbWU9IiR7cGF0aCMjKi99IgogICAgICAgIGxvY2FsIGJyYW5jaF9uYW1lPSIke2JyYW5jaF9pbmZvI1xbfSIKICAgICAgICBicmFuY2hfbmFtZT0iJHticmFuY2hfbmFtZSVcXX0iCiAgICAgICAgCiAgICAgICAgdGFyZ2V0cys9KCIkZGlyX25hbWUiKQogICAgICAgIGlmIFsgLW4gIiRicmFuY2hfbmFtZSIgXTsgdGhlbgogICAgICAgICAgICB0YXJnZXRzKz0oIiRicmFuY2hfbmFtZSIpCiAgICAgICAgZmkKICAgIGRvbmUgPCA8KF9mc3dpdGNoX2dldF93b3JrdHJlZV9kYXRhKQogICAgCiAgICAjIERlZHVwbGljYXRlIGFuZCBnZW5lcmF0ZSBjb21wbGV0aW9uCiAgICBsb2NhbCB1bmlxdWVfdGFyZ2V0cz0kKGVjaG8gIiR7dGFyZ2V0c1tAXX0iIHwgdHIgJyAnICdcbicgfCBzb3J0IC11IHwgdHIgJ1xuJyAnICcpCiAgICBDT01QUkVQTFk9KCAkKGNvbXBnZW4gLVcgIiR7dW5pcXVlX3RhcmdldHN9IiAtLSAke2N1cn0pICkKfQpjb21wbGV0ZSAtRiBfZnN3aXRjaF9jb21wbGV0aW9uIGZzd2l0Y2gKCiMgT3B0aW9uYWw6IERlZmF1bHQgdG8gc3RhYmxlIG9uIGxvYWQgaWYgbm8gZmx1dHRlciBpcyBmb3VuZAppZiAhIGNvbW1hbmQgLXYgZmx1dHRlciAmPiAvZGV2L251bGw7IHRoZW4KICAgIGZzd2l0Y2ggc3RhYmxlICMgVW5jb21tZW50IHRvIGF1dG8tbG9hZCBzdGFibGUKICAgIGVjaG8gIuKEue+4jyAgRmx1dHRlciBlbnZpcm9ubWVudCBsb2FkZWQuIFVzZSAnZnN3aXRjaCBzdGFibGUnIG9yICdmc3dpdGNoIG1hc3RlcicgdG8gYWN0aXZhdGUuIgpmaQo="
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
