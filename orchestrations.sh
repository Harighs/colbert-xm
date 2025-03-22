#!/bin/bash

# === CONFIGURATION ===
# Add your Python commands with full args below
commands=(
    "python3 src/script1.py -s 'src/setting.json' --record_number 20 --processing_status 20 --initial_status 20"
    "python3 src/script2.py -s 'src/setting.json' --record_number 50 --processing_status 10 --initial_status 5"
    "python3 src/script3.py -s 'src/setting.json' --record_number 100 --processing_status 50 --initial_status 10"
)

# Optional: add delays for staggered startup (in seconds)
delays=(0 5 10)

# Initialize shutdown flags
shutdown_flags=(0 0 0)

# === SIGNAL HANDLERS ===
trap 'shutdown_flags=(1 1 1); echo "Shutdown requested for ALL scripts (SIGINT)";' SIGINT
trap 'shutdown_flags=(1 1 1); echo "Shutdown requested for ALL scripts (SIGHUP)";' SIGHUP
trap 'shutdown_flags[0]=1; echo "Shutdown requested for script 1 (SIGUSR1)";' SIGUSR1
trap 'shutdown_flags[1]=1; echo "Shutdown requested for script 2 (SIGUSR2)";' SIGUSR2
trap 'shutdown_flags[2]=1; echo "Shutdown requested for script 3 (SIGTERM)";' SIGTERM

# === MAIN FUNCTION TO RUN EACH COMMAND ===
run_forever() {
    local index=$1
    local cmd="${commands[$index]}"
    local delay="${delays[$index]:-0}"

    echo "Starting supervisor for script $((index+1)) with delay ${delay}s"
    sleep $delay

    while [ ${shutdown_flags[$index]} -eq 0 ]; do
        echo "[Orchestration] Starting: $cmd"
        # Start Python script in background and track its PID
        eval "$cmd" &
        child_pid=$!

        # Wait for process or shutdown signal
        wait $child_pid

        if [ ${shutdown_flags[$index]} -eq 1 ]; then
            echo "[Orchestration] Shutdown flag detected for script $((index+1)). Sending SIGTERM to child PID ($child_pid) if still alive..."
            kill -SIGTERM $child_pid 2>/dev/null
            wait $child_pid
            break
        fi

        echo "[Orchestration] $cmd exited. Restarting in 5 seconds (unless shutdown flag is set)..."
        sleep 5
    done

    echo "[Orchestration] Graceful shutdown complete for: $cmd"
}

# === START ALL COMMANDS IN PARALLEL ===
for i in "${!commands[@]}"; do
    run_forever $i &
done

# Wait for all run_forever loops
wait

echo "[Orchestration] All orchestrations stopped gracefully."
