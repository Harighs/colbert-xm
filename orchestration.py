import subprocess
import signal
import sys
import threading
import time
import os
import json

# Configuration from environment variables
DEVICE_ID = int(os.getenv("DEVICE", 0))
START_INSTANCES = int(os.getenv("START_INSTANCES", 2))
CRAWLER_SCRIPT = os.getenv("CRAWLER_SCRIPT", "/app/your_crawler_script.py")
CONTROL_FILE = "/mnt/control/scale_command.json"

# Thread-safe list of running crawler subprocesses
running_crawlers = []
lock = threading.Lock()

def start_crawler():
    """Start a single crawler process."""
    proc = subprocess.Popen(["python", CRAWLER_SCRIPT, "--device", str(DEVICE_ID)])
    with lock:
        running_crawlers.append(proc)
    print(f"✅ Started crawler (PID={proc.pid})")
    return proc

def stop_crawler():
    """Stop one crawler process gracefully."""
    with lock:
        if running_crawlers:
            proc = running_crawlers.pop()
            print(f"🛑 Stopping crawler (PID={proc.pid})")
            proc.terminate()
            proc.wait()

def graceful_shutdown(signum, frame):
    """Handle shutdown signals by terminating all crawlers."""
    print("⚠️ Graceful shutdown initiated...")
    with lock:
        for proc in running_crawlers:
            print(f"Terminating crawler (PID={proc.pid})")
            proc.terminate()
        for proc in running_crawlers:
            proc.wait()
    print("✅ All crawlers stopped. Exiting.")
    sys.exit(0)

def adjust_crawlers(desired_count):
    """Adjust the number of running crawlers to match the desired count."""
    with lock:
        current = len(running_crawlers)
    if desired_count > current:
        for _ in range(desired_count - current):
            start_crawler()
    elif desired_count < current:
        for _ in range(current - desired_count):
            stop_crawler()
    print(f"📊 Adjusted crawlers to: {desired_count}")

def monitor_control_file():
    """Continuously watch the control file for scaling instructions."""
    while True:
        time.sleep(5)
        if os.path.exists(CONTROL_FILE):
            try:
                with open(CONTROL_FILE, "r") as f:
                    command = json.load(f)
                desired_instances = command.get("desired_instances", START_INSTANCES)
                if desired_instances == 0:
                    print("🛑 Shutdown requested via control file.")
                    graceful_shutdown(None, None)
                else:
                    adjust_crawlers(desired_instances)
            except Exception as e:
                print(f"[Control Monitor Error] {e}")

# Set up signal handlers for container lifecycle events
signal.signal(signal.SIGTERM, graceful_shutdown)
signal.signal(signal.SIGINT, graceful_shutdown)

# Start initial crawlers
print(f"🚀 Starting {START_INSTANCES} crawlers on GPU {DEVICE_ID}")
for _ in range(START_INSTANCES):
    start_crawler()

# Start monitoring thread for control file changes
threading.Thread(target=monitor_control_file, daemon=True).start()

# Keep the main loop running, clean up dead processes
try:
    while True:
        time.sleep(1)
        with lock:
            running_crawlers[:] = [p for p in running_crawlers if p.poll() is None]
except KeyboardInterrupt:
    graceful_shutdown(None, None)
