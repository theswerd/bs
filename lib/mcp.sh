#!/usr/bin/env bash
# BS MCP Server - MCP implementation for bs command manager

# Source the generic MCP protocol
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/mcp-protocol.sh"

# Source bs libraries for access to commands and constants
source "$SCRIPT_DIR/consts.sh"
source "$SCRIPT_DIR/colors.sh"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/commands.sh"

# Initialize bs system
ensure_db
check_dependencies
migrate_db_format

# Get all stored commands as MCP tools
bs_get_stored_commands_as_tools() {
    local databases
    databases=($(find_all_databases))
    local all_commands="{}"

    # Merge all databases
    for db_file in "${databases[@]}"; do
        if [[ -f "$db_file" ]]; then
            local tmp
            tmp=$(mktemp) || continue
            jq -s '.[0] * .[1]' <(echo "$all_commands") "$db_file" > "$tmp" 2>/dev/null
            all_commands=$(cat "$tmp" 2>/dev/null || echo "{}")
            rm -f "$tmp"
        fi
    done

    # Convert commands to MCP tool format
    echo "$all_commands" | jq -r '
        to_entries | map({
            name: ("bs_" + .key),
            description: ("Execute stored command: " + .key + " - " + .value.command + (if (.value.notes // "") != "" then " (" + .value.notes + ")" else "" end)),
            inputSchema: {
                type: "object",
                properties: {
                    args: {
                        type: "string",
                        description: "Additional arguments to append to the command",
                        default: ""
                    }
                },
                required: []
            }
        }) | sort_by(.name)'
}

# Generate management tools (add/rm)
bs_get_management_tools() {
    cat <<'EOF'
[
    {
        "name": "bs_add",
        "description": "Add a new command to bs command manager",
        "inputSchema": {
            "type": "object",
            "properties": {
                "name": {
                    "type": "string",
                    "description": "Name for the command"
                },
                "command": {
                    "type": "string",
                    "description": "The command to store"
                },
                "notes": {
                    "type": "string",
                    "description": "Optional notes for the command",
                    "default": ""
                },
                "directory": {
                    "type": "string",
                    "description": "Optional directory to run command in",
                    "default": ""
                },
                "cd_current": {
                    "type": "boolean",
                    "description": "Whether to always run in current directory",
                    "default": false
                }
            },
            "required": ["name", "command"]
        }
    },
    {
        "name": "bs_rm",
        "description": "Remove commands from bs command manager",
        "inputSchema": {
            "type": "object",
            "properties": {
                "names": {
                    "type": "array",
                    "items": {
                        "type": "string"
                    },
                    "description": "Array of command names to remove"
                }
            },
            "required": ["names"]
        }
    }
]
EOF
}

# MCP application handlers (override the default protocol handlers)
mcp_app_handle_tools_list() {
    local params="$1"
    local id="$2"

    mcp_log_debug "Listing available BS tools"

    # Get stored commands as tools
    local stored_tools
    stored_tools=$(bs_get_stored_commands_as_tools)

    # Get management tools
    local mgmt_tools
    mgmt_tools=$(bs_get_management_tools)

    # Combine all tools
    local all_tools
    all_tools=$(jq -s '.[0] + .[1]' <(echo "$stored_tools") <(echo "$mgmt_tools"))

    local result=$(jq -nc --argjson tools "$all_tools" '{tools: $tools}')
    mcp_send_success_response "$result" "$id"
}

mcp_app_handle_tools_call() {
    local params="$1"
    local id="$2"

    local tool_name=$(echo "$params" | jq -r '.name')
    local arguments=$(echo "$params" | jq -c '.arguments // {}')

    mcp_log_debug "Executing BS tool: $tool_name with args: $arguments"

    case "$tool_name" in
        "bs_add")
            bs_handle_add "$arguments" "$id"
            ;;
        "bs_rm")
            bs_handle_rm "$arguments" "$id"
            ;;
        bs_*)
            # Extract command name (remove bs_ prefix)
            local cmd_name="${tool_name#bs_}"
            bs_handle_stored_command "$cmd_name" "$arguments" "$id"
            ;;
        *)
            mcp_send_error_response -32602 "Unknown tool: $tool_name" "$id"
            ;;
    esac
}

# Handle bs add command
bs_handle_add() {
    local arguments="$1"
    local id="$2"

    local name=$(echo "$arguments" | jq -r '.name')
    local command=$(echo "$arguments" | jq -r '.command')
    local notes=$(echo "$arguments" | jq -r '.notes // ""')
    local directory=$(echo "$arguments" | jq -r '.directory // ""')
    local cd_current=$(echo "$arguments" | jq -r '.cd_current // false')

    # Validate required fields
    if [[ -z "$name" || -z "$command" ]]; then
        mcp_send_error_response -32602 "Missing required fields: name and command" "$id"
        return
    fi

    # Check for reserved commands
    if is_reserved_command "$name"; then
        local error_data=$(jq -nc --arg cmd "$name" '{command: $cmd, reason: "reserved"}')
        mcp_send_error_response -32602 "Command name '$name' is reserved for future use" "$id" "$error_data"
        return
    fi

    # Build bs add arguments
    local add_args=("$name" "$command")

    if [[ -n "$notes" ]]; then
        add_args+=("--notes" "$notes")
    fi

    if [[ -n "$directory" ]]; then
        add_args+=("--dir" "$directory")
    elif [[ "$cd_current" == "true" ]]; then
        add_args+=("--cd")
    fi

    # Execute add command (capture output)
    local output
    if output=$(add_command "${add_args[@]}" 2>&1); then
        local content="[{\"type\": \"text\", \"text\": \"Successfully added command '$name': $command\"}]"
        local result=$(jq -nc --argjson content "$content" '{content: $content}')
        mcp_send_success_response "$result" "$id"
    else
        local error_data=$(jq -nc --arg output "$output" '{output: $output}')
        mcp_send_error_response -32603 "Failed to add command: $output" "$id" "$error_data"
    fi
}

# Handle bs rm command
bs_handle_rm() {
    local arguments="$1"
    local id="$2"

    local names_json=$(echo "$arguments" | jq -c '.names // []')
    local names_array
    # Bash 3.2 compatible array population
    names_array=($(echo "$names_json" | jq -r '.[]'))

    if [[ ${#names_array[@]} -eq 0 ]]; then
        mcp_send_error_response -32602 "No command names provided" "$id"
        return
    fi

    # Execute remove command
    local output
    if output=$(remove_command "${names_array[@]}" 2>&1); then
        local content="[{\"type\": \"text\", \"text\": \"Successfully removed commands: ${names_array[*]}\"}]"
        local result=$(jq -nc --argjson content "$content" '{content: $content}')
        mcp_send_success_response "$result" "$id"
    else
        local error_data=$(jq -nc --arg output "$output" '{output: $output}')
        mcp_send_error_response -32603 "Failed to remove commands: $output" "$id" "$error_data"
    fi
}

# Handle stored command execution
bs_handle_stored_command() {
    local cmd_name="$1"
    local arguments="$2"
    local id="$3"

    local args=$(echo "$arguments" | jq -r '.args // ""')

    # Check if command exists and get its details
    local databases
    databases=($(find_all_databases))
    local found_db=""
    local command_obj=""

    for db_file in "${databases[@]}"; do
        if [[ -f "$db_file" ]]; then
            local exists
            exists=$(jq -r --arg n "$cmd_name" 'has($n)' "$db_file" 2>/dev/null || echo "false")
            if [[ "$exists" == "true" ]]; then
                command_obj=$(jq -r --arg n "$cmd_name" '.[$n]' "$db_file" 2>/dev/null)
                found_db="$db_file"
                break
            fi
        fi
    done

    if [[ -z "$found_db" ]]; then
        mcp_send_error_response -32602 "Command '$cmd_name' not found" "$id"
        return
    fi

    # Extract command details
    local command=$(echo "$command_obj" | jq -r '.command // ""')
    local notes=$(echo "$command_obj" | jq -r '.notes // ""')
    local directory=$(echo "$command_obj" | jq -r '.directory // ""')

    if [[ -z "$command" ]]; then
        mcp_send_error_response -32603 "Invalid command object for '$cmd_name'" "$id"
        return
    fi

    # Build full command with args
    local full_command="$command"
    if [[ -n "$args" ]]; then
        full_command="$command $args"
    fi

    # Execute command
    local output exit_code
    if [[ -n "$directory" ]]; then
        # Run in specified directory
        output=$(cd "$directory" && eval "$full_command" 2>&1)
        exit_code=$?
    else
        # Run in current directory
        output=$(eval "$full_command" 2>&1)
        exit_code=$?
    fi

    # Format response
    local content
    if [[ $exit_code -eq 0 ]]; then
        content="[{\"type\": \"text\", \"text\": \"Command '$cmd_name' executed successfully:\n\n$output\"}]"
    else
        content="[{\"type\": \"text\", \"text\": \"Command '$cmd_name' failed with exit code $exit_code:\n\n$output\"}]"
    fi

    local result=$(jq -nc --argjson content "$content" '{content: $content}')
    mcp_send_success_response "$result" "$id"
}

# Initialize and start the BS MCP server
bs_mcp_start() {
    # Initialize MCP protocol
    mcp_init

    # Set server information
    mcp_set_server_info "bs-mcp-server" "1.0.0" "MCP server for bs command manager - exposes all stored commands as tools"

    # Start the server
    mcp_start_server
}
