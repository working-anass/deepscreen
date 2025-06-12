#!/bin/bash

# --- Ollama Server Setup Script ---
# This script configures Ollama on your powerful Linux PC (server)
# to allow remote access from other machines on your network.
# It sets up the 'ollama serve' functionality via systemd and downloads
# the 'deepseek-coder:33b-instruct' model.

# Function to check for root privileges
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run with root privileges (e.g., using sudo)."
        echo "Usage: sudo ./setup_ollama_server.sh"
        exit 1
    fi
}

# Function to get and validate IP address
get_server_ip() {
    local ip_address
    while true; do
        read -p "Enter the IP address your Ollama server should listen on (e.g., 192.168.1.100 or 0.0.0.0 for all interfaces): " ip_address
        # Basic validation: check if it's not empty and looks like an IP or 0.0.0.0
        if [[ -z "$ip_address" ]]; then
            echo "IP address cannot be empty. Please try again."
        elif [[ "$ip_address" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ || "$ip_address" == "0.0.0.0" ]]; then
            echo "Using server IP: $ip_address"
            OLLAMA_SERVER_IP="$ip_address"
            break
        else
            echo "Invalid IP address format. Please enter a valid IPv4 address or 0.0.0.0."
        fi
    done
}

# --- Main Script Execution ---
echo "Starting Ollama Server Setup..."
check_root
get_server_ip

# 1. Install Ollama
echo "1. Installing Ollama. This will set up the 'ollama serve' as a systemd service..."
if ! curl -fsSL https://ollama.com/install.sh | sh; then
    echo "Error: Ollama installation failed. Please check your internet connection or try again."
    exit 1
fi
echo "Ollama installed successfully."

# 2. Configure OLLAMA_HOST for systemd service
# This is the most robust way to set environment variables for systemd services,
# ensuring the 'ollama serve' process starts with the correct host.
echo "2. Configuring Ollama service to listen on $OLLAMA_SERVER_IP..."
OLLAMA_OVERRIDE_DIR="/etc/systemd/system/ollama.service.d"
OLLAMA_OVERRIDE_FILE="$OLLAMA_OVERRIDE_DIR/override.conf"

mkdir -p "$OLLAMA_OVERRIDE_DIR"

cat << EOF > "$OLLAMA_OVERRIDE_FILE"
[Service]
Environment="OLLAMA_HOST=$OLLAMA_SERVER_IP"
EOF

# Reload systemd daemon to pick up changes
echo "Reloading systemd daemon..."
systemctl daemon-reload

# 3. Restart Ollama service
echo "3. Restarting Ollama service. This implicitly runs 'ollama serve' with the new configuration..."
if ! systemctl restart ollama; then
    echo "Error: Failed to restart Ollama service. Please check 'sudo systemctl status ollama'."
    exit 1
fi
echo "Ollama service restarted and serving on $OLLAMA_SERVER_IP:11434."

# 4. Configure Firewall
echo "4. Configuring Firewall (checking for ufw or firewalld)..."
if command -v ufw &> /dev/null; then
    echo "  - UFW detected. Allowing port 11434/tcp."
    ufw allow 11434/tcp
    ufw reload
    echo "  - UFW rules updated."
elif command -v firewall-cmd &> /dev/null; then
    echo "  - Firewalld detected. Allowing port 11434/tcp."
    firewall-cmd --permanent --add-port=11434/tcp
    firewall-cmd --reload
    echo "  - Firewalld rules updated."
else
    echo "  - No common firewall (ufw or firewalld) detected. Please configure your firewall manually if you have one."
    echo "    Ensure port 11434/tcp is open for incoming connections."
fi

# 5. Download the specified AI model (deepseek-coder:33b-instruct)
echo "5. Downloading the 'deepseek-coder:33b-instruct' AI model. This may take some time depending on your internet speed..."
# Using 'ollama pull' for non-interactive download
if ! ollama pull deepseek-coder:33b-instruct; then
    echo "Warning: Failed to download 'deepseek-coder:33b-instruct' model. You can try 'ollama run deepseek-coder:33b-instruct' later."
fi
echo "Model download finished (or skipped)."

echo ""
echo "--- Ollama Server Setup Complete! ---"
echo "Your Ollama server is now configured to listen on $OLLAMA_SERVER_IP:11434 and serving the model."
echo "You can now proceed to set up your client PC using the client script."
echo "Remember to replace '<powerful_pc_ip_address>' with '$OLLAMA_SERVER_IP' in the client script."
echo ""
