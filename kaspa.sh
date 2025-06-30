#!/bin/bash

# --- CONFIGURATION ---
# IMPORTANT: Replace these with your actual details!

# Miner download URL and expected filename
MINER_DOWNLOAD_URL="https://github.com/bzminer/bzminer/releases/download/v23.0.2/bzminer_v23.0.2_linux.tar.gz"
MINER_ARCHIVE_NAME="bzminer_v23.0.2_linux.tar.gz"
MINER_EXTRACTED_DIR="bzminer_v23.0.2_linux" # The directory created after extraction

# Directory where the miner will be installed
MINER_INSTALL_ROOT="$HOME/mining_tools" # You can change this to any preferred location
MINER_DIR="$MINER_INSTALL_ROOT/$MINER_EXTRACTED_DIR"
MINER_PATH="$MINER_DIR/bzminer" # Full path to the bzminer executable

WALLET_ADDRESS="kaspa:qz7kplynjjwcsc6cthg45ckg7rr0j5sdh02pclugye8s2lxvwjr87x26mytr7" # Your Kaspa wallet address (mainnet if mining for real)
POOL_URL="stratum+tcp://pool.woolypooly.com:3112" # Example pool. Choose a real Kaspa pool!
WORKER_NAME="myPCminer" # A name for your mining rig (optional, but good for tracking)

# --- END CONFIGURATION ---

# Function to download and extract the miner
download_miner() {
    echo "Checking for miner in $MINER_DIR..."
    if [ -f "$MINER_PATH" ]; then
        echo "Miner already exists at $MINER_PATH. Skipping download."
        return 0
    fi

    echo "Miner not found. Attempting to download and extract BzMiner..."
    mkdir -p "$MINER_INSTALL_ROOT"
    cd "$MINER_INSTALL_ROOT" || { echo "Error: Could not change to $MINER_INSTALL_ROOT"; exit 1; }

    echo "Downloading $MINER_ARCHIVE_NAME from $MINER_DOWNLOAD_URL..."
    wget -q --show-progress "$MINER_DOWNLOAD_URL" -O "$MINER_ARCHIVE_NAME"

    if [ $? -ne 0 ]; then
        echo "Error: Failed to download miner. Please check the URL or your internet connection."
        exit 1
    fi

    echo "Extracting $MINER_ARCHIVE_NAME..."
    tar -xzf "$MINER_ARCHIVE_NAME"

    if [ $? -ne 0 ]; then
        echo "Error: Failed to extract miner archive."
        exit 1
    fi

    echo "Cleaning up downloaded archive..."
    rm "$MINER_ARCHIVE_NAME"

    # Make the miner executable
    if [ -f "$MINER_PATH" ]; then
        chmod +x "$MINER_PATH"
        echo "Miner downloaded and set up successfully at $MINER_PATH."
    else
        echo "Error: Miner executable not found after extraction. Check the archive contents."
        exit 1
    fi
}

# Function to start the miner
start_miner() {
    # Ensure the miner is downloaded and set up before starting
    download_miner

    echo "Starting Kaspa miner..."
    echo "Miner path: $MINER_PATH"
    echo "Wallet: $WALLET_ADDRESS"
    echo "Pool: $POOL_URL"
    echo "Worker: $WORKER_NAME"
    echo "Press Ctrl+C at any time to stop the miner."
    echo "------------------------------------------------"

    # Navigate into the miner's directory to ensure it can find its configuration files
    # This is common practice for many miners
    (cd "$MINER_DIR" && "$MINER_PATH" -a kaspa -w "$WALLET_ADDRESS.$WORKER_NAME" -p "$POOL_URL" $@)
}

# Function to stop the miner process
stop_miner() {
    echo "Attempting to stop Kaspa miner..."
    # Find the process ID (PID) of the miner
    # We use 'pgrep -f' to search for the full command line, which is more reliable.
    # Adjust 'bzminer' if you're using a different miner executable name.
    # We search for the full path to avoid stopping other processes named 'bzminer'
    MINER_PID=$(pgrep -f "$MINER_PATH")

    if [ -n "$MINER_PID" ]; then
        echo "Miner process found with PID: $MINER_PID. Sending SIGTERM..."
        kill "$MINER_PID"
        sleep 2 # Give it a moment to shut down gracefully
        # Check if it's still running
        if kill -0 "$MINER_PID" 2>/dev/null; then
            echo "Miner did not stop gracefully. Sending SIGKILL..."
            kill -9 "$MINER_PID"
        fi
        echo "Miner process stopped."
    else
        echo "No Kaspa miner process found running."
    fi
}

# Main script logic
case "$1" in
    start)
        start_miner "${@:2}" # Pass all arguments after 'start' to the miner
        ;;
    stop)
        stop_miner
        ;;
    restart)
        stop_miner
        start_miner "${@:2}"
        ;;
    download)
        download_miner
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|download} [miner_options]"
        echo "  start: Starts the Kaspa miner. Downloads and sets up if not found."
        echo "         Optional: You can pass additional miner options after 'start'."
        echo "         Example: $0 start --gpu 0,1"
        echo "  stop: Stops any running Kaspa miner process."
        echo "  restart: Stops and then starts the Kaspa miner."
        echo "  download: Only downloads and sets up the miner without starting it."
        ;;
esac
