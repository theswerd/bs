#!/usr/bin/env bash
# Command management functions

add_command() {
  local name=""
  local notes=""
  local cmd_args=()

  # Parse arguments for --notes/-n flag
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

  # ANSI color codes
  local BOLD='\033[1m'
  local CYAN='\033[36m'
  local RESET='\033[0m'

  local tmp
  tmp=$(mktemp) || {
    echo "Error: Failed to create temporary file" >&2
    return 1
  }

  # Add command with new JSON structure to primary database
  jq --arg n "$name" --arg c "$cmd" --arg notes "$notes" \
    '.[$n] = {command: $c, notes: $notes}' "$DB" >"$tmp" && mv "$tmp" "$DB"

  printf "Added command ${BOLD}%s${RESET} to ${CYAN}%s${RESET}\n" "$name" "$DB" >&2
}

remove_command() {
  [[ $# -gt 0 ]] || {
    echo "Error: At least one command name is required" >&2
    return 1
  }

  # ANSI color codes
  local BOLD='\033[1m'
  local CYAN='\033[36m'
  local RESET='\033[0m'

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
      printf "Warning: Command ${BOLD}%s${RESET} not found\n" "$name" >&2
      failed_removals+=("$name")
      continue
    fi

    local tmp
    tmp=$(mktemp) || {
      printf "Error: Failed to create temporary file for ${BOLD}%s${RESET}\n" "$name" >&2
      failed_removals+=("$name")
      continue
    }

    if jq --arg n "$name" 'del(.[$n])' "$found_db" >"$tmp" && mv "$tmp" "$found_db"; then
      printf "Removed command ${BOLD}%s${RESET} from ${CYAN}%s${RESET}\n" "$name" "$found_db" >&2
      ((removal_count++))
    else
      printf "Error: Failed to remove command ${BOLD}%s${RESET}\n" "$name" >&2
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
      printf "${BOLD}%s${RESET}" "${failed_removals[$i]}"
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

  # ANSI color codes
  local BOLD='\033[1m'
  local BLUE='\033[34m'
  local GRAY='\033[90m'
  local RESET='\033[0m'

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

    if [[ -n "$notes" && "$notes" != "null" && "$notes" != "" ]]; then
      printf "${BOLD}%s${RESET}: ${BLUE}%s${RESET} ${GRAY}[%s]${RESET}\n" "$name" "$command" "$notes"
    else
      printf "${BOLD}%s${RESET}: ${BLUE}%s${RESET}\n" "$name" "$command"
    fi
  }

  if [[ -z "$prefix" ]]; then
    # List all commands with colored formatting
    echo "$all_commands" | jq -r 'to_entries[] | "\(.key)\t\(.value.command)\t\(.value.notes // "")"' | \
    while IFS=$'\t' read -r name command notes; do
      format_command "$name" "$command" "$notes"
    done
  else
    # List commands matching prefix with colored formatting
    echo "$all_commands" | jq -r --arg p "$prefix" 'to_entries[] | select(.key|startswith($p)) | "\(.key)\t\(.value.command)\t\(.value.notes // "")"' | \
    while IFS=$'\t' read -r name command notes; do
      format_command "$name" "$command" "$notes"
    done
  fi
}

run_command() {
  local name="$1"
  shift

  local databases
  databases=($(find_all_databases))
  local cmd=""

  # Search through databases in order (first match wins)
  for db_file in "${databases[@]}"; do
    if [[ -f "$db_file" ]]; then
      # Handle both old format (string) and new format (object)
      cmd=$(jq -r --arg n "$name" '
        if .[$n] then
          if (.[$n] | type) == "string" then
            .[$n]
          else
            .[$n].command
          end
        else
          empty
        end' "$db_file" 2>/dev/null)

      if [[ -n "$cmd" ]]; then
        break
      fi
    fi
  done

  [[ -n "$cmd" ]] || {
    echo "bs: no such command '$name'" >&2
    return 1
  }

  eval "$cmd" "$@"
}
