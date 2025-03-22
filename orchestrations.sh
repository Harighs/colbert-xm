#!/bin/bash

pidfile="orchestrations.pid"
echo $$ > "$pidfile"

# Adjustable delays for staggered starts (in seconds)
delays=(0 5 10)

# Shutdown flags: 0 = continue; 1 = stop this loop after current iteration
shutdown_flags=(0 0 0)

# Trap signals for graceful or targeted shutdown
trap 'shutdown_flags=(1 1 1); echo "[Supervisor] Global shutdown requested (SIGINT)";' SIGINT
trap 'shutdown_flags=(1 1 1); echo "[Supervisor] Global shutdown requested (SIGHUP)";' SIGHUP
trap 'shutdown_flags[0]=1; echo "[Supervisor] Shutdown requested for script 1";' SIGUSR1
trap 'shutdown_flags[1]=1; echo "[Supervisor] Shutdown requested for script 2";' SIGUSR2
trap 'shutdown_flags[2]=1; echo "[Supervisor] Shutdown requested for script 3";' SIGTERM

run_script_loop() {
    local index=$1
    local delay="${delays[$index]:-0}"

    echo "[Supervisor] Starting loop for script $((index+1)) after ${delay}s delay."
    sleep "$delay"

    local child_pid=0

    while true; do
        if [ "${shutdown_flags[$index]}" -eq 1 ]; then
            echo "[Supervisor] Stop flag detected for script $((index+1)). Exiting loop."
            if [ "$child_pid" -ne 0 ] && kill -0 "$child_pid" 2>/dev/null; then
                echo "[Supervisor] Killing process group for child PID $child_pid"
                kill -TERM -"$child_pid" 2>/dev/null
                wait "$child_pid"
            fi
            break
        fi

        # Dynamically load command
        cmd=$(sed -n "$((index + 1))p" commands.conf)
        if [ -z "$cmd" ]; then
            echo "[Supervisor] No command found for script $((index+1)) in commands.conf, skipping."
            break
        fi

        echo "[Supervisor] Executing script $((index+1)): $cmd"
        setsid bash -c "$cmd" &
        child_pid=$!

        # Wait for completion or forced shutdown
        wait "$child_pid"
        child_pid=0

        if [ "${shutdown_flags[$index]}" -eq 1 ]; then
            echo "[Supervisor] Stop flag detected after execution for script $((index+1))."
            break
        fi

        echo "[Supervisor] Restarting script $((index+1)) in 5s..."
        sleep 5
    done

    echo "[Supervisor] Loop ended for script $((index+1))."
}

