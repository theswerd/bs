#!/usr/bin/env bash
# Configuration and global variables

GLOBAL_DB="${HOME}/.bs.json"
LOCAL_DB=".bs.json"
DB="$GLOBAL_DB"  # Default to global
LOCAL_MODE=false

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
      current_dir="$(dirname "$current_dir")"
    done

    # Always include global database last (lowest priority)
    if [[ -f "$GLOBAL_DB" ]]; then
      databases+=("$GLOBAL_DB")
    fi
  fi

  printf '%s\n' "${databases[@]}"
}

# Get the primary database for writing (first found or global)
get_primary_database() {
  if [[ "$LOCAL_MODE" == "true" ]]; then
    echo "$LOCAL_DB"
  else
    local databases
    databases=($(find_all_databases))
    if [[ ${#databases[@]} -gt 0 ]]; then
      echo "${databases[0]}"
    else
      echo "$GLOBAL_DB"
    fi
  fi
}

# Ensure DB exists
ensure_db() {
  local primary_db
  primary_db=$(get_primary_database)
  [[ -f "$primary_db" ]] || echo '{}' > "$primary_db"
  DB="$primary_db"
}

# Check dependencies
check_dependencies() {
  command -v jq >/dev/null 2>&1 || {
    echo "jq is required but not installed" >&2
    exit 1
  }
}

# Migrate old format to new format if needed
migrate_db_format() {
  local databases
  databases=($(find_all_databases))

  for db_file in "${databases[@]}"; do
    if [[ -f "$db_file" ]]; then
      # Check if this is the old format (string values) vs new format (object values)
      local has_old_format
      has_old_format=$(jq -r 'to_entries | map(select(.value | type == "string")) | length > 0' "$db_file" 2>/dev/null || echo "false")

      if [[ "$has_old_format" == "true" ]]; then
        echo "Migrating database format in $db_file..." >&2
        local tmp
        tmp=$(mktemp) || {
          echo "Error: Failed to create temporary file for migration" >&2
          return 1
        }

        # Convert old format to new format
        jq 'to_entries | map({(.key): {command: .value, notes: ""}}) | add // {}' "$db_file" > "$tmp" && mv "$tmp" "$db_file"
        echo "Migration complete for $db_file." >&2
      fi
    fi
  done
}
