#!/bin/bash

# Configuration
PROJECT_DIR="$(pwd)" # Or specify your project directory: /path/to/your/project
LOG_DIR="$PROJECT_DIR/build_logs"
LOG_FILE="$LOG_DIR/build_$(date +%Y%m%d_%H%M%S).log"
MAX_RETRIES=5 # Maximum number of times to retry the build
RETRY_DELAY=10 # Seconds to wait before retrying

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR" || { echo "Failed to create log directory. Exiting."; exit 1; }

echo "Starting persistent build process..."
echo "Project Directory: $PROJECT_DIR"
echo "Log File: $LOG_FILE"
echo "Max Retries: $MAX_RETRIES"
echo "Retry Delay: $RETRY_DELAY seconds"
echo "----------------------------------------------------"

# Function to perform the build
perform_build() {
    local attempt=$1
    echo "Attempt #$attempt: Starting build (PID: $$) at $(date)" | tee -a "$LOG_FILE"
    echo "--- CMake Output ---" | tee -a "$LOG_FILE"
    (
        cd "$PROJECT_DIR" || { echo "ERROR: Could not change to project directory." | tee -a "$LOG_FILE"; return 1; }
        nice -n 19 cmake .. 2>&1
    ) | tee -a "$LOG_FILE"

    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        echo "CMake failed on attempt #$attempt." | tee -a "$LOG_FILE"
        return 1
    fi

    echo "--- Make Output ---" | tee -a "$LOG_FILE"
    (
        cd "$PROJECT_DIR" || { echo "ERROR: Could not change to project directory." | tee -a "$LOG_FILE"; return 1; }
        nice -n 19 make -j1 2>&1
    ) | tee -a "$LOG_FILE"

    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        echo "Make failed on attempt #$attempt." | tee -a "$LOG_FILE"
        return 1
    fi

    echo "Build completed successfully on attempt #$attempt." | tee -a "$LOG_FILE"
    return 0
}

# Main loop to keep the build active
retry_count=0
while [ $retry_count -lt $MAX_RETRIES ]; do
    perform_build $((retry_count + 1))
    BUILD_STATUS=$?

    if [ $BUILD_STATUS -eq 0 ]; then
        echo "Persistent build finished successfully after $((retry_count + 1)) attempts." | tee -a "$LOG_FILE"
        break # Exit loop if build is successful
    else
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $MAX_RETRIES ]; then
            echo "Build failed. Retrying in $RETRY_DELAY seconds (Attempt $retry_count/$MAX_RETRIES)." | tee -a "$LOG_FILE"
            sleep "$RETRY_DELAY"
        else
            echo "Build failed after $MAX_RETRIES attempts. Giving up." | tee -a "$LOG_FILE"
        fi
    fi
done

echo "Script finished." | tee -a "$LOG_FILE"
