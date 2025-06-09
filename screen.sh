#!/bin/bash
# --- Configuration ---
IMGUR_API_KEY="f8f01de269e26920152bdea96ed4fdd4"
NINJA_API_KEY="YiWejAGWZ2h13WXnrN/JFw==LoeaMiLtXI0cRC16"
SCREENSHOT_PATH="/tmp/screenshot.png"
CROPPED_PATH="/tmp/screenshot_cropped.png"
XVFB_DISPLAY=":99"
RESOLUTION="1280x1024x24"

# --- Install Dependencies ---
echo "[*] Installing Dependencies..."
sudo apt update
sudo apt install -y wget curl x11-utils imagemagick openbox xvfb jq scrot feh tint2 xfce4-terminal lxappearance pcmanfm wmctrl

# --- Install Firefox ---
add-apt-repository ppa:mozillateam/ppa -y
apt update
apt install --assume-yes firefox-esr
apt install --assume-yes dbus-x11 dbus

# --- Install getscreen.me ---
echo "[*] Installing getscreen.me..."
wget https://getscreen.me/download/getscreen.me.deb -O /tmp/getscreen.me.deb
sudo dpkg -i /tmp/getscreen.me.deb
sudo apt --assume-yes --fix-broken install

# --- Start Virtual Display ---
echo "[*] Starting Xvfb..."
Xvfb $XVFB_DISPLAY -screen 0 $RESOLUTION &
sleep 2
export DISPLAY=$XVFB_DISPLAY

# --- Start Openbox ---
echo "[*] Starting Openbox..."
openbox-session &
sleep 2

# --- Set wallpaper ---
echo "[*] Setting wallpaper..."
mkdir -p /root/.config
feh --bg-scale /usr/share/pixmaps/debian-logo.png 2>/dev/null || \
feh --bg-color black

# --- Launch panel (tint2) ---
echo "[*] Launching panel (tint2)..."
tint2 &

# --- Launch terminal ---
echo "[*] Launching terminal..."
xfce4-terminal &

# --- Launch file explorer ---
echo "[*] Launching file explorer (PCManFM)..."
pcmanfm --no-desktop &

# --- Launch getscreen.me ---
echo "[*] Launching getscreen.me..."
/opt/getscreen.me/getscreen.me &
sleep 15

---

### Main Loop for Periodic Message Sending

```bash
while true; do
    echo "--- <span class="math-inline">\(date\) \-\-\-"
echo "\[\*\] Running getscreen\.me connection info extraction\.\.\."
\# \-\-\- Find and focus getscreen\.me window \-\-\-
echo "\[\*\] Finding getscreen\.me window\.\.\."
WINDOW\_ID\=</span>(wmctrl -l | grep -i "getscreen" | awk '{print $1}' | head -1)

    if [[ -z "<span class="math-inline">WINDOW\_ID" \]\]; then
echo "\[\!\] getscreen\.me window not found\. Trying alternative approach\.\.\."
WINDOW\_ID\=</span>(xwininfo -root -tree | grep -i "getscreen" | grep -o "0x[0-9a-fA-F]*" | head -1)
    fi

    if [[ -n "$WINDOW_ID" ]]; then
        echo "[*] Found getscreen.me window: $WINDOW_ID"
        wmctrl -i -a "<span class="math-inline">WINDOW\_ID"
sleep 2
WINDOW\_GEOMETRY\=</span>(xwininfo -id "<span class="math-inline">WINDOW\_ID" \| grep \-E "Absolute upper\-left\|Width\|Height"\)
X\_POS\=</span>(echo "$WINDOW_GEOMETRY" | grep "Absolute upper-left X" | awk '{print <span class="math-inline">4\}'\)
Y\_POS\=</span>(echo "$WINDOW_GEOMETRY" | grep "Absolute upper-left Y" | awk '{print <span class="math-inline">4\}'\)
WIDTH\=</span>(echo "$WINDOW_GEOMETRY" | grep "Width" | awk '{print <span class="math-inline">2\}'\)
HEIGHT\=</span>(echo "$WINDOW_GEOMETRY" | grep "Height" | awk '{print $2}')
        echo "[*] Window position: <span class="math-inline">\{X\_POS\}x</span>{Y_POS}, Size: <span class="math-inline">\{WIDTH\}x</span>{HEIGHT}"
        echo "[*] Capturing screenshot of getscreen.me window..."
        scrot -a "<span class="math-inline">\{X\_POS\},</span>{Y_POS},<span class="math-inline">\{WIDTH\},</span>{HEIGHT}" "$SCREENSHOT_PATH"
    else
        echo "[!] Could not find getscreen.me window. Taking full screenshot..."
        scrot "$SCREENSHOT_PATH"
    fi

    if [[ ! -f "$SCREENSHOT_PATH" ]]; then
        echo "[!] Screenshot capture failed."
        sleep 300
        continue
    fi

    # --- Auto-detect and crop the connection info area ---
    echo "[*] Processing screenshot for connection info..."
    TEMP_OCR="/tmp/temp_ocr.json"
    curl -s -X POST "[https://api.api-ninjas.com/v1/imagetotext](https://api.api-ninjas.com/v1/imagetotext)" \
        -H "X-Api-Key: $NINJA_API_KEY" \
        -F "image=@$SCREENSHOT_PATH" > "<span class="math-inline">TEMP\_OCR"
FULL\_EXTRACTED\_TEXT\=</span>(cat "$TEMP_OCR" | jq -r '.[] | select(.text | test("getscreen\\.me|[0-9]{3}\\.[0-9]{3}\\.[0-9]{2}")) | .text')

    if [ -n "$FULL_EXTRACTED_TEXT" ]; then
        echo "[*] Connection info found in full screenshot"
        cp "$SCREENSHOT_PATH" "<span class="math-inline">CROPPED\_PATH"
else
echo "\[\*\] Trying to locate connection info area\.\.\."
CROP\_AREAS\=\(
"400x200\+50\+50"
"500x300\+100\+100"
"600x400\+50\+200"
"400x150\+200\+50"
\)
FOUND\_INFO\=false
for CROP in "</span>{CROP_AREAS[@]}"; do
            echo "[*] Trying crop area: $CROP"
            convert "$SCREENSHOT_PATH" -crop "<span class="math-inline">CROP" "/tmp/test\_crop\.png"
TEST\_OCR\=</span>(curl -s -X POST "[https://api.api-ninjas.com/v1/imagetotext](https://api.api-ninjas.com/v1/imagetotext)" \
                -H "X-Api-Key: <span class="math-inline">NINJA\_API\_KEY" \\
\-F "image\=@/tmp/test\_crop\.png"\)
TEST\_TEXT\=</span>(echo "$TEST_OCR" | jq -r '.[] | select(.text | test("getscreen\\.me|[0-9]{3}\\.[0-9]{3}\\.[0-9]{2}")) | .text')
            if [ -n "$TEST_TEXT" ]; then
                echo "[*] Found connection info in crop area: $CROP"
                cp "/tmp/test_crop.png" "$CROPPED_PATH"
                FOUND_INFO=true
                break
            fi
        done
        if [ "$FOUND_INFO" = false ]; then
            echo "[*] Using default crop of full screenshot"
            convert "$SCREENSHOT_PATH" -crop 600x400+0+0 "$CROPPED_PATH"
        fi
    fi

    if [[ ! -f "$CROPPED_PATH" ]]; then
        echo "[!] Image processing failed."
        sleep 300
        continue
    fi

    # --- Upload Screenshot (optional) ---
    echo "[*] Uploading screenshot..."
    UPLOAD_URL="[https://api.imgbb.com/1/upload?key=$IMGUR_API_KEY](https://api.imgbb.com/1/upload?key=<span class="math-inline">IMGUR\_API\_KEY\)"
RESPONSE\=</span>(curl -s -X POST -F "image=@$CROPPED_PATH" "<span class="math-inline">UPLOAD\_URL"\)
IMAGE\_URL\=</span>(echo "$RESPONSE" | jq -r '.data.url')

    if [[ "$IMAGE_URL" == "null" || "$IMAGE_URL" == "" ]]; then
        echo "❌ Upload failed."
        echo "Response: $RESPONSE"
    else
        echo "✅ Screenshot uploaded: <span class="math-inline">IMAGE\_URL"
fi
\# \-\-\- Extract connection info from processed image \-\-\-
echo "\[\*\] Extracting connection information\.\.\."
OCR\_RESPONSE\=</span>(curl -s -X POST "[https://api.api-ninjas.com/v1/imagetotext](https://api.api-ninjas.com/v1/imagetotext)" \
        -H "X-Api-Key: $NINJA_API_KEY" \
        -F "image=@$CROPPED_PATH")

    echo "📋 Raw OCR Response:"
    echo "<span class="math-inline">OCR\_RESPONSE"
\# \-\-\- Extract connection information \-\-\-
echo "\[\*\] Looking for connection information\:"
GETSCREEN\_TEXT\=</span>(echo "<span class="math-inline">OCR\_RESPONSE" \| jq \-r '\.\[\] \| select\(\.text \| test\("getscreen\\\\\.me"\)\) \| \.text'\)
CONNECTION\_TEXT\=</span>(echo "$OCR_RESPONSE" | jq -r '.[] | select(.text | test("[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}|[A-Z0-9]{6,}")) | .text')

    if [ -n "$GETSCREEN_TEXT" ]; then
        clear
        echo "🔗 GetScreen.me Connection Link Found:"
        echo "$GETSCREEN_TEXT"
    elif [ -n "$CONNECTION_TEXT" ]; then
        clear
        echo "🔗 Connection Information Found:"
        echo "$CONNECTION_TEXT"
    else
        echo "⚠️ No connection information found in the screenshot."
        echo "📋 All extracted text:"
        echo "$OCR_RESPONSE" | jq -r '.[].text'
    fi

    # Clean up temporary files
    rm -f /tmp/test_crop.png "$TEMP_OCR"

    echo "[*] Waiting 5 minutes before the next iteration..."
    sleep 300 # Sleep for 300 seconds (5 minutes)
done
