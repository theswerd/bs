#!/usr/bin/env bash
set -euo pipefail

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source all library files (consts.sh must be first)
source "$SCRIPT_DIR/lib/consts.sh"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/help.sh"
source "$SCRIPT_DIR/lib/commands.sh"
source "$SCRIPT_DIR/lib/completion.sh"

# Parse global options first
while [[ $# -gt 0 ]]; do
  case $1 in
    --local)
      set_local_mode
      shift
      ;;
    *)
      break
      ;;
  esac
done

# Initialize after parsing options
ensure_db
check_dependencies
migrate_db_format

# Show help if no arguments
[[ $# -eq 0 ]] && {
  show_usage
  exit 1
}

# Parse command
sub="$1"
shift

case "$sub" in
  add)
    [[ $# -ge 2 ]] || {
      echo "Error: 'add' requires a name and command" >&2
      show_usage
      exit 1
    }
    add_command "$@"
    ;;
  rm)
    [[ $# -ge 1 ]] || {
      echo "Error: 'rm' requires at least one command name" >&2
      show_usage
      exit 1
    }
    remove_command "$@"
    ;;
  ls)
    list_commands "${1-}"
    ;;
  completion)
    generate_completion_script
    ;;
  help|-h|--help)
    show_usage
    ;;
  *)
    # Try to run as stored command
    run_command "$sub" "$@"
    ;;
esac

