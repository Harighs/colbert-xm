#!/bin/bash

pidfile="orchestrations.pid"
echo $$ > "$pidfile"

CRAWLER_ID=${CRAWLER_ID:-"crawler1"}
echo "[Supervisor] CRAWLER_ID = $CRAWLER_ID"

declare -A loop_pids   # map command string -> loop PID
declare -a running_cmds=()

# Function to start a loop for a specific command
start_loop_for_command() {
    local cmd="$1"
    echo "[Supervisor] Starting loop for command: $cmd"

    (
        while true; do
            echo "[Supervisor] Executing: $cmd"
            setsid bash -c "$cmd" &
            local child_pid=$!
            wait $child_pid
            echo "[Supervisor] Command loop ended or crashed, restarting in 5s: $cmd"
            sleep 5
        done
    ) &
    loop_pids["$cmd"]=$!
}

# Function to stop a running loop for a specific command
stop_loop_for_command() {
    local cmd="$1"
    local loop_pid="${loop_pids[$cmd]}"
    if [ -n "$loop_pid" ]; then
        echo "[Supervisor] Stopping loop for command: $cmd (PID $loop_pid)"
        kill -TERM "$loop_pid" 2>/dev/null
        wait "$loop_pid" 2>/dev/null
        unset loop_pids["$cmd"]
    fi
}

# Global shutdown
graceful_shutdown() {
    echo "[Supervisor] Received termination signal, shutting down..."
    for cmd in "${!loop_pids[@]}"; do
        stop_loop_for_command "$cmd"
    done
    rm -f "$pidfile"
    exit 0
}
trap graceful_shutdown SIGINT SIGTERM SIGHUP

# Function to load desired commands from config
load_desired_commands() {
    mapfile -t desired_cmds < <(grep "^$CRAWLER_ID:" commands.conf | cut -d':' -f2-)
}

# Watcher loop to detect changes and reconcile
watcher_loop() {
    while true; do
        load_desired_commands

        # Start new commands
        for cmd in "${desired_cmds[@]}"; do
            if [ -z "${loop_pids[$cmd]}" ]; then
                echo "[Watcher] New command detected: $cmd"
                start_loop_for_command "$cmd"
            fi
        done

        # Stop removed commands
        for existing_cmd in "${!loop_pids[@]}"; do
            if ! printf '%s\n' "${desired_cmds[@]}" | grep -Fxq "$existing_cmd"; then
                echo "[Watcher] Command removed from config: $existing_cmd"
                stop_loop_for_command "$existing_cmd"
            fi
        done

        sleep 15  # Check every 15 seconds (adjustable)
    done
}

# Initial load and start watcher
load_desired_commands
for cmd in "${desired_cmds[@]}"; do
    start_loop_for_command "$cmd"
done

watcher_loop &

# Wait for background processes
wait

echo "[Supervisor] All done, exiting."
rm -f "$pidfile"
