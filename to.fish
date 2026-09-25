# to — jump to a directory shortcut (fish version).
#
#   to home    to dev    to config    to tools    to lento    to workspace
#   to add /some/path
#   to remove <name>
#   to path <name>
#
# Shortcuts are stored in ~/.config/to/mapping (name=path lines).

set -g _to_dirs_cached \
    "home:$HOME" \
    "dev:$HOME/dev" \
    "projects:$HOME/dev/projects" \
    "config:$HOME/.config" \
    "tools:$HOME/tools" \
    "lento:$HOME/dev/projects/lento" \
    "workspace:/"

function _to_refresh
    set -g _to_dirs_cached \
        "home:$HOME" \
        "dev:$HOME/dev" \
        "projects:$HOME/dev/projects" \
        "config:$HOME/.config" \
        "tools:$HOME/tools" \
        "lento:$HOME/dev/projects/lento" \
        "workspace:/"

    set -l mapping_file "$HOME/.config/to/mapping"
    if test -f "$mapping_file"
        while read -l line
            if test -z "$line"; or string match -q '^#' "$line"
                continue
            end
            set -l parts (string split '=' "$line")
            if test (count $parts) -ge 2
                set -l name (string lower $parts[1])
                set -l path (string join '=' $parts[2..-1])
                # Skip if already in hardcoded list
                set -l _exists 0
                for check in home dev projects config tools lento workspace
                    if test "$name" = "$check"
                        set _exists 1
                        break
                    end
                end
                test $_exists -eq 1; and continue
                set -g _to_dirs_cached $_to_dirs_cached "$name:$path"
            end
        end < "$mapping_file"
    end
end

_to_refresh

function _to_usage
    echo "Usage: to <shortcut>"
    echo "       to add <path> [name]"
    echo "       to path <name>"
    echo
    echo "Available shortcuts:"
    for entry in (printf '%s\n' $_to_dirs_cached | sort)
        set -l key (string split ':' "$entry")[1]
        set -l dir (string split ':' "$entry")[2]
        printf "  %-12s -> %s\n" "$key" "$dir"
    end
    echo
end

function to
    if test (count $argv) -eq 0
        _to_usage
        return 0
    end

    set -l cmd (string lower "$argv[1]")
    if test "$cmd" = "add"
        if test (count $argv) -lt 2
            echo "Usage: to add <path> [name]" >&2
            return 1
        end
        set -l add_path "$argv[2]"
        if test ! -e "$add_path"
            echo "Error: path '$add_path' does not exist." >&2
            return 1
        end
        set -l resolved (cd "$add_path" && pwd)
        set -l add_name
        if test (count $argv) -ge 3
            set add_name "$argv[3]"
        else
            set add_name (basename "$resolved")
            test "$add_name" = "" && set add_name "/"
        end
        set add_name (string lower "$add_name")
        set -l mapping_file "$HOME/.config/to/mapping"
        mkdir -p (dirname "$mapping_file")
        if test -f "$mapping_file"
            set -l temp_file (mktemp)
            grep -iv "^$add_name=" "$mapping_file" > "$temp_file" 2>/dev/null || true
            mv "$temp_file" "$mapping_file"
        end
        echo "$add_name=$resolved" >> "$mapping_file"
        echo "Added $add_name -> $resolved"
        _to_refresh
        return 0
    end

    if test "$cmd" = "remove"
        if test (count $argv) -lt 2
            echo "Usage: to remove <name>" >&2
            return 1
        end
        set -l rm_name (string lower "$argv[2]")
        set -l mapping_file "$HOME/.config/to/mapping"
        if not test -f "$mapping_file"
            echo "Error: no mappings file." >&2
            return 1
        end
        if not grep -iq "^$rm_name=" "$mapping_file" 2>/dev/null
            echo "Error: shortcut '$rm_name' not found in mappings." >&2
            return 1
        end
        set -l temp_file (mktemp)
        grep -iv "^$rm_name=" "$mapping_file" > "$temp_file" 2>/dev/null || true
        mv "$temp_file" "$mapping_file"
        _to_refresh
        echo "Removed $rm_name"
        return 0
    end

    if test "$cmd" = "path"
        if test (count $argv) -lt 2
            echo "Usage: to path <name>" >&2
            return 1
        end
        set -l name (string lower "$argv[2]")
        for entry in $_to_dirs_cached
            set -l key (string split ':' "$entry")[1]
            set -l dir (string split ':' "$entry")[2]
            if test "$name" = "$key"
                if test -d "$dir"
                    printf '%s\n' "$dir"
                    return 0
                else
                    echo "Error: target directory '$dir' does not exist." >&2
                    return 1
                end
            end
        end
        echo "Error: unknown shortcut '$name'." >&2
        return 1
    end

    set -l name "$cmd"
    for entry in $_to_dirs_cached
        set -l key (string split ':' "$entry")[1]
        set -l dir (string split ':' "$entry")[2]
        if test "$name" = "$key"
            if test -d "$dir"
                cd "$dir"
                return 0
            else
                echo "Error: target directory '$dir' does not exist." >&2
                return 1
            end
        end
    end
    echo "Error: unknown shortcut '$name'." >&2
    echo >&2
    _to_usage >&2
    return 1
end

function _to_completions
    for entry in $_to_dirs_cached
        set -l key (string split ':' "$entry")[1]
        set -l dir (string split ':' "$entry")[2]
        if test -d "$dir"
            printf "%s\t%s\n" "$key" "$dir"
        end
    end
end

complete -c to -f -a '(_to_completions)'
