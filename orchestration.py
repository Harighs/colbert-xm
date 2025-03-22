#!/bin/bash

# Define your commands
commands=("python3 script1.py" "python3 script2.py" "python3 script3.py")

# Flags to track shutdown per script
shutdown_flags=(0 0 0)

# Trap handlers for individual shutdown
trap 'shutdown_flags[0]=1; echo "Shutdown requested for script 1"' SIGUSR1
trap 'shutdown_flags[1]=1; echo "Shutdown requested for script 2"' SIGUSR2
trap 'shutdown_flags[2]=1; echo "Shutdown requested for script 3"' SIGTERM

# Trap handler to gracefully stop all at once (use SIGINT or SIGHUP)
trap 'shutdown_flags=(1 1 1); echo "Shutdown requested for ALL scripts"' SIGINT
trap 'shutdown_flags=(1 1 1); echo "Shutdown requested for ALL scripts"' SIGHUP

# Function to run and restart each command until flagged
run_forever() {
    local index=$1
    local cmd="${commands[$index]}"
    while [ ${shutdown_flags[$index]} -eq 0 ]; do
        echo "Starting: $cmd"
        $cmd
        echo "$cmd exited. Restarting in 5 seconds (unless shutdown flag is set)..."
        sleep 5
    done
    echo "Graceful shutdown complete for: $cmd"
}

# Start all commands in the background
for i in "${!commands[@]}"; do
    run_forever $i &
done

# Wait for all background jobs to finish
wait
