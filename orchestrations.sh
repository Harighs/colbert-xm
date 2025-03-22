#!/bin/bash

pidfile="orchestrations.pid"
echo $$ > "$pidfile"

# Load CRAWLER_ID from environment (default fallback)
CRAWLER_ID=${CRAWLER_ID:-"crawler1"}
echo "[Supervisor] CRAWLER_ID = $CRAWLER_ID"

# Dynamically load commands for this crawler only
mapfile -t commands < <(grep "^$CRAWLER_ID:" commands.conf | cut -d':' -f2-)

if [ ${#commands[@]} -eq 0 ]; then
    echo "[Supervisor] No commands found for $CRAWLER_ID in commands.conf. Exiting."
    rm -f "$pidfile"
    exit 1
fi

# Initialize arrays based on dynamic number of commands
shutdown_flags=()
child_pids=()
delays=()

for ((i=0; i<${#commands[@]}; i++)); do
    shutdown_flags+=(0)
    child_pids+=(0)
    delays+=(0)   # Optional: customize delays if needed
done

# Function to kill running children immediately
kill_child_immediately() {
    local idx=$1
    local cpid="${child_pids[$idx]}"
    if [ "$cpid" -ne 0 ] && kill -0 "$cpid" 2>/dev/null; then
        echo "[Supervisor] Killing process group for script $((idx+1)) (PGID: $cpid)"
        kill -TERM -"$cpid" 2>/dev/null
        wait "$cpid" 2>/dev/null
    fi
}

# Global signal handlers
trap 'for i in "${!shutdown_flags[@]}"; do shutdown_flags[$i]=1; kill_child_immediately $i; done; echo "[Supervisor] Global stop triggered (SIGINT or SIGTERM)";' SIGINT SIGTERM SIGHUP

run_script_loop() {
    local index=$1
    local delay="${delays[$index]:-0}"

    echo "[Supervisor] Starting loop for script $((index+1)) after ${delay}s delay."
    sleep "$delay"

    while true; do
        if [ "${shutdown_flags[$index]}" -eq 1 ]; then
            echo "[Supervisor] Stop flag detected for script $((index+1)). Exiting loop."
            kill_child_immediately "$index"
            break
        fi

        local cmd="${commands[$index]}"
        if [ -z "$cmd" ]; then
            echo "[Supervisor] No command found for index $((index+1)). Exiting."
            break
        fi

        echo "[Supervisor] Executing: $cmd"
        setsid bash -c "$cmd" &
        child_pids[$index]=$!

        # Wait for completion or forced stop
        wait "${child_pids[$index]}"
        child_pids[$index]=0

        if [ "${shutdown_flags[$index]}" -eq 1 ]; then
            echo "[Supervisor] Stop flag detected after script completion for $((index+1))."
            break
        fi

        echo "[Supervisor] Restarting script $((index+1)) in 5s..."
        sleep 5
    done

    echo "[Supervisor] Loop ended for script $((index+1))."
}

# Start all loops in parallel
for i in "${!commands[@]}"; do
    run_script_loop "$i" &
done

wait

echo "[Supervisor] All loops ended. Cleaning up."
rm -f "$pidfile"
