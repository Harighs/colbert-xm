#!/bin/bash

pidfile="orchestrations.pid"

get_orchestration_pid() {
    if [ -f "$pidfile" ]; then
        cat "$pidfile"
    else
        echo ""
    fi
}

print_help() {
    echo "Usage:"
    echo "  ./orchestrations_control.sh stop-all     # Stop all scripts after current iteration"
    echo "  ./orchestrations_control.sh stop <id>    # Stop script with ID (1, 2, or 3)"
    echo "  ./orchestrations_control.sh status       # Show supervisor and child processes"
}

case "$1" in
    stop-all)
        orchestration_pid=$(get_orchestration_pid)
        if [ -z "$orchestration_pid" ]; then
            echo "No running supervisor found."
            exit 1
        fi
        echo "Sending SIGINT to supervisor PID $orchestration_pid (stop all)..."
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
            echo "No running supervisor found."
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
            echo "Supervisor not running."
        else
            echo "Supervisor PID: $orchestration_pid"
            echo "Process tree:"
            pstree -p "$orchestration_pid" || ps -f --forest --ppid "$orchestration_pid"
        fi
        ;;
    *)
        print_help
        ;;
esac
