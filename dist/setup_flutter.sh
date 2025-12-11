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

PAYLOAD="IyBTb3VyY2UgdGhpcyBmaWxlIGluIHlvdXIgLmJhc2hyYyBvciAuenNocmMNCiMgVXNhZ2U6IHNvdXJjZSAkU1dJVENIX0ZJTEUNCg0KIyBBdXRvLWRldGVjdCB0aGUgcmVwbyByb290IGJhc2VkIG9uIHRoaXMgc2NyaXB0J3MgbG9jYXRpb24NCmlmIFsgLW4gIiRCQVNIX1NPVVJDRSIgXTsgdGhlbg0KICAgIF9TQ1JJUFRfUEFUSD0iJHtCQVNIX1NPVVJDRVswXX0iDQplbGlmIFsgLW4gIiRaU0hfVkVSU0lPTiIgXTsgdGhlbg0KICAgIF9TQ1JJUFRfUEFUSD0iJHsoJSk6LSV4fSINCmVsc2UNCiAgICBfU0NSSVBUX1BBVEg9IiQwIg0KZmkNCg0KRkxVVFRFUl9SRVBPX1JPT1Q9IiQoY2QgIiQoZGlybmFtZSAiJF9TQ1JJUFRfUEFUSCIpIiA+L2Rldi9udWxsIDI+JjEgJiYgcHdkKSINCg0KX2Zzd2l0Y2hfZ2V0X3dvcmt0cmVlX2RhdGEoKSB7DQogICAgaWYgY29tbWFuZCAtdiBnaXQgJj4gL2Rldi9udWxsICYmIFsgLWQgIiRGTFVUVEVSX1JFUE9fUk9PVCIgXTsgdGhlbg0KICAgICAgICBnaXQgLUMgIiRGTFVUVEVSX1JFUE9fUk9PVCIgd29ya3RyZWUgbGlzdCAyPi9kZXYvbnVsbCB8IGdyZXAgLXYgIihiYXJlKSINCiAgICBmaQ0KfQ0KDQpfZnN3aXRjaF9yZXNvbHZlKCkgew0KICAgIGxvY2FsIHRhcmdldD0kMQ0KICAgIGlmIFtbIC16ICIkRkxVVFRFUl9SRVBPX1JPT1QiIF1dOyB0aGVuDQogICAgICAgIHJldHVybg0KICAgIGZpDQogICAgbG9jYWwgcmVzb2x2ZWQ9IiINCiAgICANCiAgICB3aGlsZSByZWFkIC1yIHd0X3BhdGggaGFzaCBicmFuY2hfaW5mbyByZXN0OyBkbw0KICAgICAgICBsb2NhbCByZWxfcGF0aD0iJHt3dF9wYXRoIyRGTFVUVEVSX1JFUE9fUk9PVC99Ig0KICAgICAgICBsb2NhbCBpc19yb290PTANCiAgICAgICAgaWYgW1sgIiRyZWxfcGF0aCIgPT0gIiR3dF9wYXRoIiAmJiAiJHd0X3BhdGgiID09ICIkRkxVVFRFUl9SRVBPX1JPT1QiIF1dOyB0aGVuDQogICAgICAgICAgICByZWxfcGF0aD0iLiINCiAgICAgICAgICAgIGlzX3Jvb3Q9MQ0KICAgICAgICBmaQ0KDQogICAgICAgIGxvY2FsIGJyYW5jaF9uYW1lPSIke2JyYW5jaF9pbmZvI1xbfSINCiAgICAgICAgYnJhbmNoX25hbWU9IiR7YnJhbmNoX25hbWUlXF19Ig0KICAgICAgICANCiAgICAgICAgaWYgW1sgIiR0YXJnZXQiID09ICIkcmVsX3BhdGgiIF1dIHx8IFtbICIkdGFyZ2V0IiA9PSAiJGJyYW5jaF9uYW1lIiBdXTsgdGhlbg0KICAgICAgICAgICAgcmVzb2x2ZWQ9IiRyZWxfcGF0aCINCiAgICAgICAgICAgIGJyZWFrDQogICAgICAgIGZpDQogICAgZG9uZSA8IDwoX2Zzd2l0Y2hfZ2V0X3dvcmt0cmVlX2RhdGEpDQogICAgDQogICAgZWNobyAiJHJlc29sdmVkIg0KfQ0KDQpmc3dpdGNoKCkgew0KICAgIGxvY2FsIHRhcmdldD0kMQ0KICAgIGlmIFtbIC16ICIkRkxVVFRFUl9SRVBPX1JPT1QiIF1dOyB0aGVuDQogICAgICAgIGVjaG8gIuKdjCBFcnJvcjogRkxVVFRFUl9SRVBPX1JPT1QgaXMgbm90IHNldC4gQ291bGQgbm90IGRldGVjdCByZXBvIHJvb3QuIg0KICAgICAgICByZXR1cm4gMQ0KICAgIGZpDQogICAgDQogICAgIyBSZXNvbHZlIHRhcmdldCB0byBkaXJlY3RvcnkgKHJlbGF0aXZlIHBhdGggZnJvbSByb290LCBvciAiLiIpDQogICAgbG9jYWwgZGlyX25hbWU9JChfZnN3aXRjaF9yZXNvbHZlICIkdGFyZ2V0IikNCiAgICANCiAgICBpZiBbWyAteiAiJGRpcl9uYW1lIiBdXTsgdGhlbg0KICAgICAgICBlY2hvICLinYwgSW52YWxpZCB0YXJnZXQ6ICckdGFyZ2V0JyINCiAgICAgICAgZWNobyAiICAgQXZhaWxhYmxlIGNvbnRleHRzOiINCiAgICAgICAgX2Zzd2l0Y2hfZ2V0X3dvcmt0cmVlX2RhdGEgfCB3aGlsZSByZWFkIC1yIHd0X3BhdGggaGFzaCBicmFuY2hfaW5mbyByZXN0OyBkbw0KICAgICAgICAgICAgIGxvY2FsIGQ9IiR7d3RfcGF0aCMkRkxVVFRFUl9SRVBPX1JPT1QvfSINCiAgICAgICAgICAgICBpZiBbWyAiJGQiID09ICIkd3RfcGF0aCIgJiYgIiR3dF9wYXRoIiA9PSAiJEZMVVRURVJfUkVQT19ST09UIiBdXTsgdGhlbg0KICAgICAgICAgICAgICAgICBkPSIuIg0KICAgICAgICAgICAgIGZpDQogICAgICAgICAgICAgbG9jYWwgYj0iJHticmFuY2hfaW5mbyNcW30iDQogICAgICAgICAgICAgYj0iJHtiJVxdfSINCiAgICAgICAgICAgICBlY2hvICIgICAtICRkICgkYikiDQogICAgICAgIGRvbmUNCiAgICAgICAgcmV0dXJuIDENCiAgICBlbHNlDQogICAgICAgICMgVGFyZ2V0IHJlc29sdmVkLCBjaGVjayBiaW4NCiAgICAgICAgbG9jYWwgZnVsbF9iaW5fcGF0aD0iJEZMVVRURVJfUkVQT19ST09ULyRkaXJfbmFtZS9iaW4iDQogICAgICAgIGlmIFtbICIkZGlyX25hbWUiID09ICIuIiBdXTsgdGhlbg0KICAgICAgICAgICAgZnVsbF9iaW5fcGF0aD0iJEZMVVRURVJfUkVQT19ST09UL2JpbiINCiAgICAgICAgZmkNCiAgICANCiAgICAgICAgaWYgW1sgISAtZCAiJGZ1bGxfYmluX3BhdGgiIF1dOyB0aGVuDQogICAgICAgICAgICBlY2hvICLinYwgRXJyb3I6IEZsdXR0ZXIgYmluIGRpcmVjdG9yeSBub3QgZm91bmQgYXQ6Ig0KICAgICAgICAgICAgZWNobyAiICAgJGZ1bGxfYmluX3BhdGgiDQogICAgICAgICAgICByZXR1cm4gMQ0KICAgICAgICBlbHNlDQogICAgICAgICAgICAjIDIuIENsZWFuIFBBVEgNCiAgICAgICAgICAgICMgV2UgcmVtb3ZlIGFueSBwYXRoIGNvbnRhaW5pbmcgdGhlIEZMVVRURVJfUkVQT19ST09UIHRvIGF2b2lkIGNvbmZsaWN0cw0KICAgICAgICAgICAgIyBUaGlzIHByZXZlbnRzIGhhdmluZyBib3RoICdtYXN0ZXInIGFuZCAnc3RhYmxlJyBpbiBQQVRIIGF0IHRoZSBzYW1lIHRpbWUNCiAgICAgICAgICAgICMgVXNlIC1GIHRvIGVuc3VyZSBmaXhlZCBzdHJpbmcgbWF0Y2hpbmcgKG5vIHJlZ2V4KQ0KICAgICAgICAgICAgbG9jYWwgbmV3X3BhdGg9JChlY2hvICIkUEFUSCIgfCB0ciAnOicgJ1xuJyB8IGdyZXAgLXZGICIkRkxVVFRFUl9SRVBPX1JPT1QiIHwgdHIgJ1xuJyAnOicgfCBzZWQgJ3MvOiQvLycpDQogICAgICAgIA0KICAgICAgICAgICAgIyAzLiBVcGRhdGUgUEFUSA0KICAgICAgICAgICAgIyBQcmVwZW5kIHRoZSBuZXcgdGFyZ2V0J3MgYmluIGRpcmVjdG9yeQ0KICAgICAgICAgICAgZXhwb3J0IFBBVEg9IiRmdWxsX2Jpbl9wYXRoOiRuZXdfcGF0aCINCiAgICAgICAgDQogICAgICAgICAgICAjIDQuIFZlcmlmeQ0KICAgICAgICAgICAgZWNobyAi4pyFIFN3aXRjaGVkIHRvIEZsdXR0ZXIgJGRpcl9uYW1lIg0KICAgICAgICAgICAgZWNobyAiICAgRmx1dHRlcjogJCh3aGljaCBmbHV0dGVyKSINCiAgICAgICAgICAgIGVjaG8gIiAgIERhcnQ6ICAgICQod2hpY2ggZGFydCkiDQogICAgICAgIGZpDQogICAgZmkNCn0NCg0KX2Zzd2l0Y2hfY29tcGxldGlvbigpIHsNCiAgICBsb2NhbCBjdXI9IiR7Q09NUF9XT1JEU1tDT01QX0NXT1JEXX0iDQogICAgbG9jYWwgdGFyZ2V0cz0oKQ0KICAgIA0KICAgIHdoaWxlIHJlYWQgLXIgd3RfcGF0aCBoYXNoIGJyYW5jaF9pbmZvIHJlc3Q7IGRvDQogICAgICAgIGxvY2FsIGRpcl9uYW1lPSIke3d0X3BhdGgjJEZMVVRURVJfUkVQT19ST09UL30iDQogICAgICAgIGlmIFtbICIkZGlyX25hbWUiID09ICIkd3RfcGF0aCIgJiYgIiR3dF9wYXRoIiA9PSAiJEZMVVRURVJfUkVQT19ST09UIiBdXTsgdGhlbg0KICAgICAgICAgICAgZGlyX25hbWU9IiR7d3RfcGF0aCMjKi99Ig0KICAgICAgICBmaQ0KICAgICAgICBsb2NhbCBicmFuY2hfbmFtZT0iJHticmFuY2hfaW5mbyNcW30iDQogICAgICAgIGJyYW5jaF9uYW1lPSIke2JyYW5jaF9uYW1lJVxdfSINCiAgICAgICAgDQogICAgICAgIHRhcmdldHMrPSgiJGRpcl9uYW1lIikNCiAgICAgICAgaWYgWyAtbiAiJGJyYW5jaF9uYW1lIiBdOyB0aGVuDQogICAgICAgICAgICB0YXJnZXRzKz0oIiRicmFuY2hfbmFtZSIpDQogICAgICAgIGZpDQogICAgZG9uZSA8IDwoX2Zzd2l0Y2hfZ2V0X3dvcmt0cmVlX2RhdGEpDQogICAgDQogICAgIyBEZWR1cGxpY2F0ZSBhbmQgZ2VuZXJhdGUgY29tcGxldGlvbg0KICAgIGxvY2FsIHVuaXF1ZV90YXJnZXRzPSQoZWNobyAiJHt0YXJnZXRzW0BdfSIgfCB0ciAnICcgJ1xuJyB8IHNvcnQgLXUgfCB0ciAnXG4nICcgJykNCiAgICBDT01QUkVQTFk9KCAkKGNvbXBnZW4gLVcgIiR7dW5pcXVlX3RhcmdldHN9IiAtLSAke2N1cn0pICkNCn0NCmNvbXBsZXRlIC1GIF9mc3dpdGNoX2NvbXBsZXRpb24gZnN3aXRjaA0KDQojIE9wdGlvbmFsOiBEZWZhdWx0IHRvIG1hc3RlciBvbiBsb2FkIGlmIG5vIGZsdXR0ZXIgaXMgZm91bmQNCmlmICEgY29tbWFuZCAtdiBmbHV0dGVyICY+IC9kZXYvbnVsbDsgdGhlbg0KICAgIGZzd2l0Y2ggbWFzdGVyDQogICAgZWNobyAi4oS577iPICBGbHV0dGVyIGVudmlyb25tZW50IGxvYWRlZC4gVXNlICdmc3dpdGNoIHN0YWJsZScgb3IgJ2Zzd2l0Y2ggbWFzdGVyJyB0byBhY3RpdmF0ZS4iDQpmaQ0K"
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
