#!/bin/bash

# Color codes for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_message() {
    echo -e "${YELLOW}###########################${NC}"
    echo -e "${GREEN}# $1 ${NC}"
    echo -e "${YELLOW}###########################${NC}"
    sleep 1
}

# Function to install a package if it's not already installed
install_package() {
    if ! xbps-query -l | grep -q "^ii $1"; then
        echo "Installing $1..."
        sudo xbps-install -y "$1"
    else
        echo "$1 is already installed."
    fi
}

# Function to create directories
create_directories() {
    mkdir -p "$HOME"/.config "$HOME"/scripts "$HOME"/downloads "$HOME"/software
}
