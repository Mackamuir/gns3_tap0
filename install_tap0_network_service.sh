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

# Function to execute the network setup script
execute_setup_network() {
    echo -e "${YELLOW}→ ${WHITE}Executing network setup script... ${RED}[100%]${NC}"
    if ! sudo bash $script_path; then
        echo -e "${RED}Error executing network setup script. ${PURPLE}Continuing...${NC}"
    fi
}

# Function to check if a package is installed
is_package_installed() {
    dpkg -l "$1" &> /dev/null
    return $?
}

echo -e "${WHITE}Initiating Network Setup - ...${NC}"

# Step 1: Check for required packages
echo -e "${RED}→ ${WHITE}Step 1/4 ${YELLOW}Checking for required packages... ${RED}[25%]${NC}"
if ! is_package_installed "uml-utilities" || ! is_package_installed "bridge-utils"; then
    echo -e "${PURPLE}Installing required packages... ${PURPLE}[50%]${NC}"
    sudo apt update -y &> /dev/null
    sudo apt install -y uml-utilities bridge-utils &> /dev/null
else
    echo -e "${PURPLE}Required packages are already installed. ${RED}[50%]${NC}"
fi

# Step 2: Check if the network setup script already exists
echo -e "${RED}→ ${WHITE}Step 2/4 ${YELLOW}Setting up network script... ${RED}[75%]${NC}"
if [ ! -f $script_path ]; then
    echo -e "${PURPLE}Creating network setup script... ${RED}[100%]${NC}"

    # Create the script file with your network setup logic here
    cat > $script_path << 'EOF'
#!/bin/bash

# Counter for naming taps and bridges
count=1

# Loop through all interfaces except lo and eth0
for iface in $(ls /sys/class/net | grep -vE '^(lo|eth0|br|tap|docker0|virbr0)'); do
    tap="tap${count}"
    bridge="br${count}"

    echo "Setting up $bridge with $iface and $tap..."

    # Create tap
    sudo tunctl -t "$tap"
    sudo ifconfig "$tap" 0.0.0.0 promisc up

    # Set physical interface to promisc
    sudo ifconfig "$iface" 0.0.0.0 promisc up

    # Create bridge
    sudo brctl addbr "$bridge"
    sudo brctl addif "$bridge" "$tap"
    sudo brctl addif "$bridge" "$iface"

    # Bring up bridge
    sudo ifconfig "$bridge" up

    ((count++))
done
EOF

    chmod +x $script_path
else
    echo -e "${YELLOW}Network setup script already exists. ${RED}[100%]${NC}"
fi

# Step 3: Check if the systemd service file already exists
echo -e "${RED}→ ${WHITE}Step 3/4 ${YELLOW}Setting up systemd service... ${RED}[100%]${NC}"
if [ ! -f $service_path ]; then
    echo -e "${PURPLE}Creating systemd service file... ${RED}[100%]${NC}"
    cat > $service_path << 'EOF'
[Unit]
Description=Network Setup Script

[Service]
Type=oneshot
ExecStart=/usr/local/bin/setup_network.sh

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd and enable the service
    systemctl daemon-reload
    systemctl enable setup_network.service
else
    echo -e "${PURPLE}Systemd service file already exists. ${RED}[100%]${NC}"
fi

# Step 4: Execute the network setup script
echo -e "${RED}→ ${WHITE}Step 4/4 ${YELLOW}Executing network setup script... ${RED}[100%]${NC}"
execute_setup_network
