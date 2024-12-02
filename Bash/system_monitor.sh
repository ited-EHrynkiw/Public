#!/bin/bash

# Variables
LOG_DIR="/var/log/server_monitor"
PROCESS_LOG="$LOG_DIR/process_log_$(date +%F).log"
IO_LOG="$LOG_DIR/io_log_$(date +%F).log"
DISK_LOG="$LOG_DIR/disk_log_$(date +%F).log"
NETWORK_LOG="$LOG_DIR/network_log_$(date +%F).log"
SUMMARY_LOG="$LOG_DIR/summary_$(date +%F).log"

# Ensure the log directory exists
mkdir -p "$LOG_DIR"

# Function to log active processes
log_processes() {
    ps aux --sort=-%cpu,-%mem | head -n 20 > "$PROCESS_LOG"
}

# Function to log system I/O stats
log_io() {
    iostat -dx 1 5 > "$IO_LOG"
}

# Function to test hard drive performance
check_disk_performance() {
    dd if=/dev/zero of=/tmp/testfile bs=1G count=1 oflag=direct 2> "$DISK_LOG"
    rm -f /tmp/testfile
}

# Function to check network health
check_network_health() {
    GATEWAY=$(ip route | grep default | awk '{print $3}')
    ping -c 5 "$GATEWAY" > "$NETWORK_LOG" 2>&1
    ifstat 1 5 >> "$NETWORK_LOG" 2>&1
}

# Function to log PostgreSQL resource usage
log_postgres() {
    ps aux | grep postgres | grep -v grep >> "$PROCESS_LOG"
}

# Function to create a combined summary log
create_summary() {
    echo "Creating summary log..." > "$SUMMARY_LOG"
    echo "==== Summary of System Diagnostics ====" >> "$SUMMARY_LOG"

    # High CPU/Memory usage processes
    echo -e "\nHigh CPU/Memory Usage Processes (CPU > 50% or MEM > 50%):" >> "$SUMMARY_LOG"
    awk 'NR > 1 && ($3 > 50 || $4 > 50) {printf "%-8s %-8s %6.2f%% %6.2f%% %s\n", $1, $2, $3, $4, $11}' "$PROCESS_LOG" >> "$SUMMARY_LOG"

    # Disk I/O issues
    echo -e "\nDisk I/O Warnings (await > 50ms):" >> "$SUMMARY_LOG"
    awk '$10 > 50 {printf "%-8s %6.2f\n", $1, $10}' "$IO_LOG" >> "$SUMMARY_LOG"

    # Disk performance
    echo -e "\nDisk Performance Test Results:" >> "$SUMMARY_LOG"
    grep -i 'bytes' "$DISK_LOG" >> "$SUMMARY_LOG"

    # Network health
    echo -e "\nNetwork Health Issues (Packet Loss or Latency > 100ms):" >> "$SUMMARY_LOG"
    grep -E 'packet loss|time=[1-9][0-9]{2}' "$NETWORK_LOG" >> "$SUMMARY_LOG"

    echo -e "\nSummary saved in $SUMMARY_LOG."
}

# Check if necessary commands are available
check_dependencies() {
    for cmd in ps iostat dd ifstat awk grep ping ip; do
        if ! command -v $cmd &>/dev/null; then
            echo "Error: $cmd is not installed. Please install it and rerun the script."
            exit 1
        fi
    done
}

# Main function
main() {
    check_dependencies
    echo "Starting server monitoring..."
    log_processes
    log_postgres
    log_io
    check_disk_performance
    check_network_health
    create_summary
    echo "Logs saved in $LOG_DIR."
}

# Run the main function
main
