#!/usr/bin/env bash
# Command management functions

add_command() {
  local name=""
  local notes=""
  local directory=""
  local cmd_args=()

  # Parse arguments for --notes/-n, --dir/-d, and --here flags
  while [[ $# -gt 0 ]]; do
    case $1 in
      --notes|-n)
        [[ -n "$2" ]] || {
          echo "Error: --notes/-n requires a value" >&2
          return 1
        }
        notes="$2"
        shift 2
        ;;
      --dir|-d)
        [[ -n "$2" ]] || {
          echo "Error: --dir/-d requires a directory path" >&2
          return 1
        }
        # Convert to absolute path
        directory="$(cd "$2" 2>/dev/null && pwd)" || {
          echo "Error: Directory '$2' does not exist or is not accessible" >&2
          return 1
        }
        shift 2
        ;;
      --cd)
        # Use current directory
        directory="$(pwd)"
        shift
        ;;
      *)
        if [[ -z "$name" ]]; then
          name="$1"
          shift
        else
          # Rest of arguments form the command
          cmd_args+=("$1")
          shift
        fi
        ;;
    esac
  done

  [[ -n "$name" ]] || {
    echo "Error: Command name is required" >&2
    return 1
  }

  [[ ${#cmd_args[@]} -gt 0 ]] || {
    echo "Error: Command is required" >&2
    return 1
  }

  # Join command arguments
  local cmd="${cmd_args[*]}"

  local tmp
  tmp=$(mktemp) || {
    echo "Error: Failed to create temporary file" >&2
    return 1
  }

  # Add command with new JSON structure to primary database
  jq --arg n "$name" --arg c "$cmd" --arg notes "$notes" --arg dir "$directory" \
    '.[$n] = {command: $c, notes: $notes, directory: $dir}' "$DB" >"$tmp" && mv "$tmp" "$DB"

  if [[ -n "$directory" ]]; then
    printf "Added command $(color_bold "%s") to $(color_cyan "%s") (runs in $(color_cyan "%s"))\n" "$name" "$DB" "$directory" >&2
  else
    printf "Added command $(color_bold "%s") to $(color_cyan "%s")\n" "$name" "$DB" >&2
  fi
}

remove_command() {
  [[ $# -gt 0 ]] || {
    echo "Error: At least one command name is required" >&2
    return 1
  }

  local databases
  databases=($(find_all_databases))
  local removal_count=0
  local failed_removals=()

  # Process each command name
  for name in "$@"; do
    local found_db=""

    # Find which database contains the command
    for db_file in "${databases[@]}"; do
      if [[ -f "$db_file" ]]; then
        local exists
        exists=$(jq -r --arg n "$name" 'has($n)' "$db_file" 2>/dev/null || echo "false")
        if [[ "$exists" == "true" ]]; then
          found_db="$db_file"
          break
        fi
      fi
    done

    if [[ -z "$found_db" ]]; then
      printf "Warning: Command $(color_bold "%s") not found\n" "$name" >&2
      failed_removals+=("$name")
      continue
    fi

    local tmp
    tmp=$(mktemp) || {
      printf "Error: Failed to create temporary file for $(color_bold "%s")\n" "$name" >&2
      failed_removals+=("$name")
      continue
    }

    if jq --arg n "$name" 'del(.[$n])' "$found_db" >"$tmp" && mv "$tmp" "$found_db"; then
      printf "Removed command $(color_bold "%s") from $(color_cyan "%s")\n" "$name" "$found_db" >&2
      ((removal_count++))
    else
      printf "Error: Failed to remove command $(color_bold "%s")\n" "$name" >&2
      failed_removals+=("$name")
      rm -f "$tmp"
    fi
  done

  # Summary
  if [[ $removal_count -gt 0 ]]; then
    echo "Successfully removed $removal_count command(s)" >&2
  fi

  if [[ ${#failed_removals[@]} -gt 0 ]]; then
    printf "Failed to remove: "
    for i in "${!failed_removals[@]}"; do
      if [[ $i -gt 0 ]]; then printf ", "; fi
      printf "$(color_bold "%s")" "${failed_removals[$i]}"
    done
    printf "\n"
    return 1
  fi

  return 0
}

list_commands() {
  local prefix="${1-}"
  local databases
  databases=($(find_all_databases))
  local all_commands="{}"

  # Merge all databases (later ones override earlier ones)
  for db_file in "${databases[@]}"; do
    if [[ -f "$db_file" ]]; then
      local tmp
      tmp=$(mktemp) || {
        echo "Error: Failed to create temporary file" >&2
        return 1
      }
      # Merge databases, with current file taking precedence
      jq -s '.[0] * .[1]' <(echo "$all_commands") "$db_file" > "$tmp"
      all_commands=$(cat "$tmp")
      rm "$tmp"
    fi
  done

  if [[ "$all_commands" == "{}" ]]; then
    echo "No commands found" >&2
    return 1
  fi

  # Function to format a single command entry
  format_command() {
    local name="$1"
    local command="$2"
    local notes="$3"
    local directory="$4"

    # Build the base line: name: command
    local line="$(color_bold "$name"): $(color_blue "$command")"

    # Add notes in brackets if present
    if [[ -n "$notes" && "$notes" != "null" && "$notes" != "" ]]; then
      line+=" $(color_gray "[$notes]")"
    fi

    # Add directory in parentheses if present
    if [[ -n "$directory" && "$directory" != "null" && "$directory" != "" ]]; then
      line+=" $(color_gray "(runs in $(color_cyan "$directory"))")"
    fi

    printf "%s\n" "$line"
  }

  if [[ -z "$prefix" ]]; then
    # List all commands with colored formatting
    echo "$all_commands" | jq -r 'to_entries[] | "\(.key)\t\(.value.command)\t\(.value.notes // "")\t\(.value.directory // "")"' | \
    while IFS=$'\t' read -r name command notes directory; do
      format_command "$name" "$command" "$notes" "$directory"
    done
  else
    # List commands matching prefix with colored formatting
    echo "$all_commands" | jq -r --arg p "$prefix" 'to_entries[] | select(.key|startswith($p)) | "\(.key)\t\(.value.command)\t\(.value.notes // "")\t\(.value.directory // "")"' | \
    while IFS=$'\t' read -r name command notes directory; do
      format_command "$name" "$command" "$notes" "$directory"
    done
  fi
}

run_command() {
  local name="$1"
  shift

  local databases
  databases=($(find_all_databases))
  local cmd=""
  local directory=""

  # Search through databases in order (first match wins)
  for db_file in "${databases[@]}"; do
    if [[ -f "$db_file" ]]; then
      # Handle both old format (string) and new format (object)
      local result
      result=$(jq -r --arg n "$name" '
        if .[$n] then
          if (.[$n] | type) == "string" then
            "\(.[$n])\t"
          else
            "\(.[$n].command)\t\(.[$n].directory // "")"
          end
        else
          empty
        end' "$db_file" 2>/dev/null)

      if [[ -n "$result" ]]; then
        IFS=$'\t' read -r cmd directory <<< "$result"
        break
      fi
    fi
  done

  [[ -n "$cmd" ]] || {
    echo "bs: no such command '$name'" >&2
    return 1
  }

  # Change to specified directory if provided
  if [[ -n "$directory" && "$directory" != "null" ]]; then
    if [[ -d "$directory" ]]; then
      echo "Running in: $directory" >&2
      cd "$directory" || {
        echo "bs: failed to change to directory '$directory'" >&2
        return 1
      }
    else
      echo "bs: warning: directory '$directory' no longer exists, running in current directory" >&2
    fi
  fi

  eval "$cmd" "$@"
}
