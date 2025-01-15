#!/usr/bin/env bash

# Script version and configuration paths
VERSION="1.0.0"
CONFIG_DIR="/root"
INSTALL_CONFIG="${CONFIG_DIR}/install_config"
DISK_CONFIG="${CONFIG_DIR}/disk_config.txt"

# Colors and styling for better user feedback
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
ITALIC='\033[3m'
NC='\033[0m'

# Unicode symbols for status indicators
CHECK_MARK="\033[0;32m✓\033[0m"
CROSS_MARK="\033[0;31m✗\033[0m"
ARROW="→"

# Helper functions for consistent output formatting
progress() { echo -ne "${ITALIC}${DIM}$1...${NC}"; }
success() { echo -e "\r${CHECK_MARK} $1"; }
error() { echo -e "\r${CROSS_MARK} ${RED}ERROR:${NC} $1"; if [ "$2" != "no_exit" ]; then exit 1; fi; }
warn() { echo -e "\r${YELLOW}WARNING:${NC} $1"; }

# Function to print section headers
print_section() {
    echo
    echo -e "${CYAN}${BOLD}$1${NC}"
    echo -e "${DIM}$(printf '%.s─' $(seq 1 $(tput cols)))${NC}"
}

# Function to verify root privileges
verify_root() {
    if [ "$EUID" -ne 0 ]; then
        error "Please run as root"
    fi
}

# Function to load and validate configurations
load_configs() {
    print_section "📋 Loading Configurations"
    
    # Check and load installation config
    if [ ! -f "$INSTALL_CONFIG" ]; then
        error "Installation configuration not found at $INSTALL_CONFIG"
    fi
    source "$INSTALL_CONFIG"
    success "Loaded installation config"

    # Check and load disk config
    if [ ! -f "$DISK_CONFIG" ]; then
        error "Disk configuration not found at $DISK_CONFIG"
    fi
    source "$DISK_CONFIG"
    success "Loaded disk config"

    # Verify all required variables are set
    local required_vars=(
        "USERNAME" "ROOT_PASSWORD" "USER_PASSWORD" "HOSTNAME"
        "ROOT_PART" "HOME_PART" "BOOT_CHOICE"
    )
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            error "Required variable $var is not set"
        fi
    done
    
    if [ "$BOOT_CHOICE" = "yes" ] && [ -z "$BOOT_PART" ]; then
        error "BOOT_PART must be set when BOOT_CHOICE is yes"
    fi

    success "Configuration validation complete"
}

# Function to detect graphics hardware
detect_graphics() {
    print_section "🔍 Detecting Graphics Hardware"
    
    if systemd-detect-virt --vm &>/dev/null; then
        success "VM detected - using vmware drivers"
        echo "vmware"
        return
    fi
    
    local gpu_info=$(lspci | grep -i vga)
    local graphics="default"
    
    if [[ $gpu_info =~ "NVIDIA" ]]; then
        graphics="nvidia"
        success "NVIDIA GPU detected"
    elif [[ $gpu_info =~ "AMD" ]] || [[ $gpu_info =~ "ATI" ]]; then
        graphics="amd"
        success "AMD GPU detected"
    elif [[ $gpu_info =~ "Intel" ]]; then
        graphics="intel"
        success "Intel GPU detected"
    else
        warn "Unknown GPU - using default drivers"
    fi
    
    echo "$graphics"
}

# Function to create and validate archinstall configuration
create_config() {
    print_section "📝 Creating Installation Configuration"
    
    local config_file="${CONFIG_DIR}/archinstall.json"
    local graphics=$(detect_graphics)
    
    progress "Creating configuration file"

    # Use Python to generate valid JSON configuration
    python3 - << EOF
import json

# Build the configuration dictionary
config = {
    "additional-repositories": ["multilib"],
    "audio": "pipewire",
    "bootloader": "grub-install",
    "config_version": "2.5.1",
    "debug": True,
    "desktop-environment": None,
    "gfx_driver": "${graphics}",
    "harddrives": ["${ROOT_DISK}"],
    "hostname": "${HOSTNAME}",
    "kernels": ["linux"],
    "keyboard-language": "us",
    "mirror-region": {
        "Sweden": {
            "https://ftp.acc.umu.se/mirror/archlinux/\$repo/os/\$arch": True,
            "https://ftp.lysator.liu.se/pub/archlinux/\$repo/os/\$arch": True,
            "https://ftp.myrveln.se/pub/linux/archlinux/\$repo/os/\$arch": True
        }
    },
    "mount_points": {
        "/": {"device": "${ROOT_PART}", "type": "btrfs", "subvolume": "@"},
        "/home": {"device": "${HOME_PART}", "type": "btrfs"},
        "/.snapshots": {"device": "${ROOT_PART}", "type": "btrfs", "subvolume": "@snapshots"},
        "/var/log": {"device": "${ROOT_PART}", "type": "btrfs", "subvolume": "@log"},
        "/var/cache": {"device": "${ROOT_PART}", "type": "btrfs", "subvolume": "@cache"}
    },
    "nic": {"type": "NetworkManager"},
    "ntp": True,
    "profile": None,
    "packages": [
        "git",
        "vim",
        "sudo",
        "networkmanager",
        "base-devel",
        "linux-headers"
    ],
    "services": ["NetworkManager", "sshd"],
    "sys-encoding": "utf-8",
    "sys-language": "en_US",
    "timezone": "Europe/Stockholm",
    "swap": True,
    "users": {
        "${USERNAME}": {
            "sudo": True,
            "password": "${USER_PASSWORD}",
            "shell": "/bin/bash"
        }
    },
    "custom-commands": [
        "chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}",
        "systemctl enable NetworkManager",
        "systemctl enable sshd",
        "pacman -Sy --noconfirm archlinux-keyring"
    ]
}

# Add boot partition if specified
if "${BOOT_CHOICE}" == "yes":
    config["mount_points"]["/boot"] = {"device": "${BOOT_PART}", "type": "ext4"}

# Write the configuration to file with proper formatting
with open("${config_file}", "w") as f:
    json.dump(config, f, indent=4)

# Validate the JSON
with open("${config_file}", "r") as f:
    json.load(f)

print("Configuration successfully created and validated")
EOF

    if [ $? -ne 0 ]; then
        error "Failed to create configuration file"
    fi
    
    success "Created and verified installation configuration"
    
    # Display configuration preview (excluding sensitive data)
    echo -e "\n${CYAN}Configuration Preview (sensitive data hidden):${NC}"
    grep -v "password" "$config_file" || true
    echo

    # Verify the configuration file exists and has content
    if [ ! -s "$config_file" ]; then
        error "Configuration file is empty or missing"
    fi
}

# Function to run the actual installation
run_installation() {
    print_section "🚀 Running System Installation"
    
    progress "Starting archinstall"
    if ! archinstall --config "${CONFIG_DIR}/archinstall.json" --disk_layouts none; then
        error "Installation failed"
    fi
    success "Installation completed"
}

# Function to copy SSH keys to the new user
copy_ssh_to_user() {
    print_section "🔑 Setting up User SSH Keys"
    
    if [ -d "/root/.ssh" ]; then
        local user_home="/mnt/home/$USERNAME"
        progress "Copying SSH keys to $USERNAME"
        mkdir -p "$user_home/.ssh"
        cp -r /root/.ssh/* "$user_home/.ssh/"
        arch-chroot /mnt chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.ssh"
        chmod 700 "$user_home/.ssh"
        chmod 600 "$user_home/.ssh/"*
        success "SSH keys configured for $USERNAME"
    else
        warn "No SSH keys found in root"
    fi
}

# Main execution function
main() {
    verify_root
    load_configs
    create_config
    run_installation
    
    if [[ "$COPY_SSH" =~ ^(y|yes)$ ]]; then
        copy_ssh_to_user
    fi
}

# Run the script with error handling
trap 'error "An error occurred. Check the output above for details."' ERR
main "$@"
