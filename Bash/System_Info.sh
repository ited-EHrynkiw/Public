#!/bin/bash

# Define threshold values
CPU_THRESHOLD=80         # CPU usage percentage threshold
MEMORY_THRESHOLD=80      # Memory usage percentage threshold
IO_WAIT_THRESHOLD=80     # I/O wait percentage threshold
DISK_UTIL_THRESHOLD=80   # Disk utilization percentage threshold
DISK_AVG_WAIT_THRESHOLD=10  # Average wait time in ms (e.g., 10ms)

# Function to check if required packages are installed
check_and_install_packages() {
    # List of required packages
    REQUIRED_PACKAGES=("sysstat" "lscpu" "bc" "df")

    # Detect package manager and install missing packages
    if command -v apt-get &> /dev/null; then
        PKG_MANAGER="apt-get"
        INSTALL_CMD="sudo apt-get install -y"
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
        INSTALL_CMD="sudo yum install -y"
    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
        INSTALL_CMD="sudo dnf install -y"
    elif command -v zypper &> /dev/null; then
        PKG_MANAGER="zypper"
        INSTALL_CMD="sudo zypper install -y"
    else
        echo "Unsupported package manager. Please install required packages manually: ${REQUIRED_PACKAGES[@]}"
        exit 1
    fi

    # Check each required package
    for package in "${REQUIRED_PACKAGES[@]}"; do
        if ! command -v "$package" &> /dev/null; then
            echo "Package '$package' not found. Installing..."
            $INSTALL_CMD "$package"
        else
            echo "Package '$package' is already installed."
        fi
    done
}

# Function to display system information
get_system_info() {
    echo "Gathering system information..."
    echo "----------------------------------------"

    # Hostname
    echo "Hostname: $(hostname -f)"

    # Operating System and Kernel Version
    echo "OS and Kernel: $(uname -o) $(uname -r)"

    # CPU Model and Cores
    echo "CPU Model: $(lscpu | grep 'Model name' | awk -F ': ' '{print $2}')"
    echo "CPU Cores: $(lscpu | grep '^CPU(s):' | awk -F ': ' '{print $2}')"

    # Total RAM
    echo "Total RAM: $(free -h | awk '/^Mem:/ {print $2}')"

    # Disk Space
    echo "Disk Space:"
    df -h --output=source,size,used,avail,pcent / | sed '1 s/^/  /'

    # IP Address
    IP_ADDRESS=$(hostname -I | awk '{print $1}')
    echo "IP Address: ${IP_ADDRESS:-Not Available}"

    # Uptime
    echo "System Uptime: $(uptime -p)"

    echo "----------------------------------------"
    echo
}

# Function to check CPU usage
check_cpu_usage() {
    echo "Checking CPU usage..."
    ps -eo pid,comm,%cpu --sort=-%cpu | awk -v threshold=$CPU_THRESHOLD '
    NR==1 {print $0}  # Print header
    NR>1 && $3 > threshold {print $0}
    '
}

# Function to check memory usage
check_memory_usage() {
    echo "Checking memory usage..."
    ps -eo pid,comm,%mem --sort=-%mem | awk -v threshold=$MEMORY_THRESHOLD '
    NR==1 {print $0}  # Print header
    NR>1 && $3 > threshold {print $0}
    '
}

# Function to check CPU I/O wait
check_io_wait() {
    echo "Checking I/O wait time..."
    IOWAIT=$(iostat -c 1 2 | awk 'NR==4 {print $4}')  # Get I/O wait from iostat
    if (( $(echo "$IOWAIT > $IO_WAIT_THRESHOLD" | bc -l) )); then
        echo "High CPU I/O wait detected: $IOWAIT%"
    else
        echo "CPU I/O wait is within normal limits: $IOWAIT%"
    fi
}

# Function to check disk I/O
check_disk_io() {
    echo "Checking disk I/O utilization and wait time..."

    # Use iostat to get disk utilization and average wait time
    iostat -x 1 2 | awk -v util_threshold=$DISK_UTIL_THRESHOLD -v wait_threshold=$DISK_AVG_WAIT_THRESHOLD '
    NR > 7 {
        if ($14 > util_threshold) {
            printf "High disk utilization on %s: %.2f%%\n", $1, $14
        }
        if ($10 > wait_threshold) {
            printf "High average wait time on %s: %.2f ms\n", $1, $10
        }
    }
    '
}

# Check and install required packages
check_and_install_packages

# Display system information
get_system_info

# Check for high CPU usage
check_cpu_usage
echo

# Check for high memory usage
check_memory_usage
echo

# Check for high CPU I/O wait
check_io_wait
echo

# Check for high disk I/O utilization and wait times
check_disk_io
echo

echo "System check completed."
