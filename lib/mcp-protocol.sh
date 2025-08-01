#!/usr/bin/env bash
# Generic MCP (Model Context Protocol) implementation
# Provides JSON-RPC 2.0 over stdio for MCP servers

# MCP Protocol state (compatible with bash 3.2+)
MCP_SERVER_INITIALIZED=false
MCP_PROTOCOL_VERSION="2025-03-26"
MCP_SERVER_NAME=""
MCP_SERVER_VERSION=""
MCP_SERVER_DESCRIPTION=""

# Logging functions (NEVER use stdout - breaks MCP protocol)
mcp_log_info() {
    echo "[MCP-INFO] $*" >&2
}

mcp_log_error() {
    echo "[MCP-ERROR] $*" >&2
}

mcp_log_debug() {
    echo "[MCP-DEBUG] $*" >&2
}

# JSON-RPC 2.0 response generators
mcp_send_success_response() {
    local result="$1"
    local id="$2"
    
    jq -nc \
        --argjson result "$result" \
        --arg id "$id" \
        '{
            jsonrpc: "2.0",
            result: $result,
            id: ($id | if . == "null" then null else (tonumber // .) end)
        }'
}

mcp_send_error_response() {
    local code="$1"
    local message="$2"
    local id="$3"
    local data="${4:-}"
    
    local error_obj
    if [[ -n "$data" ]]; then
        error_obj=$(jq -nc \
            --arg code "$code" \
            --arg message "$message" \
            --argjson data "$data" \
            '{code: ($code | tonumber), message: $message, data: $data}')
    else
        error_obj=$(jq -nc \
            --arg code "$code" \
            --arg message "$message" \
            '{code: ($code | tonumber), message: $message}')
    fi
    
    jq -nc \
        --argjson error "$error_obj" \
        --arg id "$id" \
        '{
            jsonrpc: "2.0",
            error: $error,
            id: ($id | if . == "null" then null else (tonumber // .) end)
        }'
}

# Parse and validate JSON-RPC request
mcp_parse_json_rpc() {
    local request="$1"
    local method params id jsonrpc
    
    # Validate JSON structure
    if ! echo "$request" | jq . >/dev/null 2>&1; then
        mcp_send_error_response -32700 "Parse error" null
        return 1
    fi
    
    # Extract components using jq
    jsonrpc=$(echo "$request" | jq -r '.jsonrpc // empty')
    method=$(echo "$request" | jq -r '.method // empty')
    params=$(echo "$request" | jq -c '.params // {}')
    id=$(echo "$request" | jq -r '.id // null')
    
    # Validate JSON-RPC version
    if [[ "$jsonrpc" != "2.0" ]]; then
        mcp_send_error_response -32600 "Invalid Request" "$id"
        return 1
    fi
    
    # Export for use in handlers
    export MCP_METHOD="$method"
    export MCP_PARAMS="$params"
    export MCP_ID="$id"
    
    return 0
}

# Set server info (call this before starting server)
mcp_set_server_info() {
    local name="$1"
    local version="$2"
    local description="$3"
    
    MCP_SERVER_NAME="$name"
    MCP_SERVER_VERSION="$version"
    MCP_SERVER_DESCRIPTION="$description"
}

# Default initialize handler (can be overridden)
mcp_handle_initialize() {
    local params="$1"
    local id="$2"
    
    mcp_log_info "Initializing MCP server: $MCP_SERVER_NAME"
    
    # Extract client info
    local client_version=$(echo "$params" | jq -r '.protocolVersion // "2025-03-26"')
    
    # Mark as initialized
    MCP_SERVER_INITIALIZED=true
    MCP_PROTOCOL_VERSION="$client_version"
    
    # Build initialization response
    local result=$(jq -nc \
        --arg version "$client_version" \
        --arg name "$MCP_SERVER_NAME" \
        --arg server_version "$MCP_SERVER_VERSION" \
        --arg description "$MCP_SERVER_DESCRIPTION" \
        '{
            protocolVersion: $version,
            capabilities: {
                tools: { listChanged: true }
            },
            serverInfo: {
                name: $name,
                version: $server_version,
                description: $description
            }
        }')
    
    mcp_send_success_response "$result" "$id"
}

# Default initialized handler (can be overridden)
mcp_handle_initialized() {
    mcp_log_info "Client initialization complete"
}

# Main request processing (requires implementation-specific handlers)
mcp_process_request() {
    local request="$1"
    local response
    
    # Parse and validate JSON-RPC structure
    if ! mcp_parse_json_rpc "$request"; then
        return 1  # Error response already sent
    fi
    
    # Route to appropriate handler
    case "$MCP_METHOD" in
        "initialize")
            if type mcp_app_handle_initialize >/dev/null 2>&1; then
                response=$(mcp_app_handle_initialize "$MCP_PARAMS" "$MCP_ID")
            else
                response=$(mcp_handle_initialize "$MCP_PARAMS" "$MCP_ID")
            fi
            ;;
        "initialized")
            if type mcp_app_handle_initialized >/dev/null 2>&1; then
                mcp_app_handle_initialized
            else
                mcp_handle_initialized
            fi
            return 0  # No response for notifications
            ;;
        "tools/list")
            if type mcp_app_handle_tools_list >/dev/null 2>&1; then
                response=$(mcp_app_handle_tools_list "$MCP_PARAMS" "$MCP_ID")
            else
                response=$(mcp_send_error_response -32601 "tools/list not implemented" "$MCP_ID")
            fi
            ;;
        "tools/call")
            if type mcp_app_handle_tools_call >/dev/null 2>&1; then
                response=$(mcp_app_handle_tools_call "$MCP_PARAMS" "$MCP_ID")
            else
                response=$(mcp_send_error_response -32601 "tools/call not implemented" "$MCP_ID")
            fi
            ;;
        *)
            response=$(mcp_send_error_response -32601 "Method not found: $MCP_METHOD" "$MCP_ID")
            ;;
    esac
    
    echo "$response"
}

# Main JSON-RPC server loop
mcp_start_server() {
    mcp_log_info "Starting MCP server: $MCP_SERVER_NAME"
    
    while IFS= read -r request; do
        if [[ -n "$request" ]]; then
            mcp_log_debug "Processing request: $request"
            mcp_process_request "$request"
        fi
    done
    
    mcp_log_info "MCP server shutting down: $MCP_SERVER_NAME"
}

# Error handling
mcp_handle_error() {
    local exit_code=$?
    local line_number=$1
    mcp_log_error "Error occurred at line $line_number: exit code $exit_code"
    
    # Send internal error if in RPC context
    if [[ -n "${MCP_ID:-}" ]]; then
        mcp_send_error_response -32603 "Internal error" "$MCP_ID"
    fi
    exit $exit_code
}

# Signal handlers for graceful shutdown
mcp_setup_signal_handlers() {
    trap 'mcp_log_info "Received SIGTERM, shutting down gracefully"; exit 0' TERM
    trap 'mcp_log_info "Received SIGINT, exiting"; exit 1' INT
    trap 'mcp_log_info "Pipe closed, exiting"; exit 0' PIPE
}

# Initialize MCP protocol (call this to set up error handling)
mcp_init() {
    trap 'mcp_handle_error $LINENO' ERR
    mcp_setup_signal_handlers
}
