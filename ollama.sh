#!/bin/bash

# --- Ollama Server Setup Script ---
# This script configures Ollama on your powerful Linux PC (server)
# to allow remote access from other machines on your network.
# It forces Ollama to listen on all interfaces (0.0.0.0), sets up 'ollama serve' via systemd,
# ensures it's running, waits, opens firewall, and downloads the model.

# Function to check for root privileges
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run with root privileges (e.g., using sudo)."
        echo "Usage: sudo ./setup_ollama_server.sh"
        exit 1
    fi
}

# --- Main Script Execution ---
echo "Starting Ollama Server Setup..."
check_root

# We will force Ollama to listen on all interfaces (0.0.0.0) for maximum accessibility.
# This assumes your powerful PC has a network interface accessible by your less powerful PC.
OLLAMA_SERVER_IP="0.0.0.0"
echo "Configuring Ollama server to listen on all available network interfaces (0.0.0.0)."
echo "You will need to use the actual IP address of this powerful PC on your network to connect from the client."
echo "You can find this PC's IP using 'ip a' or 'hostname -I' later."

# 1. Install Ollama
echo "1. Installing Ollama. This will set up the 'ollama serve' functionality as a systemd service..."
if ! curl -fsSL https://ollama.com/install.sh | sh; then
    echo "Error: Ollama installation failed. Please check your internet connection or try again."
    exit 1
fi
echo "Ollama installed successfully."

# 2. Configure OLLAMA_HOST for systemd service
# This ensures the 'ollama serve' process (run by systemd) starts with the correct host.
echo "2. Configuring Ollama service to listen on $OLLAMA_SERVER_IP..."
OLLAMA_OVERRIDE_DIR="/etc/systemd/system/ollama.service.d"
OLLAMA_OVERRIDE_FILE="$OLLAMA_OVERRIDE_DIR/override.conf"

mkdir -p "$OLLAMA_OVERRIDE_DIR"

# Ensure the file is created/overwritten correctly
cat << EOF > "$OLLAMA_OVERRIDE_FILE"
[Service]
Environment="OLLAMA_HOST=$OLLAMA_SERVER_IP"
EOF

# Reload systemd daemon to pick up changes
echo "Reloading systemd daemon..."
systemctl daemon-reload

# 3. Start/Restart Ollama service to run 'ollama serve' in background
echo "3. Starting/Restarting Ollama service to ensure 'ollama serve' is running in the background..."
if ! systemctl restart ollama; then
    echo "Error: Failed to start/restart Ollama service. Please check 'sudo systemctl status ollama'."
    exit 1
fi
echo "Ollama service started/restarted and serving on $OLLAMA_SERVER_IP:11434."

# 4. Wait 10 seconds for the Ollama server to fully initialize
echo "4. Waiting 10 seconds for the Ollama server to fully initialize..."
sleep 10
echo "Wait complete. Proceeding with model download."

# 5. Configure Firewall
echo "5. Configuring Firewall (checking for ufw or firewalld)..."
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

# 6. Download the specified AI model (deepseek-coder:33b-instruct)
echo "6. Downloading the 'deepseek-coder:33b-instruct' AI model. This may take some time depending on your internet speed..."
# Using 'ollama pull' for non-interactive download
if ! ollama pull deepseek-coder:33b-instruct; then
    echo "Warning: Failed to download 'deepseek-coder:33b-instruct' model. You can try 'ollama run deepseek-coder:33b-instruct' later."
fi
echo "Model download finished (or skipped if already present)."

echo ""
echo "--- Ollama Server Setup Complete! ---"
echo "Your Ollama server is now configured to listen on all interfaces (0.0.0.0) on port 11434."
echo "Please find the actual IP address of this powerful PC that is reachable from your client PC."
echo "You can try running 'ip a' or 'hostname -I' on this powerful PC."
echo ""
echo "Once you have that IP, use it in the client script."
echo "For example, if the IP is 192.168.1.100, then on your client PC, set OLLAMA_HOST to http://192.168.1.100:11434."
echo ""
