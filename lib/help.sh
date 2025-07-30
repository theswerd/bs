#!/usr/bin/env bash
# Help and usage information

show_usage() {
  cat <<HELP_EOF
bs - Ben's BS Manager

USAGE:
    bs [--local] <command> [options]

GLOBAL OPTIONS:
    --local                   Use local .bs.json in current directory only

COMMANDS:
    add <name> <command...>   Add or replace a command entry
        --notes, -n           Add notes for the command
    rm  <name...>             Remove one or more command entries
    ls  [prefix]              List entries (optional prefix filter)
    completion                Output bash completion script
    help                      Show this help message

To enable tab completion, add this to your shell profile:
    eval "\$(bs completion)"

HELP_EOF
}
