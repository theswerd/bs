#!/usr/bin/env bash
# Tab completion functionality

generate_completion_script() {
  # Get reserved commands from consts.sh for use in completion script
  local reserved_list=""
  for cmd in "${RESERVED_COMMANDS[@]}"; do
    if [[ -n "$reserved_list" ]]; then
      reserved_list="$reserved_list|$cmd"
    else
      reserved_list="$cmd"
    fi
  done

  cat <<COMPLETION_SCRIPT
# Bash completion for bs command
#
# For Bash, add this to your ~/.bashrc or ~/.bash_profile:
# eval "\$(bs completion)"
#
# For Zsh, add this to your ~/.zshrc:
# autoload -U +X compinit && compinit
# autoload -U +X bashcompinit && bashcompinit
# eval "\$(bs completion)"

_bs_completion() {
  local cur prev opts
  COMPREPLY=()
  cur="\${COMP_WORDS[COMP_CWORD]}"
  prev="\${COMP_WORDS[COMP_CWORD-1]}"

  # Helper function to get stored commands from all databases
  _get_all_stored_commands() {
    local local_mode=false
    local current_dir="\$(pwd)"
    local home_dir="\$(cd ~ && pwd)"
    local databases=()
    local all_commands="{}"

    # Check for --local flag in command line
    for word in "\${COMP_WORDS[@]}"; do
      if [[ "\$word" == "--local" ]]; then
        local_mode=true
        break
      fi
    done

    # Use same logic as find_all_databases from consts.sh
    if [[ "\$local_mode" == "true" ]]; then
      if [[ -f ".bs.json" ]]; then
        databases+=(".bs.json")
      fi
    else
      # Search from current directory up to home directory
      while [[ "\$current_dir" != "/" && "\$current_dir" == "\$home_dir"* ]]; do
        if [[ -f "\$current_dir/.bs.json" ]]; then
          databases+=("\$current_dir/.bs.json")
        fi

        # Stop if we've reached home directory
        if [[ "\$current_dir" == "\$home_dir" ]]; then
          break
        fi

        # Move up one directory
        current_dir="\$(dirname "\$current_dir")"
      done

      # Always include the global database as fallback
      if [[ -f "\${HOME}/.bs.json" ]]; then
        databases+=("\${HOME}/.bs.json")
      fi
    fi

    # Merge all databases
    for db_file in "\${databases[@]}"; do
      if [[ -f "\$db_file" ]]; then
        local tmp_file
        tmp_file=\$(mktemp 2>/dev/null) || continue
        jq -s '.[0] * .[1]' <(echo "\$all_commands") "\$db_file" > "\$tmp_file" 2>/dev/null
        all_commands=\$(cat "\$tmp_file" 2>/dev/null || echo "{}")
        rm -f "\$tmp_file"
      fi
    done

    echo "\$all_commands" | jq -r 'keys[]' 2>/dev/null | while read -r cmd; do
      # Filter out reserved commands (injected from consts.sh)
      case "\$cmd" in
        $reserved_list)
          # Skip reserved commands
          ;;
        *)
          echo "\$cmd"
          ;;
      esac
    done
  }

  # Handle --local flag and global options
  local word_index=1
  if [[ \${#COMP_WORDS[@]} -gt 2 && "\${COMP_WORDS[1]}" == "--local" ]]; then
    word_index=2
  fi

  # First argument completions (or second if --local is present)
  if [[ \$COMP_CWORD -eq \$word_index ]]; then
    local subcommands="--local add rm ls help completion"
    local stored_commands=""
    stored_commands=\$(_get_all_stored_commands)
    opts="\$subcommands \$stored_commands"
    COMPREPLY=( \$(compgen -W "\$opts" -- "\$cur") )
    return 0
  fi

  # Command-specific completions
  local command="\${COMP_WORDS[\$word_index]}"
  case "\$command" in
    add)
      # Complete with flags after the command name
      if [[ \${#COMP_WORDS[@]} -gt \$((\$word_index + 2)) ]]; then
        case "\$prev" in
          --notes|-n)
            # No completion for notes text
            return 0
            ;;
          --dir|-d)
            # Complete with directories
            COMPREPLY=( \$(compgen -d -- "\$cur") )
            return 0
            ;;
          *)
            COMPREPLY=( \$(compgen -W "--notes -n --dir -d --cd" -- "\$cur") )
            return 0
            ;;
        esac
      fi
      ;;
    rm)
      # Complete with stored command names for removal (multiple allowed)
      if [[ \${#COMP_WORDS[@]} -ge \$((\$word_index + 2)) ]]; then
        local stored_commands
        stored_commands=\$(_get_all_stored_commands)
        COMPREPLY=( \$(compgen -W "\$stored_commands" -- "\$cur") )
      fi
      return 0
      ;;
    ls)
      # Complete with stored command names as prefix filters
      if [[ \${#COMP_WORDS[@]} -eq \$((\$word_index + 2)) ]]; then
        local stored_commands
        stored_commands=\$(_get_all_stored_commands)
        COMPREPLY=( \$(compgen -W "\$stored_commands" -- "\$cur") )
      fi
      return 0
      ;;
  esac
}

complete -F _bs_completion bs
complete -F _bs_completion bs.sh
complete -F _bs_completion ./bs.sh
COMPLETION_SCRIPT
}
