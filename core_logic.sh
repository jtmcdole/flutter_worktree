# Source this file in your .bashrc or .zshrc
# Usage: source $SWITCH_FILE

# Auto-detect the repo root based on this script's location
if [ -n "$BASH_SOURCE" ]; then
    _SCRIPT_PATH="${BASH_SOURCE[0]}"
elif [ -n "$ZSH_VERSION" ]; then
    _SCRIPT_PATH="${(%):-%x}"
else
    _SCRIPT_PATH="$0"
fi

export FLUTTER_REPO_ROOT="$(cd "$(dirname "$_SCRIPT_PATH")" >/dev/null 2>&1 && pwd)"

_fswitch_get_worktree_data() {
    if command -v git &> /dev/null && [ -d "$FLUTTER_REPO_ROOT" ]; then
        git -C "$FLUTTER_REPO_ROOT" worktree list 2>/dev/null | grep -v "(bare)"
    fi
}

_fswitch_resolve() {
    local target=$1
    local resolved=""
    
    while read -r path hash branch_info rest; do
        local rel_path="${path#$FLUTTER_REPO_ROOT/}"
        local is_root=0
        if [[ "$rel_path" == "$path" && "$path" == "$FLUTTER_REPO_ROOT" ]]; then
            rel_path="."
            is_root=1
        fi

        local branch_name="${branch_info#\[}"
        branch_name="${branch_name%\]}"
        
        if [[ "$target" == "$rel_path" ]] || [[ "$target" == "$branch_name" ]]; then
            resolved="$rel_path"
            break
        fi
        
        # Allow matching by root directory name
        if [[ $is_root -eq 1 ]]; then
             local root_name="${path##*/}"
             if [[ "$target" == "$root_name" ]]; then
                  resolved="$rel_path"
                  break
             fi
        fi
    done < <(_fswitch_get_worktree_data)
    
    echo "$resolved"
}

fswitch() {
    local target=$1
    
    # Resolve target to directory (relative path from root, or ".")
    local dir_name=$(_fswitch_resolve "$target")
    
    if [[ -z "$dir_name" ]]; then
        echo "❌ Invalid target: '$target'"
        echo "   Available contexts:"
        _fswitch_get_worktree_data | while read -r path hash branch_info rest; do
             local d="${path#$FLUTTER_REPO_ROOT/}"
             if [[ "$d" == "$path" && "$path" == "$FLUTTER_REPO_ROOT" ]]; then
                 d="."
             fi
             local b="${branch_info#\[}"
             b="${b%\]}"
             echo "   - $d ($b)"
        done
        return 1
    fi
    
    # Check if target bin exists BEFORE destroying PATH
    local full_bin_path="$FLUTTER_REPO_ROOT/$dir_name/bin"
    # Normalize path slightly for display/check (remove /./)
    if [[ "$dir_name" == "." ]]; then
        full_bin_path="$FLUTTER_REPO_ROOT/bin"
    fi

    if [[ ! -d "$full_bin_path" ]]; then
        echo "❌ Error: Flutter bin directory not found at:"
        echo "   $full_bin_path"
        return 1
    fi

    # 2. Clean PATH
    # We remove any path containing the FLUTTER_REPO_ROOT to avoid conflicts
    # This prevents having both 'master' and 'stable' in PATH at the same time
    local new_path=$(echo "$PATH" | tr ':' '\n' | grep -v "$FLUTTER_REPO_ROOT" | tr '\n' ':' | sed 's/:$//')

    # 3. Update PATH
    # Prepend the new target's bin directory
    export PATH="$full_bin_path:$new_path"

    # 4. Verify
    echo "✅ Switched to Flutter $dir_name"
    echo "   Flutter: $(which flutter)"
    echo "   Dart:    $(which dart)"
}

_fswitch_completion() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local targets=()
    
    while read -r path hash branch_info rest; do
        local dir_name="${path#$FLUTTER_REPO_ROOT/}"
        if [[ "$dir_name" == "$path" && "$path" == "$FLUTTER_REPO_ROOT" ]]; then
            dir_name="${path##*/}"
        fi
        local branch_name="${branch_info#\[}"
        branch_name="${branch_name%\]}"
        
        targets+=("$dir_name")
        if [ -n "$branch_name" ]; then
            targets+=("$branch_name")
        fi
    done < <(_fswitch_get_worktree_data)
    
    # Deduplicate and generate completion
    local unique_targets=$(echo "${targets[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ')
    COMPREPLY=( $(compgen -W "${unique_targets}" -- ${cur}) )
}
complete -F _fswitch_completion fswitch

# Optional: Default to master on load if no flutter is found
if ! command -v flutter &> /dev/null; then
    fswitch master
    echo "ℹ️  Flutter environment loaded. Use 'fswitch stable' or 'fswitch master' to activate."
fi
