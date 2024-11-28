#!/bin/bash

# Define color variables
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Function to print aligned output
print_aligned() {
    printf "${CYAN}%-35s${NC} ${GREEN}%s${NC}\n" "$1" "$2"
}

# Convert to IEC format
toiec() {
    echo -e "${MAGENTA}$(printf "%'d" $(($1 >> 10))) MiB$([[ $1 -ge 1048576 ]] && echo " ($(numfmt --from=iec --to=iec-i "${1}K")B)")${NC}"
}

# Convert to SI format
tosi() {
    echo -e "${MAGENTA}$(printf "%'d" $(((($1 << 10) / 1000) / 1000))) MB$([[ $1 -ge 1000000 ]] && echo " ($(numfmt --from=iec --to=si "${1}K")B)")${NC}"
}

# OS Information
# shellcheck source=/dev/null
. /etc/os-release
print_aligned "Linux Distribution:" "${PRETTY_NAME:-$ID-$VERSION_ID}"

# Kernel Information
KERNEL=$(</proc/sys/kernel/osrelease)
print_aligned "Linux Kernel:" "$KERNEL"

# Computer Model
file=/sys/class/dmi/id
MODEL=""
if [[ -d $file ]]; then
    [[ -r "$file/sys_vendor" ]] && MODEL=$(<"$file/sys_vendor")
    [[ -r "$file/product_name" ]] && MODEL+=" $(<"$file/product_name")"
    [[ -r "$file/product_version" ]] && MODEL+=" $(<"$file/product_version")"
elif [[ -r /sys/firmware/devicetree/base/model ]]; then
    MODEL=$(<"/sys/firmware/devicetree/base/model")
fi
print_aligned "Computer Model:" "$MODEL"

# Processor (CPU) Information
mapfile -t CPU < <(sed -n 's/^model name[[:blank:]]*: *//p' /proc/cpuinfo | uniq)
print_aligned "Processor (CPU):" "${CPU[0]}"

# CPU Sockets/Cores/Threads
CPU_THREADS=$(nproc --all)
CPU_CORES=$(lscpu | awk '/^Core\(s\) per socket:/ {print $4}')
CPU_SOCKETS=$(lscpu | awk '/^Socket\(s\):/ {print $2}')
print_aligned "CPU Sockets/Cores/Threads:" "$CPU_SOCKETS/$CPU_CORES/$CPU_THREADS"

# CPU Caches
echo -e "${CYAN}CPU Caches:${NC}"
for cache in L1d L1i L2 L3; do
    SIZE=$(lscpu | grep "$cache cache:" | awk '{print $3}')
    printf "\t${GREEN}%-10s${NC} %s\n" "$cache:" "$SIZE"
done

# Top 5 most active processes by CPU and memory usage
echo -e "${CYAN}Top 5 most active processes:${NC}"
printf "${YELLOW}%-8s %-20s %-10s %-10s${NC}\n" "PID" "COMMAND" "CPU (%)" "MEM (%)"
ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -n 6 | awk -v green="${GREEN}" -v nc="${NC}" '
NR>1 {printf "\t%s%-8s %-20s %-10s %-10s%s\n", green, $1, $2, $3, $4, nc}'

# Architecture
ARCHITECTURE=$(getconf LONG_BIT)
print_aligned "Architecture:" "$HOSTTYPE (${ARCHITECTURE}-bit)"

# Memory Information
MEMINFO=$(</proc/meminfo)
TOTAL_PHYSICAL_MEM=$(echo "$MEMINFO" | awk '/^MemTotal:/ { print $2 }')
print_aligned "Total memory (RAM):" "$(toiec "$TOTAL_PHYSICAL_MEM") ($(tosi "$TOTAL_PHYSICAL_MEM"))"

# Swap Information
TOTAL_SWAP=$(echo "$MEMINFO" | awk '/^SwapTotal:/ { print $2 }')
print_aligned "Total swap space:" "$(toiec "$TOTAL_SWAP") ($(tosi "$TOTAL_SWAP"))"

# Disk Information
echo -e "${CYAN}Disk space:${NC}"
DISKS=$(lsblk -dbn 2>/dev/null | awk '$6=="disk" {print $1, $4}')
while IFS=" " read -r NAME SIZE; do
    if [[ -n "$SIZE" && "$SIZE" =~ ^[0-9]+$ ]]; then
        SIZE_FORMATTED="$(printf "%'d" $((SIZE >> 20))) MiB ($(numfmt --to=iec-i "$SIZE")B)"
        printf "\t${GREEN}%-10s${NC} %s\n" "$NAME:" "$SIZE_FORMATTED"
    fi
done <<<"$DISKS"

# GPU Information
GPU=$(lspci | grep -i 'vga\|3d\|2d')
print_aligned "Graphics Processor (GPU):" "$GPU"

# Hostname and Computer Name
print_aligned "Computer name:" "$HOSTNAME"
print_aligned "Hostname:" "$(hostname -f)"

# Network Interfaces and IP Addresses
echo -e "${CYAN}IPv4 addresses:${NC}"
for interface in $(ip -o -4 addr show | awk '{print $2}'); do
    IP=$(ip -o -4 addr show $interface | awk '{print $4}')
    printf "\t${GREEN}%-10s${NC} %s\n" "$interface:" "$IP"
done

# MAC Addresses
echo -e "${CYAN}MAC addresses:${NC}"
for interface in $(ip -o link show | awk -F': ' '{print $2}'); do
    mac_file="/sys/class/net/$interface/address"
    if [[ -r $mac_file ]]; then
        MAC=$(<"$mac_file")
        printf "\t${GREEN}%-10s${NC} %s\n" "$interface:" "$MAC"
    else
        printf "\t${YELLOW}%-10s${NC} ${RED}MAC address not available${NC}\n" "$interface:"
    fi
done

# Computer ID
if [[ -r /var/lib/dbus/machine-id ]]; then
    COMPUTER_ID=$(</var/lib/dbus/machine-id)
    print_aligned "Computer ID:" "$COMPUTER_ID"
fi

# Time Zone
TIME_ZONE=$(timedatectl show -p Timezone --value)
print_aligned "Time zone:" "$TIME_ZONE"

# Language
print_aligned "Language:" "$LANG"

# Virtual Machine (VM) Hypervisor
VM=$(systemd-detect-virt -v 2>/dev/null)
if [[ -n $VM ]]; then
    print_aligned "Virtual Machine (VM) hypervisor:" "$VM"
fi

# Bash Version
print_aligned "Bash Version:" "$BASH_VERSION"

# Terminal Information
print_aligned "Terminal:" "$TERM"
