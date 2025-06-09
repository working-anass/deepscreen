#!/bin/bash

# --- Configuration ---
IMGUR_API_KEY="f8f01de269e26920152bdea96ed4fdd4" # Consider using environment variables for sensitive keys
NINJA_API_KEY="YiWejAGWZ2h13WXnrN/JFw==LoeaMiLtXI0cRC16" # Consider using environment variables for sensitive keys
SCREENSHOT_PATH="/tmp/getscreen_screenshot.png" # More descriptive name
CROPPED_PATH="/tmp/getscreen_cropped.png"       # More descriptive name
XVFB_DISPLAY=":99"
RESOLUTION="1280x1024x24"
LOG_FILE="/tmp/getscreen_script.log" # Dedicated log file

# --- Progress Tracking ---
# Approximate number of major steps in the script for progress calculation
TOTAL_STEPS=30 # Increased slightly for more granular steps or longer waits
CURRENT_STEP=0

# Function to update and display progress
update_progress() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    PERCENTAGE=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    echo -ne "\r[+] Progress: $PERCENTAGE% - $1" >&2
    echo "[*] $1" # This will go to the log file due to 'exec > "$LOG_FILE"'
}

# Redirect standard output to a log file. Standard error will still go to the terminal.
exec > "$LOG_FILE"

# Log initial message to the file (stdout is now redirected)
echo "[*] Starting GetScreen.me Connection Script (logging to $LOG_FILE)..."
echo "--- Configuration ---"
echo "IMGUR_API_KEY: (hidden)"
echo "NINJA_API_KEY: (hidden)"
echo "SCREENSHOT_PATH: $SCREENSHOT_PATH"
echo "CROPPED_PATH: $CROPPED_PATH"
echo "XVFB_DISPLAY: $XVFB_DISPLAY"
echo "RESOLUTION: $RESOLUTION"
echo "---------------------"

# --- Helper Functions ---

# Function to check if a command exists
command_exists () {
    type "$1" &> /dev/null
}

# Function to safely install packages
install_package() {
    PACKAGE=$1
    update_progress "Installing $PACKAGE..."
    if ! command_exists "$PACKAGE"; then
        sudo apt install -y "$PACKAGE"
        if [ $? -ne 0 ]; then
            echo "[!] Failed to install $PACKAGE. Exiting."
            exit 1
        fi
    else
        echo "[*] $PACKAGE is already installed."
    fi
}

# --- Initial Setup ---
update_progress "Initial setup and apt update..."
sudo apt update || { echo "[!] apt update failed. Exiting."; exit 1; }

# Add apt-utils to avoid "debconf: delaying package configuration" warnings
install_package "apt-utils"

# --- Install Dependencies ---
DEPENDENCIES="wget curl x11-utils imagemagick openbox xvfb jq scrot feh tint2 xfce4-terminal pcmanfm wmctrl"
for DEP in $DEPENDENCIES; do
    install_package "$DEP"
done

# --- Install Firefox ---
update_progress "Installing Firefox ESR..."
if ! command_exists "firefox-esr"; then
    sudo add-apt-repository ppa:mozillateam/ppa -y >/dev/null 2>&1
    sudo apt update || { echo "[!] apt update after PPA failed. Exiting."; exit 1; }
    sudo apt install --assume-yes firefox-esr dbus-x11 dbus
    if [ $? -ne 0 ]; then
        echo "[!] Failed to install Firefox ESR. Exiting."
        exit 1
    fi
else
    echo "[*] Firefox ESR is already installed."
fi

# --- Install getscreen.me and its dependencies ---
update_progress "Downloading getscreen.me package..."
GETSCREEN_DEB="/tmp/getscreen.me.deb"
if [ ! -f "/opt/getscreen.me/getscreen.me" ]; then
    wget https://getscreen.me/download/getscreen.me.deb -O "$GETSCREEN_DEB" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "[!] Failed to download getscreen.me.deb. Exiting."
        exit 1
    fi

    update_progress "Attempting getscreen.me installation (may report errors initially)..."
    sudo dpkg -i "$GETSCREEN_DEB" || true
    
    update_progress "Fixing broken dependencies for getscreen.me..."
    sudo apt --assume-yes --fix-broken install
    if [ $? -ne 0 ]; then
        echo "[!] Failed to fix broken dependencies. Exiting."
        exit 1
    fi

    update_progress "Finalizing getscreen.me installation..."
    sudo dpkg -i "$GETSCREEN_DEB"
    if [ $? -ne 0 ]; then
        echo "[!] getscreen.me installation failed even after fixing dependencies. Exiting."
        exit 1
    fi

    rm -f "$GETSCREEN_DEB"
else
    echo "[*] getscreen.me is already installed."
fi

# --- Start Virtual Display ---
update_progress "Starting Xvfb virtual display..."
if ! pgrep -f "Xvfb $XVFB_DISPLAY"; then
    Xvfb "$XVFB_DISPLAY" -screen 0 "$RESOLUTION" &
    XVFB_PID=$!
    export DISPLAY="$XVFB_DISPLAY"
    sleep 5 # Initial wait for Xvfb
    if ! kill -0 "$XVFB_PID" 2>/dev/null; then
        echo "[!] Xvfb failed to start. Exiting."
        exit 1
    fi
else
    echo "[*] Xvfb is already running on $XVFB_DISPLAY."
    export DISPLAY="$XVFB_DISPLAY"
fi

# --- Start Openbox ---
update_progress "Starting Openbox window manager..."
if ! pgrep -f "openbox-session"; then
    openbox-session &
    sleep 5 # Wait for Openbox to initialize
else
    echo "[*] Openbox is already running."
fi

# --- Set wallpaper ---
update_progress "Setting desktop wallpaper..."
mkdir -p /root/.config
if [ -f "/usr/share/pixmaps/debian-logo.png" ]; then
    feh --bg-scale /usr/share/pixmaps/debian-logo.png
else
    echo "[!] Debian logo not found, setting black background."
    feh --bg-color black
fi

# --- Launch desktop components ---
update_progress "Launching desktop environment components (tint2, terminal, pcmanfm)..."
if ! pgrep -f "tint2"; then
    tint2 &
    sleep 2
fi

if ! pgrep -f "xfce4-terminal"; then
    xfce4-terminal &
    sleep 2
fi

if ! pgrep -f "pcmanfm"; then
    pcmanfm --no-desktop &
    sleep 2
fi

# --- Launch getscreen.me ---
update_progress "Launching getscreen.me application (waiting for GUI)..."
GETSCREEN_APP_PATH="/opt/getscreen.me/getscreen.me"
if [ -f "$GETSCREEN_APP_PATH" ]; then
    if ! pgrep -f "getscreen.me"; then
        "$GETSCREEN_APP_PATH" &
        # SIGNIFICANTLY INCREASED WAIT TIME FOR GETSCREEN.ME GUI TO RENDER
        echo "[*] getscreen.me launched. Waiting 30 seconds for its window to appear and stabilize..."
        sleep 30
    else
        echo "[*] getscreen.me is already running."
    fi
else
    echo "[!] getscreen.me executable not found at $GETSCREEN_APP_PATH. Exiting."
    exit 1
fi

# --- Find and focus getscreen.me window ---
update_progress "Locating and focusing getscreen.me window (retrying for longer)..."
WINDOW_ID=""
MAX_ATTEMPTS=20 # Increased from 10 to 20 attempts
SLEEP_BETWEEN_ATTEMPTS=3 # Reduced sleep slightly to try more often in the overall increased time

for i in $(seq 1 $MAX_ATTEMPTS); do
    # Try wmctrl first
    WINDOW_ID=$(wmctrl -l | grep -i "getscreen" | awk '{print $1}' | head -1)
    if [[ -n "$WINDOW_ID" ]]; then
        echo "[*] Found getscreen.me window via wmctrl: $WINDOW_ID (attempt $i)"
        break
    fi
    # Fallback to xwininfo
    WINDOW_ID=$(xwininfo -root -tree | grep -i "getscreen" | grep -o "0x[0-9a-fA-F]*" | head -1)
    if [[ -n "$WINDOW_ID" ]]; then
        echo "[*] Found getscreen.me window via xwininfo: $WINDOW_ID (attempt $i)"
        break
    fi
    echo "[*] getscreen.me window not found on attempt $i, retrying in ${SLEEP_BETWEEN_ATTEMPTS} seconds..."
    sleep $SLEEP_BETWEEN_ATTEMPTS
done

if [[ -n "$WINDOW_ID" ]]; then
    echo "[*] Activating and raising getscreen.me window: $WINDOW_ID"
    wmctrl -i -a "$WINDOW_ID"
    sleep 2 # Give it a moment to activate

    read -r X_POS Y_POS WIDTH HEIGHT <<< "$(xwininfo -id "$WINDOW_ID" | \
        awk '/Absolute upper-left X:/ {print $4} /Absolute upper-left Y:/ {print $4} /Width:/ {print $2} /Height:/ {print $2}')"

    if [[ -z "$X_POS" || -z "$Y_POS" || -z "$WIDTH" || "$HEIGHT" -le 0 ]]; then
        echo "[!] Could not determine getscreen.me window geometry or invalid dimensions. Taking full screenshot."
        scrot "$SCREENSHOT_PATH"
    else
        echo "[*] Window position: ${X_POS}x${Y_POS}, Size: ${WIDTH}x${HEIGHT}"
        echo "[*] Capturing screenshot of specific getscreen.me window area..."
        scrot -a "${X_POS},${Y_POS},${WIDTH},${HEIGHT}" "$SCREENSHOT_PATH"
    fi
else
    echo "[!] Could not find getscreen.me window after all attempts. Taking full screenshot as fallback."
    scrot "$SCREENSHOT_PATH"
fi

if [[ ! -f "$SCREENSHOT_PATH" ]]; then
    echo "[!] Screenshot capture failed for $SCREENSHOT_PATH. Exiting."
    exit 1
fi

# --- Auto-detect and crop the connection info area ---
update_progress "Processing screenshot for connection info via OCR..."
TEMP_OCR_FULL="/tmp/temp_ocr_full.json"
TEMP_OCR_CROP="/tmp/temp_ocr_crop.json"

echo "[*] Performing OCR on the full screenshot to detect initial text."
curl -s -X POST "https://api.api-ninjas.com/v1/imagetotext" \
    -H "X-Api-Key: $NINJA_API_KEY" \
    -F "image=@$SCREENSHOT_PATH" > "$TEMP_OCR_FULL"

FULL_EXTRACTED_TEXT=$(jq -r '.[] | select(.text | test("getscreen\\.me|[0-9]{3}\\.[0-9]{3}\\.[0-9]{2}|[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}|[A-Z0-9]{6,}")) | .text' "$TEMP_OCR_FULL")

if [ -n "$FULL_EXTRACTED_TEXT" ]; then
    echo "[*] Connection info found in full screenshot. Using full screenshot for final OCR."
    cp "$SCREENSHOT_PATH" "$CROPPED_PATH"
else
    echo "[*] Connection info not immediately found. Trying to locate connection info area by cropping..."

    CROP_AREAS=(
        "500x300+0+0"
        "500x300+300+0"
        "500x300+0+200"
        "500x300+300+200"
        "600x200+100+100"
        "300x500+150+50"
    )

    FOUND_INFO_IN_CROP=false
    for CROP in "${CROP_AREAS[@]}"; do
        echo "[*] Trying crop area: $CROP"
        convert "$SCREENSHOT_PATH" -crop "$CROP" "/tmp/test_crop.png"

        if [ -f "/tmp/test_crop.png" ]; then
            TEST_OCR_RESPONSE=$(curl -s -X POST "https://api.api-ninjas.com/v1/imagetotext" \
                -H "X-Api-Key: $NINJA_API_KEY" \
                -F "image=@/tmp/test_crop.png")

            TEST_TEXT=$(echo "$TEST_OCR_RESPONSE" | jq -r '.[] | select(.text | test("getscreen\\.me|[0-9]{3}\\.[0-9]{3}\\.[0-9]{2}|[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}|[A-Z0-9]{6,}")) | .text')

            if [ -n "$TEST_TEXT" ]; then
                echo "[*] Found connection info in crop area: $CROP. Saving as cropped image."
                cp "/tmp/test_crop.png" "$CROPPED_PATH"
                FOUND_INFO_IN_CROP=true
                break
            fi
        else
            echo "[!] Failed to create test crop for area: $CROP"
        fi
    done

    if [ "$FOUND_INFO_IN_CROP" = false ]; then
        echo "[*] No specific connection info found in cropped areas. Using default full screenshot for OCR."
        cp "$SCREENSHOT_PATH" "$CROPPED_PATH"
    fi
fi

if [[ ! -f "$CROPPED_PATH" ]]; then
    echo "[!] Image processing or cropping failed. $CROPPED_PATH does not exist. Exiting."
    exit 1
fi

# --- Upload Screenshot (optional) ---
update_progress "Uploading screenshot to ImgBB..."
UPLOAD_URL="https://api.imgbb.com/1/upload?key=$IMGUR_API_KEY"
RESPONSE=$(curl -s -X POST -F "image=@$CROPPED_PATH" "$UPLOAD_URL")
IMAGE_URL=$(echo "$RESPONSE" | jq -r '.data.url')
UPLOAD_ERROR=$(echo "$RESPONSE" | jq -r '.error.message // empty')

if [[ "$IMAGE_URL" == "null" || "$IMAGE_URL" == "" ]]; then
    echo "❌ Upload failed."
    if [[ -n "$UPLOAD_ERROR" ]]; then
        echo "Error: $UPLOAD_ERROR"
    fi
    echo "Full API Response: $RESPONSE"
else
    echo "✅ Screenshot uploaded: $IMAGE_URL"
fi

# --- Extract connection info from processed image ---
update_progress "Extracting connection information from OCR text..."
OCR_RESPONSE=$(curl -s -X POST "https://api.api-ninjas.com/v1/imagetotext" \
    -H "X-Api-Key: $NINJA_API_KEY" \
    -F "image=@$CROPPED_PATH")

echo "📋 Raw OCR Response:"
echo "$OCR_RESPONSE" | jq .

echo "[*] Looking for connection information in the OCR text:"

GETSCREEN_URL=$(echo "$OCR_RESPONSE" | jq -r '.[] | select(.text | test("https?://(go\\.)?getscreen\\.me/[0-9A-Za-z\\-]+")) | .text' | head -1)

CONNECTION_CODE=$(echo "$OCR_RESPONSE" | jq -r '.[] | select(.text | test("([0-9]{3}-){3}[0-9]{3,}|[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}|[A-Z0-9]{6,}")) | .text' | head -1)

echo -ne "\r                                                                       \r" >&2
if [ -n "$GETSCREEN_URL" ]; then
    echo "--- Connection Information ---" >&2
    echo "🔗 GetScreen.me Connection Link Found:" >&2
    echo "$GETSCREEN_URL" >&2
elif [ -n "$CONNECTION_CODE" ]; then
    echo "--- Connection Information ---" >&2
    echo "🔗 Connection Code/IP Found:" >&2
    echo "$CONNECTION_CODE" >&2
else
    echo "--- Connection Information ---" >&2
    echo "⚠️ No specific getscreen.me connection link, IP address, or code found in the screenshot." >&2
    echo "📋 All extracted text (for manual inspection, check $LOG_FILE for full details):" >&2
    echo "$OCR_RESPONSE" | jq -r '.[].text' >&2
fi

# --- Clean up temporary files ---
update_progress "Cleaning up temporary files..."
rm -f "$SCREENSHOT_PATH" "$CROPPED_PATH" "/tmp/test_crop.png" "$TEMP_OCR_FULL" "$TEMP_OCR_CROP"
echo "[*] Script finished."
echo "" >&2
