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

PAYLOAD="IyBTb3VyY2UgdGhpcyBmaWxlIGluIHlvdXIgLmJhc2hyYyBvciAuenNocmMKIyBVc2FnZTogc291cmNlICRTV0lUQ0hfRklMRQoKIyBBdXRvLWRldGVjdCB0aGUgcmVwbyByb290IGJhc2VkIG9uIHRoaXMgc2NyaXB0J3MgbG9jYXRpb24KaWYgWyAtbiAiJEJBU0hfU09VUkNFIiBdOyB0aGVuCiAgICBfU0NSSVBUX1BBVEg9IiR7QkFTSF9TT1VSQ0VbMF19IgplbGlmIFsgLW4gIiRaU0hfVkVSU0lPTiIgXTsgdGhlbgogICAgX1NDUklQVF9QQVRIPSIkeyglKTotJXh9IgplbHNlCiAgICBfU0NSSVBUX1BBVEg9IiQwIgpmaQoKIyBVc2UgcHdkIC1QIHRvIHJlc29sdmUgc3ltbGlua3MgdG8gcGh5c2ljYWwgcGF0aApGTFVUVEVSX1JFUE9fUk9PVD0iJChjZCAiJChkaXJuYW1lICIkX1NDUklQVF9QQVRIIikiID4vZGV2L251bGwgMj4mMSAmJiBwd2QgLVApIgoKX2Zzd2l0Y2hfZ2V0X3dvcmt0cmVlX2RhdGEoKSB7CiAgICBpZiBjb21tYW5kIC12IGdpdCAmPiAvZGV2L251bGwgJiYgWyAtZCAiJEZMVVRURVJfUkVQT19ST09UIiBdOyB0aGVuCiAgICAgICAgZ2l0IC1DICIkRkxVVFRFUl9SRVBPX1JPT1QiIHdvcmt0cmVlIGxpc3QgMj4vZGV2L251bGwgfCBncmVwIC12ICIoYmFyZSkiCiAgICBmaQp9CgpfZnN3aXRjaF9yZXNvbHZlKCkgewogICAgbG9jYWwgdGFyZ2V0PSQxCiAgICBpZiBbWyAteiAiJEZMVVRURVJfUkVQT19ST09UIiBdXTsgdGhlbgogICAgICAgIHJldHVybgogICAgZmkKICAgIGxvY2FsIHJlc29sdmVkPSIiCgogICAgd2hpbGUgcmVhZCAtciB3dF9wYXRoIGhhc2ggYnJhbmNoX2luZm8gcmVzdDsgZG8KICAgICAgICBsb2NhbCByZWxfcGF0aD0iJHt3dF9wYXRoIyRGTFVUVEVSX1JFUE9fUk9PVC99IgogICAgICAgIGxvY2FsIGlzX3Jvb3Q9MAogICAgICAgIGlmIFtbICIkcmVsX3BhdGgiID09ICIkd3RfcGF0aCIgJiYgIiR3dF9wYXRoIiA9PSAiJEZMVVRURVJfUkVQT19ST09UIiBdXTsgdGhlbgogICAgICAgICAgICByZWxfcGF0aD0iLiIKICAgICAgICAgICAgaXNfcm9vdD0xCiAgICAgICAgZmkKCiAgICAgICAgaWYgW1sgIiRyZWxfcGF0aCIgPT0gIi5iYXJlIiBdXTsgdGhlbgogICAgICAgICAgICBjb250aW51ZQogICAgICAgIGZpCgogICAgICAgIGxvY2FsIGJyYW5jaF9uYW1lPSIke2JyYW5jaF9pbmZvI1xbfSIKICAgICAgICBicmFuY2hfbmFtZT0iJHticmFuY2hfbmFtZSVcXX0iCgogICAgICAgIGlmIFtbICIkdGFyZ2V0IiA9PSAiJHJlbF9wYXRoIiBdXSB8fCBbWyAiJHRhcmdldCIgPT0gIiRicmFuY2hfbmFtZSIgXV07IHRoZW4KICAgICAgICAgICAgcmVzb2x2ZWQ9IiRyZWxfcGF0aCIKICAgICAgICAgICAgYnJlYWsKICAgICAgICBmaQogICAgZG9uZSA8IDwoX2Zzd2l0Y2hfZ2V0X3dvcmt0cmVlX2RhdGEpCgogICAgZWNobyAiJHJlc29sdmVkIgp9Cgpmc3dpdGNoKCkgewogICAgbG9jYWwgdGFyZ2V0PSQxCiAgICBpZiBbWyAteiAiJEZMVVRURVJfUkVQT19ST09UIiBdXTsgdGhlbgogICAgICAgIGVjaG8gIuKdjCBFcnJvcjogRkxVVFRFUl9SRVBPX1JPT1QgaXMgbm90IHNldC4gQ291bGQgbm90IGRldGVjdCByZXBvIHJvb3QuIgogICAgICAgIHJldHVybiAxCiAgICBmaQoKICAgICMgUmVzb2x2ZSB0YXJnZXQgdG8gZGlyZWN0b3J5IChyZWxhdGl2ZSBwYXRoIGZyb20gcm9vdCwgb3IgIi4iKQogICAgbG9jYWwgZGlyX25hbWU9JChfZnN3aXRjaF9yZXNvbHZlICIkdGFyZ2V0IikKCiAgICBpZiBbWyAteiAiJGRpcl9uYW1lIiBdXTsgdGhlbgogICAgICAgIGVjaG8gIuKdjCBJbnZhbGlkIHRhcmdldDogJyR0YXJnZXQnIgogICAgICAgIGVjaG8gIiAgIEF2YWlsYWJsZSBjb250ZXh0czoiCiAgICAgICAgX2Zzd2l0Y2hfZ2V0X3dvcmt0cmVlX2RhdGEgfCB3aGlsZSByZWFkIC1yIHd0X3BhdGggaGFzaCBicmFuY2hfaW5mbyByZXN0OyBkbwogICAgICAgICAgICAgbG9jYWwgZD0iJHt3dF9wYXRoIyRGTFVUVEVSX1JFUE9fUk9PVC99IgogICAgICAgICAgICAgaWYgW1sgIiRkIiA9PSAiJHd0X3BhdGgiICYmICIkd3RfcGF0aCIgPT0gIiRGTFVUVEVSX1JFUE9fUk9PVCIgXV07IHRoZW4KICAgICAgICAgICAgICAgICBkPSIuIgogICAgICAgICAgICAgZmkKICAgICAgICAgICAgIGxvY2FsIGI9IiR7YnJhbmNoX2luZm8jXFt9IgogICAgICAgICAgICAgYj0iJHtiJVxdfSIKICAgICAgICAgICAgIGVjaG8gIiAgIC0gJGQgKCRiKSIKICAgICAgICBkb25lCiAgICAgICAgcmV0dXJuIDEKICAgIGVsc2UKICAgICAgICAjIFRhcmdldCByZXNvbHZlZCwgY2hlY2sgYmluCiAgICAgICAgbG9jYWwgZnVsbF9iaW5fcGF0aAogICAgICAgIGxvY2FsIGV0X2Jpbl9wYXRoCgogICAgICAgICMgSGFuZGxlIGFic29sdXRlIHBhdGhzIChlLmcuIHN5bWxpbmsgcmVzb2x1dGlvbiBtaXNtYXRjaGVzIG9yIGV4dGVybmFsIHdvcmt0cmVlcykKICAgICAgICBpZiBbWyAiJGRpcl9uYW1lIiA9PSAvKiBdXTsgdGhlbgogICAgICAgICAgICBmdWxsX2Jpbl9wYXRoPSIkZGlyX25hbWUvYmluIgogICAgICAgICAgICBldF9iaW5fcGF0aD0iJGRpcl9uYW1lL2VuZ2luZS9zcmMvZmx1dHRlci9iaW4iCiAgICAgICAgZWxpZiBbWyAiJGRpcl9uYW1lIiA9PSAiLiIgXV07IHRoZW4KICAgICAgICAgICAgZnVsbF9iaW5fcGF0aD0iJEZMVVRURVJfUkVQT19ST09UL2JpbiIKICAgICAgICAgICAgZXRfYmluX3BhdGg9IiRGTFVUVEVSX1JFUE9fUk9PVC9lbmdpbmUvc3JjL2ZsdXR0ZXIvYmluIgogICAgICAgIGVsc2UKICAgICAgICAgICAgZnVsbF9iaW5fcGF0aD0iJEZMVVRURVJfUkVQT19ST09ULyRkaXJfbmFtZS9iaW4iCiAgICAgICAgICAgIGV0X2Jpbl9wYXRoPSIkRkxVVFRFUl9SRVBPX1JPT1QvJGRpcl9uYW1lL2VuZ2luZS9zcmMvZmx1dHRlci9iaW4iCiAgICAgICAgZmkKCiAgICAgICAgaWYgW1sgISAtZCAiJGZ1bGxfYmluX3BhdGgiIF1dOyB0aGVuCiAgICAgICAgICAgIGVjaG8gIuKdjCBFcnJvcjogRmx1dHRlciBiaW4gZGlyZWN0b3J5IG5vdCBmb3VuZCBhdDoiCiAgICAgICAgICAgIGVjaG8gIiAgICRmdWxsX2Jpbl9wYXRoIgogICAgICAgICAgICByZXR1cm4gMQogICAgICAgIGVsc2UKICAgICAgICAgICAgIyAyLiBDbGVhbiBQQVRICiAgICAgICAgICAgICMgV2UgcmVtb3ZlIGFueSBwYXRoIGNvbnRhaW5pbmcgdGhlIEZMVVRURVJfUkVQT19ST09UIHRvIGF2b2lkIGNvbmZsaWN0cwogICAgICAgICAgICAjIFRoaXMgcHJldmVudHMgaGF2aW5nIGJvdGggJ21hc3RlcicgYW5kICdzdGFibGUnIGluIFBBVEggYXQgdGhlIHNhbWUgdGltZQogICAgICAgICAgICAjIFVzZSAtRiB0byBlbnN1cmUgZml4ZWQgc3RyaW5nIG1hdGNoaW5nIChubyByZWdleCkKICAgICAgICAgICAgbG9jYWwgbmV3X3BhdGg9JChlY2hvICIkUEFUSCIgfCB0ciAnOicgJ1xuJyB8IGdyZXAgLXZGICIkRkxVVFRFUl9SRVBPX1JPT1QiIHwgdHIgJ1xuJyAnOicgfCBzZWQgJ3MvOiQvLycpCgogICAgICAgICAgICAjIDMuIFVwZGF0ZSBQQVRICiAgICAgICAgICAgICMgUHJlcGVuZCB0aGUgbmV3IHRhcmdldCdzIGJpbiBkaXJlY3RvcnkgKGFuZCBldCBwYXRoIGlmIGl0IGV4aXN0cykKICAgICAgICAgICAgaWYgW1sgLWQgIiRldF9iaW5fcGF0aCIgXV07IHRoZW4KICAgICAgICAgICAgICAgIGV4cG9ydCBQQVRIPSIkZnVsbF9iaW5fcGF0aDokZXRfYmluX3BhdGg6JG5ld19wYXRoIgogICAgICAgICAgICBlbHNlCiAgICAgICAgICAgICAgICBleHBvcnQgUEFUSD0iJGZ1bGxfYmluX3BhdGg6JG5ld19wYXRoIgogICAgICAgICAgICBmaQoKICAgICAgICAgICAgIyA0LiBWZXJpZnkKICAgICAgICAgICAgZWNobyAi4pyFIFN3aXRjaGVkIHRvIEZsdXR0ZXIgJGRpcl9uYW1lIgogICAgICAgICAgICBlY2hvICIgICBGbHV0dGVyOiAkKHdoaWNoIGZsdXR0ZXIpIgogICAgICAgICAgICBlY2hvICIgICBEYXJ0OiAgICAkKHdoaWNoIGRhcnQpIgogICAgICAgIGZpCiAgICBmaQp9CgpfZnN3aXRjaF9jb21wbGV0aW9uKCkgewogICAgbG9jYWwgY3VyPSIke0NPTVBfV09SRFNbQ09NUF9DV09SRF19IgogICAgbG9jYWwgdGFyZ2V0cz0oKQoKICAgIHdoaWxlIHJlYWQgLXIgd3RfcGF0aCBoYXNoIGJyYW5jaF9pbmZvIHJlc3Q7IGRvCiAgICAgICAgbG9jYWwgZGlyX25hbWU9IiR7d3RfcGF0aCMkRkxVVFRFUl9SRVBPX1JPT1QvfSIKICAgICAgICBpZiBbWyAiJGRpcl9uYW1lIiA9PSAiJHd0X3BhdGgiICYmICIkd3RfcGF0aCIgPT0gIiRGTFVUVEVSX1JFUE9fUk9PVCIgXV07IHRoZW4KICAgICAgICAgICAgZGlyX25hbWU9IiR7d3RfcGF0aCMjKi99IgogICAgICAgIGZpCiAgICAgICAgbG9jYWwgYnJhbmNoX25hbWU9IiR7YnJhbmNoX2luZm8jXFt9IgogICAgICAgIGJyYW5jaF9uYW1lPSIke2JyYW5jaF9uYW1lJVxdfSIKCiAgICAgICAgdGFyZ2V0cys9KCIkZGlyX25hbWUiKQogICAgICAgIGlmIFsgLW4gIiRicmFuY2hfbmFtZSIgXTsgdGhlbgogICAgICAgICAgICB0YXJnZXRzKz0oIiRicmFuY2hfbmFtZSIpCiAgICAgICAgZmkKICAgIGRvbmUgPCA8KF9mc3dpdGNoX2dldF93b3JrdHJlZV9kYXRhKQoKICAgICMgRGVkdXBsaWNhdGUgYW5kIGdlbmVyYXRlIGNvbXBsZXRpb24KICAgIGxvY2FsIHVuaXF1ZV90YXJnZXRzPSQoZWNobyAiJHt0YXJnZXRzW0BdfSIgfCB0ciAnICcgJ1xuJyB8IHNvcnQgLXUgfCB0ciAnXG4nICcgJykKICAgIENPTVBSRVBMWT0oICQoY29tcGdlbiAtVyAiJHt1bmlxdWVfdGFyZ2V0c30iIC0tICR7Y3VyfSkgKQp9CmNvbXBsZXRlIC1GIF9mc3dpdGNoX2NvbXBsZXRpb24gZnN3aXRjaAoKZmNkKCkgewogICAgbG9jYWwgZmx1dHRlcl9wYXRoCiAgICBmbHV0dGVyX3BhdGg9JChjb21tYW5kIC12IGZsdXR0ZXIpCgogICAgaWYgW1sgLXogIiRmbHV0dGVyX3BhdGgiIF1dOyB0aGVuCiAgICAgICAgZWNobyAi4p2MIEZsdXR0ZXIgY29tbWFuZCBub3QgZm91bmQuIFJ1biAnZnN3aXRjaCA8dGFyZ2V0PicgZmlyc3QuIgogICAgICAgIHJldHVybiAxCiAgICBmaQoKICAgIGxvY2FsIGJpbl9kaXIKICAgIGJpbl9kaXI9JChkaXJuYW1lICIkZmx1dHRlcl9wYXRoIikKCiAgICAjIENoZWNrIGlmIHdlIGFyZSBpbiAnYmluJyBhbmQgZ28gdXAgb25lIGxldmVsCiAgICBpZiBbWyAiJChiYXNlbmFtZSAiJGJpbl9kaXIiKSIgPT0gImJpbiIgXV07IHRoZW4KICAgICAgICBjZCAiJChkaXJuYW1lICIkYmluX2RpciIpIgogICAgZWxzZQogICAgICAgIGNkICIkYmluX2RpciIKICAgIGZpCn0KCmFsaWFzIGZyb290PWZjZAoKIyBPcHRpb25hbDogRGVmYXVsdCB0byBtYXN0ZXIgb24gbG9hZCBpZiBubyBmbHV0dGVyIGlzIGZvdW5kCmlmICEgY29tbWFuZCAtdiBmbHV0dGVyICY+IC9kZXYvbnVsbDsgdGhlbgogICAgZnN3aXRjaCBtYXN0ZXIKICAgIGVjaG8gIuKEue+4jyAgRmx1dHRlciBlbnZpcm9ubWVudCBsb2FkZWQuIFVzZSAnZnN3aXRjaCBzdGFibGUnIG9yICdmc3dpdGNoIG1hc3RlcicgdG8gYWN0aXZhdGUuIgpmaQo="
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
