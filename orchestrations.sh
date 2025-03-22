#!/bin/bash

pidfile="orchestrations.pid"
echo $$ > "$pidfile"

# Delays for staggered startup
delays=(0 5 10)

# Shutdown flags: 0 = keep running, 1 = stop next iteration
shutdown_flags=(0 0 0)

# Track child pids for each script loop
child_pids=(0 0 0)

# Function to immediately kill a running script if flagged
kill_child_immediately() {
    local idx=$1
    local cpid="${child_pids[$idx]}"
    if [ "$cpid" -ne 0 ] && kill -0 "$cpid" 2>/dev/null; then
        echo "[Supervisor] Immediately killing process group for script $((idx+1)) (PGID: $cpid)"
        kill -TERM -"$cpid" 2>/dev/null
        wait "$cpid" 2>/dev/null
    fi
}

# Signal handlers for global and per-script stops
trap 'shutdown_flags=(1 1 1); echo "[Supervisor] Global stop triggered"; for i in {0..2}; do kill_child_immediately $i; done' SIGINT
trap 'shutdown_flags=(1 1 1); echo "[Supervisor] Global stop triggered (SIGHUP)"; for i in {0..2}; do kill_child_immediately $i; done' SIGHUP
trap 'shutdown_flags[0]=1; echo "[Supervisor] Stop requested for script 1"; kill_child_immediately 0' SIGUSR1
trap 'shutdown_flags[1]=1; echo "[Supervisor] Stop requested for script 2"; kill_child_immediately 1' SIGUSR2
trap 'shutdown_flags[2]=1; echo "[Supervisor] Stop requested for script 3"; kill_child_immediately 2' SIGTERM

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

        # Dynamically load command
        cmd=$(sed -n "$((index + 1))p" commands.conf)
        if [ -z "$cmd" ]; then
            echo "[Supervisor] No command found for script $((index+1)) in commands.conf. Skipping."
            break
        fi

        echo "[Supervisor] Executing script $((index+1)): $cmd"
        setsid bash -c "$cmd" &
        child_pids[$index]=$!

        # Wait for completion or forced stop
        wait "${child_pids[$index]}"
        child_pids[$index]=0

        if [ "${shutdown_flags[$index]}" -eq 1 ]; then
            echo "[Supervisor] Stop flag detected after execution for script $((index+1))."
            break
        fi

        echo "[Supervisor] Restarting script $((index+1)) in 5s..."
        sleep 5
    done

    echo "[Supervisor] Loop ended for script $((index+1))."
}

# Start all loops in parallel
for i in {0..2}; do
    run_script_loop "$i" &
done

wait

echo "[Supervisor] All loops ended. Cleaning up."
rm -f "$pidfile"
