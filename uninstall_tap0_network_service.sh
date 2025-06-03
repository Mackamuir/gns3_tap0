#!/bin/bash

# ANSI escape codes for colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
WHITE='\033[1;37m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# File paths
script_path="/usr/local/bin/setup_network.sh"
service_path="/etc/systemd/system/setup_network.service"

# Function to remove all dynamically created bridges and taps
remove_setup_network() {
    echo -e "${RED}→ ${WHITE}Removing network setup... ${PURPLE}[50%]${NC}"

    # Remove all tap interfaces
    for tap in $(ip -o link show | awk -F': ' '{print $2}' | grep -E '^tap[0-9]+$'); do
        echo -e "${YELLOW}Removing TAP interface: $tap${NC}"
        sudo ip link set "$tap" down 2>/dev/null
        sudo tunctl -d "$tap" 2>/dev/null
    done

    # Remove all bridges named br[0-9]+
    for br in $(brctl show | awk 'NR>1 {print $1}' | grep -E '^br[0-9]+$'); do
        echo -e "${YELLOW}Removing bridge: $br${NC}"
        sudo ip link set "$br" down 2>/dev/null
        sudo brctl delbr "$br" 2>/dev/null
    done
}

# Step 1: Remove systemd service
echo -e "${RED}→ ${WHITE}Step 1/4 ${YELLOW}Removing systemd service... ${PURPLE}[25%]${NC}"
sudo systemctl disable setup_network.service &> /dev/null
sudo rm -f "$service_path"
sudo systemctl daemon-reload
sudo systemctl reset-failed

# Step 2: Remove network setup script
echo -e "${RED}→ ${WHITE}Step 2/4 ${YELLOW}Removing network setup script... ${PURPLE}[50%]${NC}"
sudo rm -f "$script_path"

# Step 3: Remove networking setup
remove_setup_network

# Step 4: Remove installed packages
echo -e "${RED}→ ${WHITE}Step 4/4 ${YELLOW}Removing installed packages... ${PURPLE}[100%]${NC}"
sudo apt-get remove --purge -y uml-utilities bridge-utils &> /dev/null
sudo apt-get autoremove -y &> /dev/null
sudo apt-get autoclean &> /dev/null

echo -e "${GREEN}Uninstallation complete. System reverted to previous state.${NC}"
