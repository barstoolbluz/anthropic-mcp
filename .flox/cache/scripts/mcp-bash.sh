#!/usr/bin/env bash

# ------------------------------------------
# MCP Environment Bash Functions
# ------------------------------------------

# Global variables
MCP_CACHE_DIR="${FLOX_ENV_CACHE}/mcp"
MCP_SCRIPTS_DIR="${FLOX_ENV_CACHE}/scripts"
MCP_CONFIG_FILE="${MCP_CACHE_DIR}/config.sh"
MCP_SERVER_SCRIPT="${FLOX_ENV_PROJECT}/.mcp-server-command.sh"
MCP_CURRENT_SERVER_FILE="${MCP_CACHE_DIR}/current_server.txt"

# Ensure directories exist
mkdir -p "${MCP_CACHE_DIR}"

# ------------------------------------------
# Helper Functions
# ------------------------------------------

# Show informative banner when environment activates
info() {
  # Inspector message for dev mode
  local inspector_message=""
  
  if [[ "${MCP_ENV_MODE:-dev}" == "dev" ]]; then
    # Check if the service is running - use exact name and check for "Running" status
    if flox services status | grep -E "mcp-server\s+Running" >/dev/null 2>&1; then
      # Try to extract the inspector URL from logs with more flexibility in the pattern
      local inspector_url=$(flox services logs mcp-server 2>/dev/null | grep -o "MCP Inspector is up and running at http://[^[:space:]]*" | tail -n 1 | sed 's/.*running at //')
      
      if [[ -n "$inspector_url" ]]; then
        inspector_message="
🔍 MCP Inspector is up and running at ${inspector_url} 🚀"
      else
        # If we can't find it in logs, use the default
        inspector_message="
🔍 MCP Inspector is running at http://127.0.0.1:6274 🚀"
      fi
    else
      inspector_message="
🔍 MCP Inspector will be available at http://127.0.0.1:6274 when server is running 🚀"
    fi
  fi

  gum style \
    --border rounded \
    --border-foreground 240 \
    --padding "1 2" \
    --margin "1 0" \
    --width 96 \
    "$(gum style --foreground 141 --bold 'Model Context Protocol (MCP) Environment')

👉 MCP Commands:

$(gum style --foreground 212 'dev [server.py]') Start MCP server in development mode with inspector
$(gum style --foreground 212 'run [server.py]') Start MCP server in production/run mode
$(gum style --foreground 212 'test [server.py]') Test MCP server directly without starting service
$(gum style --foreground 212 'choose-mode') Select which mode to use interactively

👉 Claude Desktop Integration:

$(gum style --foreground 212 'install [server.py] ["Your Server Name"]') Register server with Claude Desktop

👉 Server Management:

$(gum style --foreground 212 'mcp dev [server.py]') Run the MCP Inspector for interactive testing
$(gum style --foreground 212 'init [server.py]') Create a new MCP server template

👉 Troubleshooting:

$(gum style --foreground 212 'flox services logs mcp-server') View MCP server logs
$(gum style --foreground 212 'flox services status mcp-server') Check MCP server status

👉 Environment Details:

Current Mode: $(gum style --foreground 212 "${MCP_ENV_MODE:-dev}")
Current Server File: $(gum style --foreground 212 "$(cat "${MCP_CURRENT_SERVER_FILE}" 2>/dev/null || echo "server.py")")${inspector_message}"

  echo ""
}

# Create a server template
create_server_template() {
  local server_file="${1:-server.py}"
  
  # Check if file already exists
  if [[ -f "$server_file" ]]; then
    echo "Error: File '$server_file' already exists."
    return 1
  fi
  
  # Create the server template file
  cat > "$server_file" << 'EOF'
# Model Context Protocol (MCP) Server
from mcp.server.fastmcp import FastMCP

# Create an MCP server
mcp = FastMCP("My MCP Server")


# Add a simple greeting resource
@mcp.resource("greeting://{name}")
def get_greeting(name: str) -> str:
    """Get a personalized greeting"""
    return f"Hello, {name}!"


# Add a simple calculator tool
@mcp.tool()
def calculate(operation: str, a: float, b: float) -> float:
    """
    Perform a calculation on two numbers.
    
    Parameters:
    - operation: The operation to perform (add, subtract, multiply, divide)
    - a: First number
    - b: Second number
    
    Returns:
    - The result of the calculation
    """
    if operation == "add":
        return a + b
    elif operation == "subtract":
        return a - b
    elif operation == "multiply":
        return a * b
    elif operation == "divide":
        if b == 0:
            raise ValueError("Cannot divide by zero")
        return a / b
    else:
        raise ValueError(f"Unknown operation: {operation}")


# Only needed if running the file directly
if __name__ == "__main__":
    mcp.run()
EOF

  echo "Created MCP server template at '$server_file'."
  
  # Store as current server file
  echo "$server_file" > "${MCP_CURRENT_SERVER_FILE}"
  
  return 0
}

# Function to prompt user for MCP mode selection
prompt_for_mcp_mode() {
  # Check if mode is hardcoded in environment variables
  if [[ -n "${MCP_ENV_MODE_HARDCODED}" ]]; then
    export MCP_ENV_MODE="${MCP_ENV_MODE_HARDCODED}"
    echo "Using hardcoded MCP mode: ${MCP_ENV_MODE}"
    return 0
  fi
  
  clear
  gum style \
    --border rounded \
    --border-foreground 240 \
    --padding "1 2" \
    --margin "1 0" \
    --width 70 \
    "$(gum style --foreground 27 --bold 'MCP Server Configuration')
    
$(gum style --foreground 240 'Which mode do you want to start the MCP server in?')"

  # Prompt for mode selection
  local selected_mode
  selected_mode=$(gum choose "dev" "run")
  
  if [[ -n "$selected_mode" ]]; then
    export MCP_ENV_MODE="$selected_mode"
    echo "MCP server will start in '${MCP_ENV_MODE}' mode."
    
    # Save the selected mode to config file
    mkdir -p "$(dirname "$MCP_CONFIG_FILE")"
    echo "export MCP_ENV_MODE=\"$selected_mode\"" > "$MCP_CONFIG_FILE"
  else
    # Default to dev mode if nothing selected
    export MCP_ENV_MODE="dev"
    echo "No mode selected. Defaulting to 'dev' mode."
    echo "export MCP_ENV_MODE=\"dev\"" > "$MCP_CONFIG_FILE"
  fi
}

# Test MCP server directly without starting service
test() {
  local server_file="${1:-$(cat "${MCP_CURRENT_SERVER_FILE}" 2>/dev/null || echo "server.py")}"
  
  # Update current server file
  echo "$server_file" > "${MCP_CURRENT_SERVER_FILE}"
  
  # Get directory and filename
  local server_dir=$(dirname "$server_file")
  local server_filename=$(basename "$server_file")
  
  echo "Testing MCP server directly..."
  echo "Server file: $server_file"
  echo "Mode: ${MCP_ENV_MODE:-dev}"
  
  # Save current directory
  local current_dir=$(pwd)
  
  # Save LD_AUDIT if it exists
  if [ -n "$LD_AUDIT" ]; then
    LD_AUDIT_BACKUP="$LD_AUDIT"
    export LD_AUDIT_BACKUP
    unset LD_AUDIT
  fi
  
  # Change to server directory and run for 5 seconds
  cd "$server_dir"
  echo "Working directory: $(pwd)"
  
  if [ "${MCP_ENV_MODE:-dev}" = "dev" ]; then
    echo "Testing development mode (Ctrl+C to stop)..."
    ${FLOX_ENV_CACHE}/venv/bin/mcp dev "$server_filename"
  else
    echo "Testing production mode (Ctrl+C to stop)..."
    ${FLOX_ENV_CACHE}/venv/bin/mcp run "$server_filename"
  fi
  
  # Return to original directory
  cd "$current_dir"
  
  # Restore LD_AUDIT if it existed
  if [ -n "$LD_AUDIT_BACKUP" ]; then
    export LD_AUDIT="$LD_AUDIT_BACKUP"
    unset LD_AUDIT_BACKUP
  fi
}

# Initialize the MCP environment
# This should be called from the hook.on-activate section
initialize_mcp_environment() {
  # Check if mode is hardcoded in environment
  if [[ -n "${MCP_ENV_MODE}" ]]; then
    export MCP_ENV_MODE_HARDCODED="${MCP_ENV_MODE}"
  fi
  
  # Load saved config if it exists
  if [[ -f "$MCP_CONFIG_FILE" ]]; then
    source "$MCP_CONFIG_FILE"
  else
    # Set default mode
    export MCP_ENV_MODE="dev"
  fi
  
  # Set default server file if not set
  if [[ ! -f "${MCP_CURRENT_SERVER_FILE}" ]]; then
    echo "server.py" > "${MCP_CURRENT_SERVER_FILE}"
  fi
  
  # We don't generate a script at activation time anymore
  # Script will be generated when functions like dev are used
}

# Generate the mcp-server executable script
generate_mcp_server_function() {
  local server_file="${1:-$(cat "${MCP_CURRENT_SERVER_FILE}" 2>/dev/null || echo "server.py")}"
  
  # Store as current server file
  echo "$server_file" > "${MCP_CURRENT_SERVER_FILE}"
  
  # Get absolute path of the server file
  local abs_server_file
  if [[ "$server_file" == /* ]]; then
    abs_server_file="$server_file"
  else
    abs_server_file="$(pwd)/$server_file"
  fi
  
  # Create executable script content for manual service starts
  local script_content
  script_content=$(cat << EOF
#!/usr/bin/env bash

# This script is for manually running the MCP server
# It is called when using 'flox services start mcp-server' outside of activation

echo "Starting MCP server..."
echo "Current directory: \$(pwd)"
echo "Running as user: \$(whoami)"

# Determine server file to use
server_file="\$(cat "${MCP_CURRENT_SERVER_FILE}" 2>/dev/null || echo "server.py")"
echo "Using server file: \$server_file"

# Save LD_AUDIT if it exists
if [ -n "\$LD_AUDIT" ]; then
  LD_AUDIT_BACKUP="\$LD_AUDIT"
  export LD_AUDIT_BACKUP
fi

# Unset LD_AUDIT to prevent jemalloc issues
unset LD_AUDIT

# Run MCP server in the appropriate mode
if [ "${MCP_ENV_MODE:-dev}" = "dev" ]; then
  echo "Starting MCP server in development mode..."
  ${FLOX_ENV_CACHE}/venv/bin/mcp dev "\$server_file"
else
  echo "Starting MCP server in production mode..."
  ${FLOX_ENV_CACHE}/venv/bin/mcp run "\$server_file"
fi

# Restore LD_AUDIT if it existed
if [ -n "\$LD_AUDIT_BACKUP" ]; then
  export LD_AUDIT="\$LD_AUDIT_BACKUP"
  unset LD_AUDIT_BACKUP
fi
EOF
)

  # Save the script to the project directory to ensure it's accessible
  local script_path="$FLOX_ENV_PROJECT/.mcp-server-command.sh"
  echo "$script_content" > "$script_path"
  
  # Make the script executable
  chmod +x "$script_path"
  
  echo "Generated MCP server script at $script_path"
}

# ------------------------------------------
# MCP Server Functions
# ------------------------------------------

# Start MCP server in development mode
dev() {
  local server_file="${1:-$(cat "${MCP_CURRENT_SERVER_FILE}" 2>/dev/null || echo "server.py")}"
  
  # Update the environment mode
  export MCP_ENV_MODE="dev"
  echo "export MCP_ENV_MODE=\"dev\"" > "$MCP_CONFIG_FILE"
  
  # Store as current server file
  echo "$server_file" > "${MCP_CURRENT_SERVER_FILE}"
  
  # Generate the server function with the updated mode
  generate_mcp_server_function "$server_file"
  
  # Stop any running MCP server
  flox services stop mcp-server >/dev/null 2>&1 || true
  sleep 1
  
  # Start the service with the new server file
  echo "Starting MCP server in development mode with $server_file..."
  flox services start mcp-server
  
  # Show service status
  echo "Service status:"
  flox services status mcp-server
}

# Start MCP server in run mode
run() {
  local server_file="${1:-$(cat "${MCP_CURRENT_SERVER_FILE}" 2>/dev/null || echo "server.py")}"
  
  # Update the environment mode
  export MCP_ENV_MODE="run"
  echo "export MCP_ENV_MODE=\"run\"" > "$MCP_CONFIG_FILE"
  
  # Store as current server file
  echo "$server_file" > "${MCP_CURRENT_SERVER_FILE}"
  
  # Generate the server function with the updated mode
  generate_mcp_server_function "$server_file"
  
  # Stop any running MCP server
  flox services stop mcp-server >/dev/null 2>&1 || true
  sleep 1
  
  # Start the service with the new server file
  echo "Starting MCP server in production mode with $server_file..."
  flox services start mcp-server
  
  # Show service status
  echo "Service status:"
  flox services status mcp-server
}

# Function to create a new MCP server file
init() {
  local server_file="${1:-server.py}"
  create_server_template "$server_file"
}

# Interactive function to choose MCP mode
choose-mode() {
  # Prompt for mode
  prompt_for_mcp_mode
  
  # Ask if the user wants to start the server now
  if gum confirm "Do you want to start the MCP server now?"; then
    # Generate the server function with the updated mode
    generate_mcp_server_function "$(cat "${MCP_CURRENT_SERVER_FILE}" 2>/dev/null || echo "server.py")"
    
    # Stop any running service
    flox services stop mcp-server >/dev/null 2>&1 || true
    sleep 1
    
    # Start the service
    echo "Starting MCP server..."
    flox services start mcp-server
  fi
}

# Install MCP server in Claude Desktop
install() {
  local server_file="${1:-$(cat "${MCP_CURRENT_SERVER_FILE}" 2>/dev/null || echo "server.py")}"
  local server_name="${2:-"MCP Server"}"
  
  # Update current server file
  echo "$server_file" > "${MCP_CURRENT_SERVER_FILE}"
  
  # Check if the user has already been informed about Claude Desktop
  local claude_flag="${MCP_CACHE_DIR}/.claude_desktop_selection"
  
  # If user hasn't been informed yet, show the prompt
  if [ ! -f "$claude_flag" ]; then
    clear
    gum style \
      --border rounded \
      --border-foreground 240 \
      --padding "1 2" \
      --margin "1 0" \
      --width 70 \
      "$(gum style --foreground 27 --bold 'Claude Desktop Required')
      
$(gum style --foreground 240 'Claude Desktop must be installed to use this feature.')"

    local choice
    choice=$(gum choose "Download Now" "Run Anyway" "Quit")
    
    case "$choice" in
      "Download Now")
        # Open browser based on platform
        if [[ "$OSTYPE" == "darwin"* ]]; then
          open "https://claude.ai/download"
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
          if command -v xdg-open &> /dev/null; then
            xdg-open "https://claude.ai/download"
          else
            echo "Please visit: https://claude.ai/download"
          fi
        elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
          start "https://claude.ai/download"
        else
          echo "Please visit: https://claude.ai/download"
        fi
        echo "After installing Claude Desktop, run this command again."
        return 0
        ;;
      "Quit")
        echo "Installation cancelled."
        return 1
        ;;
      *)
        # Run anyway or no selection
        echo "Proceeding with installation..."
        ;;
    esac
    
    # Mark that we've informed the user
    touch "$claude_flag"
  fi
  
  echo "Installing MCP server in Claude Desktop..."
  echo "Server file: $server_file"
  echo "Server name: $server_name"
  
  # Save LD_AUDIT if it exists
  if [ -n "$LD_AUDIT" ]; then
    LD_AUDIT_BACKUP="$LD_AUDIT"
    export LD_AUDIT_BACKUP
    unset LD_AUDIT
  fi
  
  # Install the server in Claude Desktop
  ${FLOX_ENV_CACHE}/venv/bin/mcp install "$server_file" --name "$server_name"
  local install_status=$?
  
  # Restore LD_AUDIT if it existed
  if [ -n "$LD_AUDIT_BACKUP" ]; then
    export LD_AUDIT="$LD_AUDIT_BACKUP"
    unset LD_AUDIT_BACKUP
  fi
  
  if [ $install_status -eq 0 ]; then
    echo "✅ MCP server successfully installed in Claude Desktop."
    echo "You can now use it in Claude Desktop conversations."
  else
    echo "❌ Failed to install MCP server in Claude Desktop."
    echo "Make sure Claude Desktop is running and try again."
  fi
}

# Define mcp-server function
mcp-server() {
  # Only generate the script if it doesn't exist
  if [ ! -f "$MCP_SERVER_SCRIPT" ]; then
    generate_mcp_server_function "$(cat "${MCP_CURRENT_SERVER_FILE}" 2>/dev/null || echo "server.py")"
  fi
  
  # Run the script
  "$MCP_SERVER_SCRIPT"
}

# Initialize the MCP environment on script load - only set defaults, don't generate script
initialize_mcp_environment
