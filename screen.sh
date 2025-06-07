#!/bin/bash

# --- Configuration ---
IMGUR_API_KEY="f8f01de269e26920152bdea96ed4fdd4"
SCREENSHOT_PATH="/tmp/screenshot.png"
XVFB_DISPLAY=":99"
RESOLUTION="1280x1024x24"

# --- Install Dependencies ---
echo "[*] Installing Dependencies..."
sudo apt update
sudo apt install -y wget curl x11-utils imagemagick openbox xvfb jq \
                    scrot feh tint2 xfce4-terminal lxappearance pcmanfm
# --- Install Google Chrome ---   
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo dpkg -i google-chrome-stable_current_amd64.deb
sudo apt --fix-broken install
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
openbox-session &  # safer and more complete
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

sleep 10

# --- Capture Screenshot ---
echo "[*] Capturing screenshot..."
scrot "$SCREENSHOT_PATH"
if [[ ! -f "$SCREENSHOT_PATH" ]]; then
    echo "[!] Screenshot capture failed."
    exit 1
fi

# --- Upload Screenshot ---
echo "[*] Uploading..."
UPLOAD_URL="https://api.imgbb.com/1/upload?key=$IMGUR_API_KEY"
RESPONSE=$(curl -s -X POST -F "image=@$SCREENSHOT_PATH" "$UPLOAD_URL")
IMAGE_URL=$(echo "$RESPONSE" | jq -r '.data.url')

if [[ "$IMAGE_URL" != "null" && "$IMAGE_URL" != "" ]]; then
    echo "✅ Screenshot uploaded: $IMAGE_URL"
else
    echo "❌ Upload failed."
    echo "Response: $RESPONSE"
fi
