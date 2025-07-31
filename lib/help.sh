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
        --dir, -d <path>      Always run command in specified directory
        --cd                  Always run command in current directory
    rm  <name...>             Remove one or more command entries
    ls  [prefix]              List entries (optional prefix filter)
    completion                Output bash completion script
    help                      Show this help message

To enable tab completion:

For Bash, add to ~/.bashrc or ~/.bash_profile:
    eval "\$(bs completion)"

For Zsh, add to ~/.zshrc:
    autoload -U +X compinit && compinit
    autoload -U +X bashcompinit && bashcompinit
    eval "\$(bs completion)"

HELP_EOF
}
