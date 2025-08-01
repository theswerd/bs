#!/usr/bin/env bash
# Constants and shared variables

# Database configuration
readonly GLOBAL_DB="${HOME}/.bs.json"
readonly LOCAL_DB=".bs.json"
DB="$GLOBAL_DB"  # Default to global
LOCAL_MODE=false

# Reserved commands for future features
readonly RESERVED_COMMANDS=("api" "mcp" "export" "info" "version")

# Application metadata
readonly BS_NAME="Ben's BS Manager"
readonly BS_VERSION="1.0.0"
readonly BS_DESCRIPTION="A hierarchical bash script manager"

# Set database location based on --local flag
set_local_mode() {
  LOCAL_MODE=true
  DB="$LOCAL_DB"
}

# Find all .bs.json files from current directory up to home directory
find_all_databases() {
  local databases=()
  local current_dir="$(pwd)"
  local home_dir="$(cd ~ && pwd)"

  # If in local mode, only use current directory
  if [[ "$LOCAL_MODE" == "true" ]]; then
    if [[ -f "$LOCAL_DB" ]]; then
      databases+=("$LOCAL_DB")
    fi
  else
    # Search from current directory up to home directory
    while [[ "$current_dir" != "/" && "$current_dir" == "$home_dir"* ]]; do
      if [[ -f "$current_dir/.bs.json" ]]; then
        databases+=("$current_dir/.bs.json")
      fi

      # Stop if we've reached home directory
      if [[ "$current_dir" == "$home_dir" ]]; then
        break
      fi

      # Move up one directory
      current_dir="$(dirname "$current_dir")"
    done

    # Always include the global database as fallback
    if [[ -f "$GLOBAL_DB" ]]; then
      databases+=("$GLOBAL_DB")
    fi
  fi

  printf '%s\n' "${databases[@]}"
}

# Reserved command validation
is_reserved_command() {
  local cmd="$1"
  for reserved in "${RESERVED_COMMANDS[@]}"; do
    if [[ "$cmd" == "$reserved" ]]; then
      return 0
    fi
  done
  return 1
}
