#!/bin/bash

# Configuration
PROJECT_DIR="$(pwd)" # Or specify your project directory: /path/to/your/project
HEARTBEAT_INTERVAL=600 # Seconds (10 minutes * 60 seconds/minute)

echo "Starting build process..."
echo "Project Directory: $PROJECT_DIR"
echo "Heartbeat every: $((HEARTBEAT_INTERVAL / 60)) minutes"
echo "----------------------------------------------------"

# Function to perform the build (runs only once)
perform_build_once() {
    echo "Starting initial build (PID: $$) at $(date)"

    echo "--- CMake Output ---"
    (
        cd "$PROJECT_DIR" || { echo "ERROR: Could not change to project directory. Exiting."; return 1; }
        nice -n 19 cmake .. 2>&1
    )

    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        echo "CMake failed. Build aborted."
        return 1
    fi

    echo "--- Make Output ---"
    (
        cd "$PROJECT_DIR" || { echo "ERROR: Could not change to project directory. Exiting."; return 1; }
        nice -n 19 make -j1 2>&1
    )

    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        echo "Make failed. Build aborted."
        return 1
    }

    echo "Initial build commands sent. Monitoring progress..."
    return 0
}

# --- Main execution ---

# Run the build commands in a subshell in the background
# We pipe its output directly to the nohup.out (or terminal if not using nohup)
( perform_build_once ) &
BUILD_PID=$! # Get the PID of the background build subshell

# Check if the build process actually started
if ! kill -0 "$BUILD_PID" 2>/dev/null; then
    echo "Failed to start the build process. Exiting."
    exit 1
fi

echo "Build process running in background with PID: $BUILD_PID"

# Loop to send heartbeat while the build process is active
while kill -0 "$BUILD_PID" 2>/dev/null; do
    echo "Active - $(date)"
    sleep "$HEARTBEAT_INTERVAL"
done

# Wait for the build process to fully finish (optional, but good practice)
wait "$BUILD_PID"
BUILD_STATUS=$?

if [ $BUILD_STATUS -eq 0 ]; then
    echo "Build process completed successfully."
else
    echo "Build process exited with an error status: $BUILD_STATUS"
fi

echo "Script finished."
