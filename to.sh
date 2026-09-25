#!/usr/bin/env bash
set -euo pipefail

# to — jump to a directory shortcut (bash/zsh).
#
# The `to` command works as a SHELL FUNCTION so it can "cd" in your current
# shell. To use it, source this file from your shell config, e.g.:
#
#   . ~/tools/to/to.sh       # bash
#   source ~/tools/to/to.sh  # zsh
#
# Then:  to dev   to config   to tools   to home   to lento   to workspace
# Help:  to (no args) or `to --help`
# Add:   to add <path> [name]
# Remove: to remove <name>
# Path:   to path <name>

_is_zsh=0
[[ -n ${BASH_VERSION:-} ]] || _is_zsh=1

if [[ $_is_zsh -eq 1 ]]; then
  _to_keys=(home dev projects config tools lento workspace)
  _to_dirs=(
    "$HOME"
    "$HOME/dev"
    "$HOME/dev/projects"
    "$HOME/.config"
    "$HOME/tools"
    "$HOME/dev/projects/lento"
    "/"
  )
else
  declare -A DIRS=(
    [home]="$HOME"
    [dev]="$HOME/dev"
    [projects]="$HOME/dev/projects"
    [config]="$HOME/.config"
    [tools]="$HOME/tools"
    [lento]="$HOME/dev/projects/lento"
    [workspace]="/"
  )
fi

# Load user-defined shortcuts from mapping file
_to_mapping_file="${HOME}/.config/to/mapping"
if [[ -f "$_to_mapping_file" ]]; then
  while IFS='=' read -r name path; do
    [[ -z "$name" || "$name" =~ ^# ]] && continue
    if [[ $_is_zsh -eq 1 ]]; then
      name="${name:l}"
    else
      name="${name,,}"
    fi
    _exists=0
    if [[ $_is_zsh -eq 1 ]]; then
      for _k in "${_to_keys[@]}"; do [[ "$_k" == "$name" ]] && { _exists=1; break; }; done
    else
      [[ -v "DIRS[$name]" ]] && _exists=1
    fi
    [[ $_exists -eq 1 ]] && continue
    if [[ $_is_zsh -eq 1 ]]; then
      _to_keys+=("$name")
      _to_dirs+=("$path")
    else
      DIRS["$name"]="$path"
    fi
  done < "$_to_mapping_file"
fi

_to_usage() {
  echo "Usage: to <shortcut>"
  echo "       to add <path> [name]"
  echo "       to path <name>"
  echo
  echo "Available shortcuts:"
  if [[ $_is_zsh -eq 1 ]]; then
    local i
    for i in {1..${#_to_keys[@]}}; do
      printf "  %-12s -> %s\n" "${_to_keys[$i]}" "${_to_dirs[$i]}"
    done
  else
    local key
    while IFS= read -r key; do
      printf "  %-12s -> %s\n" "$key" "${DIRS[$key]}"
    done < <(printf '%s\n' "${!DIRS[@]}" | sort)
  fi
  echo
}

_to() {
  if [[ $# -eq 0 ]]; then
    _to_usage
    return 0
  fi
  local cmd
  if [[ $_is_zsh -eq 1 ]]; then
    cmd="${1:l}"
  else
    cmd="${1,,}"
  fi
  case "$cmd" in
    -h|--help) _to_usage; return 0 ;;
    add)
      if [[ $# -lt 2 ]]; then
        echo "Usage: to add <path> [name]" >&2
        return 1
      fi
      local add_path="$2"
      local add_name="${3:-}"
      if [[ $_is_zsh -eq 1 ]]; then
        add_name="${add_name:l}"
      else
        add_name="${add_name,,}"
      fi
      if [[ ! -e "$add_path" ]]; then
        echo "Error: path '$add_path' does not exist." >&2
        return 1
      fi
      local resolved
      resolved="$(cd "$add_path" && pwd)" || {
        echo "Error: cannot resolve '$add_path'." >&2
        return 1
      }
      if [[ -z "$add_name" ]]; then
        add_name="${resolved##*/}"
        [[ "$add_name" == "" ]] && add_name="/"
        if [[ $_is_zsh -eq 1 ]]; then
          add_name="${add_name:l}"
        else
          add_name="${add_name,,}"
        fi
      fi
      local mapping_file="${HOME}/.config/to/mapping"
      mkdir -p "$(dirname "$mapping_file")"
      if [[ -f "$mapping_file" ]]; then
        grep -iv "^${add_name}=" "$mapping_file" > "${mapping_file}.tmp" 2>/dev/null || true
        mv "${mapping_file}.tmp" "$mapping_file"
      fi
      printf '%s=%s\n' "$add_name" "$resolved" >> "$mapping_file"
      echo "Added $add_name -> $resolved"
      if [[ $_is_zsh -eq 1 ]]; then
        _to_keys+=("$add_name")
        _to_dirs+=("$resolved")
      else
        DIRS["$add_name"]="$resolved"
      fi
      return 0
      ;;
    remove)
      if [[ $# -lt 2 ]]; then
        echo "Usage: to remove <name>" >&2
        return 1
      fi
      if [[ $_is_zsh -eq 1 ]]; then
        rm_name="${2:l}"
      else
        rm_name="${2,,}"
      fi
      local mapping_file="${HOME}/.config/to/mapping"
      if [[ ! -f "$mapping_file" ]]; then
        echo "Error: no mappings file." >&2
        return 1
      fi
      if ! grep -iq "^${rm_name}=" "$mapping_file" 2>/dev/null; then
        echo "Error: shortcut '$rm_name' not found in mappings." >&2
        return 1
      fi
      grep -iv "^${rm_name}=" "$mapping_file" > "${mapping_file}.tmp" 2>/dev/null || true
      mv "${mapping_file}.tmp" "$mapping_file"
      # Remove from in-memory arrays
      if [[ $_is_zsh -eq 1 ]]; then
        local new_keys=() new_dirs=() i
        for i in {1..${#_to_keys[@]}}; do
          [[ "${_to_keys[$i]}" != "$rm_name" ]] && { new_keys+=("${_to_keys[$i]}"); new_dirs+=("${_to_dirs[$i]}"); }
        done
        _to_keys=("${new_keys[@]}")
        _to_dirs=("${new_dirs[@]}")
      else
        unset "DIRS[$rm_name]"
      fi
      echo "Removed $rm_name"
      return 0
      ;;
    path)
      if [[ $# -lt 2 ]]; then
        echo "Usage: to path <name>" >&2
        return 1
      fi
      local path_target
      if [[ $_is_zsh -eq 1 ]]; then
        path_target="${2:l}"
      else
        path_target="${2,,}"
      fi
      local path_dir=""
      local i
      if [[ $_is_zsh -eq 1 ]]; then
        for i in {1..${#_to_keys[@]}}; do
          if [[ "$path_target" == "${_to_keys[$i]}" ]]; then
            path_dir="${_to_dirs[$i]}"
            break
          fi
        done
      else
        if [[ -v "DIRS[$path_target]" ]]; then
          path_dir="${DIRS[$path_target]}"
        fi
      fi
      if [[ -z "$path_dir" ]]; then
        echo "Error: unknown shortcut '$path_target'." >&2
        return 1
      fi
      if [[ ! -d "$path_dir" ]]; then
        echo "Error: target directory '$path_dir' does not exist." >&2
        return 1
      fi
      printf '%s\n' "$path_dir"
      return 0
      ;;
  esac

  local target="$cmd"
  local dir=""
  local i
  if [[ $_is_zsh -eq 1 ]]; then
    for i in {1..${#_to_keys[@]}}; do
      if [[ "$target" == "${_to_keys[$i]}" ]]; then
        dir="${_to_dirs[$i]}"
        break
      fi
    done
  else
    if [[ -v "DIRS[$target]" ]]; then
      dir="${DIRS[$target]}"
    fi
  fi

  if [[ -z "$dir" ]]; then
    echo "Error: unknown shortcut '$target'." >&2
    echo >&2
    _to_usage >&2
    return 1
  fi

  if [[ ! -d "$dir" ]]; then
    echo "Error: target directory '$dir' does not exist." >&2
    return 1
  fi

  cd "$dir"
}

# When sourced, expose `to` as a shell function so cd affects the current shell.
if [[ $_is_zsh -eq 1 ]]; then
  if [[ $ZSH_EVAL_CONTEXT != toplevel ]]; then
    to() { _to "$@"; }
    return 0
  fi
else
  if [[ -n $BASH_SOURCE && $BASH_SOURCE != $0 ]]; then
    to() { _to "$@"; }
    return 0
  fi
fi

# Direct execution (e.g. ~/tools/to/to.sh dev): a subshell cd won't persist, so
# just print the resolved directory path for use in scripts/command substitution.
if [[ $# -eq 0 || "$1" == "-h" || "$1" == "--help" ]]; then
  _to_usage
  exit 0
fi

resolve_dir() {
  local target="$1"
  local i
  if [[ $_is_zsh -eq 1 ]]; then
    for i in {1..${#_to_keys[@]}}; do
      [[ "$target" == "${_to_keys[$i]}" ]] && { printf '%s' "${_to_dirs[$i]}"; return 0; }
    done
  else
    [[ -v "DIRS[$target]" ]] && { printf '%s' "${DIRS[$target]}"; return 0; }
  fi
  return 1
}

if [[ $_is_zsh -eq 1 ]]; then
  target="${1:l}"
else
  target="${1,,}"
fi
if [[ "$target" == "path" ]]; then
  if [[ $# -lt 2 ]]; then
    echo "Usage: to path <name>" >&2
    exit 1
  fi
  if [[ $_is_zsh -eq 1 ]]; then
    target="${2:l}"
  else
    target="${2,,}"
  fi
fi
dir=""
dir="$(resolve_dir "$target")" || {
  echo "Error: unknown shortcut '$target'." >&2
  exit 1
}
if [[ ! -d "$dir" ]]; then
  echo "Error: target directory '$dir' does not exist." >&2
  exit 1
fi
printf '%s\n' "$dir"
