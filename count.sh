#!/bin/bash

# Function to format time
format_time() {
    local total_seconds=$1
    local hours=$((total_seconds / 3600))
    local minutes=$(((total_seconds % 3600) / 60))
    local seconds=$((total_seconds % 60))

    local output=""
    if [ "$hours" -gt 0 ]; then
        output="${output}${hours}h "
    fi
    if [ "$minutes" -gt 0 ] || [ "$hours" -gt 0 ]; then
        output="${output}${minutes}min "
    fi
    output="${output}${seconds}s"
    echo "$output"
}

# Main countdown loop
counter=1
trap 'echo -e "\nTimer stopped."; exit 0' SIGINT

while true; do
    time_str=$(format_time "$counter")
    echo -ne "\r$time_str   "
    sleep 1
    ((counter++))
done
