#!/bin/bash

# Function to get orchestrations supervisor PID
get_orchestration_pid() {
    pgrep -f "bash ./orchestrations.sh" | head -n 1
}

# Function to print usage
print_help() {
    echo "Usage:"
    echo "  ./orchestrations_control.sh stop-all     # Gracefully stop all scripts"
    echo "  ./orchestrations_control.sh stop <id>    # Gracefully stop script with ID (1, 2, or 3)"
    echo "  ./orchestrations_control.sh status       # Show supervisor and running processes"
}

# Parse arguments
case "$1" in
    stop-all)
        orchestration_pid=$(get_orchestration_pid)
        if [ -z "$orchestration_pid" ]; then
            echo "No running orchestrations supervisor found."
            exit 1
        fi
        echo "Sending SIGINT to orchestrations supervisor (PID: $orchestration_pid) to stop all scripts..."
        kill -SIGINT "$orchestration_pid"
        ;;
    stop)
        if [ -z "$2" ]; then
            echo "Please specify script number (1, 2, or 3)."
            print_help
            exit 1
        fi
        orchestration_pid=$(get_orchestration_pid)
        if [ -z "$orchestration_pid" ]; then
            echo "No running orchestrations supervisor found."
            exit 1
        fi
        case "$2" in
            1)
                echo "Stopping script 1..."
                kill -SIGUSR1 "$orchestration_pid"
                ;;
            2)
                echo "Stopping script 2..."
                kill -SIGUSR2 "$orchestration_pid"
                ;;
            3)
                echo "Stopping script 3..."
                kill -SIGTERM "$orchestration_pid"
                ;;
            *)
                echo "Invalid script number. Use 1, 2, or 3."
                ;;
        esac
        ;;
    status)
        orchestration_pid=$(get_orchestration_pid)
        if [ -z "$orchestration_pid" ]; then
            echo "No orchestrations supervisor is currently running."
        else
            echo "Orchestrations supervisor running with PID: $orchestration_pid"
            echo "Process tree:"
            ps -f --forest --ppid "$orchestration_pid"
        fi
        ;;
    *)
        print_help
        ;;
esac
