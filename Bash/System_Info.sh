#!/bin/bash

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'  # No Color

# Define threshold values
CPU_THRESHOLD=80         # CPU usage percentage threshold
MEMORY_THRESHOLD=80      # Memory usage percentage threshold
IO_WAIT_THRESHOLD=80     # I/O wait percentage threshold
DISK_UTIL_THRESHOLD=80   # Disk utilization percentage threshold
DISK_AVG_WAIT_THRESHOLD=10  # Average wait time in ms (e.g., 10ms)

# Function to check if required packages are installed
check_and_install_packages() {
    echo ""
    echo -e "${CYAN}Checking required packages...${NC}"

    REQUIRED_PACKAGES=("sysstat" "lscpu" "bc" "df")

    if command -v apt-get &> /dev/null; then
        INSTALL_CMD="sudo apt-get install -y"
    elif command -v yum &> /dev/null; then
        INSTALL_CMD="sudo yum install -y"
    elif command -v dnf &> /dev/null; then
        INSTALL_CMD="sudo dnf install -y"
    elif command -v zypper &> /dev/null; then
        INSTALL_CMD="sudo zypper install -y"
    else
        echo -e "${RED}Unsupported package manager. Please install required packages manually: ${REQUIRED_PACKAGES[@]}${NC}"
        exit 1
    fi

    for package in "${REQUIRED_PACKAGES[@]}"; do
        if ! command -v "$package" &> /dev/null; then
            echo -e "${YELLOW}Package '$package' not found. Installing...${NC}"
            $INSTALL_CMD "$package"
        else
            echo -e "${GREEN}Package '$package' is already installed.${NC}"
        fi
    done
    echo ""
}

# Function to display system information
get_system_info() {
    echo ""
    echo -e "${CYAN}Gathering system information...${NC}"
    echo -e "----------------------------------------"

    echo -e "${BLUE}Hostname:${NC} $(hostname -f)"
    echo -e "${BLUE}OS and Kernel:${NC} $(uname -o) $(uname -r)"
    echo -e "${BLUE}CPU Model:${NC} $(lscpu | grep 'Model name' | awk -F ': ' '{print $2}')"
    echo -e "${BLUE}CPU Cores:${NC} $(lscpu | grep '^CPU(s):' | awk -F ': ' '{print $2}')"
    echo -e "${BLUE}Total RAM:${NC} $(free -h | awk '/^Mem:/ {print $2}')"
    echo -e "${BLUE}Disk Space:${NC}"
    df -h --output=source,size,used,avail,pcent / | sed '1 s/^/  /'
    IP_ADDRESS=$(hostname -I | awk '{print $1}')
    echo -e "${BLUE}IP Address:${NC} ${IP_ADDRESS:-Not Available}"
    echo -e "${BLUE}System Uptime:${NC} $(uptime -p)"
    echo -e "----------------------------------------\n"
    echo ""
}

# Function to check CPU usage
check_cpu_usage() {
    echo -e "${CYAN}Checking CPU usage...${NC}"
    ps -eo pid,comm,%cpu --sort=-%cpu | awk -v threshold=$CPU_THRESHOLD -v red=$RED -v nc=$NC '
    NR==1 {print $0}
    NR>1 && $3 > threshold {printf "%s%s%s\n", red, $0, nc}
    '
}

# Function to check memory usage
check_memory_usage() {
    echo -e "${CYAN}Checking memory usage...${NC}"
    ps -eo pid,comm,%mem --sort=-%mem | awk -v threshold=$MEMORY_THRESHOLD -v red=$RED -v nc=$NC '
    NR==1 {print $0}
    NR>1 && $3 > threshold {printf "%s%s%s\n", red, $0, nc}
    '
}

# Function to check CPU I/O wait
check_io_wait() {
    echo -e "${CYAN}Checking I/O wait time...${NC}"
    IOWAIT=$(iostat -c 1 2 | awk 'NR==4 {print $4}')
    if (( $(echo "$IOWAIT > $IO_WAIT_THRESHOLD" | bc -l) )); then
        echo -e "${RED}High CPU I/O wait detected: $IOWAIT%${NC}"
    else
        echo -e "${GREEN}CPU I/O wait is within normal limits: $IOWAIT%${NC}"
    fi
}

# Function to check disk I/O
check_disk_io() {
    echo -e "${CYAN}Checking disk I/O utilization and wait time...${NC}"
    iostat -x 1 2 | awk -v util_threshold=$DISK_UTIL_THRESHOLD -v wait_threshold=$DISK_AVG_WAIT_THRESHOLD -v red=$RED -v green=$GREEN -v nc=$NC '
    NR > 7 {
        if ($14 > util_threshold) {
            printf "%sHigh disk utilization on %s: %.2f%%%s\n", red, $1, $14, nc
        }
        if ($10 > wait_threshold) {
            printf "%sHigh average wait time on %s: %.2f ms%s\n", red, $1, $10, nc
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

echo -e "${GREEN}System check completed.${NC}"