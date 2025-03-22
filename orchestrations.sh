#!/bin/bash

# === CONFIGURATION ===
commands=(
    "python3 src/script1.py -s 'src/setting.json' --record_number 20 --processing_status 20 --initial_status 20"
    "python3 src/script2.py -s 'src/setting.json' --record_number 50 --processing_status 10 --initial_status 5"
    "python3 src/script3.py -s 'src/setting.json' --record_number 100 --processing_status 50 --initial_status 10"
)
delays=(0 5 10)

# PID file for supervisor
pidfile="orchestrations.pid"
echo $$ > "$pidfile"

# Shutdown flags (0 = continue, 1 = stop next loop)
shutdown_flags=(0 0 0)

# === SIGNAL HANDLERS ===
trap 'shutdown_flags=(1 1 1); echo "Global shutdown requested (SIGINT)";' SIGINT
trap 'shutdown_flags=(1 1 1); echo "Global shutdown requested (SIGHUP)";' SIGHUP
trap 'shutdown_flags[0]=1; echo "Shutdown requested for script 1";' SIGUSR1
trap 'shutdown_flags[1]=1; echo "Shutdown requested for script 2";' SIGUSR2
trap 'shutdown_flags[2]=1; echo "Shutdown requested for script 3";' SIGTERM

# === MAIN FUNCTION TO RUN EACH COMMAND ===
run_script_loop() {
    local index=$1
    local cmd="${commands[$index]}"
    local delay="${delays[$index]:-0}"
    
    echo "Supervisor starting loop for script $((index+1)) after delay of $delay seconds."
    sleep "$delay"

    while true; do
        if [ "${shutdown_flags[$index]}" -eq 1 ]; then
            echo "[Supervisor] Stop flag set for script $((index+1)). Exiting loop."
            break
        fi

        echo "[Supervisor] Executing: $cmd"
        eval "$cmd"
        echo "[Supervisor] Script $((index+1)) finished."

        # Check shutdown again after completion
        if [ "${shutdown_flags[$index]}" -eq 1 ]; then
            echo "[Supervisor] Stop flag set for script $((index+1)) after completion."
            break
        fi

        echo "[Supervisor] Restarting script $((index+1)) after 5s pause."
        sleep 5
    done

    echo "[Supervisor] Graceful exit for script $((index+1)) loop."
}

# === Start each script loop in parallel ===
for i in "${!commands[@]}"; do
    run_script_loop "$i" &
done

wait

echo "[Supervisor] All script loops exited. Cleaning up."
rm -f "$pidfile"
