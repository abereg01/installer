#!/usr/bin/env bash

# Script version and configuration paths
VERSION="1.0.0"
CONFIG_DIR="/root"
INSTALL_CONFIG="${CONFIG_DIR}/install_config"
DISK_CONFIG="${CONFIG_DIR}/disk_config.txt"

# Colors and styling
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
ITALIC='\033[3m'
NC='\033[0m'

# Unicode symbols
CHECK_MARK="\033[0;32m✓\033[0m"
CROSS_MARK="\033[0;31m✗\033[0m"
ARROW="→"

# Helper functions for output and progress indication
progress() {
    echo -ne "${ITALIC}${DIM}$1...${NC}"
}

success() {
    echo -e "\r${CHECK_MARK} $1"
}

error() {
    echo -e "\r${CROSS_MARK} ${RED}ERROR:${NC} $1"
    if [ "$2" != "no_exit" ]; then
        exit 1
    fi
}

warn() {
    echo -e "\r${YELLOW}WARNING:${NC} $1"
}

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

    # Verify required variables
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
        local graphics="vmware"
        success "Detected VM environment"
        echo "$graphics"
        return
    fi
    
    local gpu_info=$(lspci | grep -i vga)
    progress "Detected GPU: $gpu_info"
    local graphics=""
    
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
        graphics="default"
        warn "Unknown GPU, using default drivers"
    fi
    
    echo "$graphics"
}

# Function to validate user configuration
validate_user_config() {
    print_section "✓ Validating User Configuration"
    
    if [ -z "$USERNAME" ] || [ -z "$USER_PASSWORD" ]; then
        error "Username or password not set in configuration"
    fi
    
    if ! [[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        error "Invalid username format: $USERNAME"
    fi
    
    success "User configuration validated"
}

# Function to create archinstall configuration
create_config() {
    print_section "📝 Creating Installation Configuration"
    
    validate_user_config
    local graphics=$(detect_graphics)
    local config_file="${CONFIG_DIR}/archinstall.json"
    
    progress "Generating configuration file"

    # Create base configuration
    cat > "$config_file" << 'EOF'
{
    "additional-repositories": ["multilib"],
    "audio": "pipewire",
    "bootloader": "grub-install",
    "config_version": "2.5.1",
    "debug": true,
    "desktop-environment": null,
EOF

    # Add dynamic values
    echo "    \"gfx_driver\": \"${graphics}\"," >> "$config_file"
    echo "    \"harddrives\": [\"${ROOT_DISK}\"]," >> "$config_file"
    echo "    \"hostname\": \"${HOSTNAME}\"," >> "$config_file"

    # Add static configuration
    cat >> "$config_file" << 'EOF'
    "kernels": ["linux"],
    "keyboard-language": "us",
    "mirror-region": {
        "Sweden": {
            "https://ftp.acc.umu.se/mirror/archlinux/$repo/os/$arch": true,
            "https://ftp.lysator.liu.se/pub/archlinux/$repo/os/$arch": true,
            "https://ftp.myrveln.se/pub/linux/archlinux/$repo/os/$arch": true
        }
    },
EOF

    # Add mount points
    echo "    \"mount_points\": {" >> "$config_file"
    
    if [ "$BOOT_CHOICE" = "yes" ]; then
        echo "        \"/boot\": {\"device\": \"${BOOT_PART}\", \"type\": \"ext4\"}," >> "$config_file"
    fi

    # Add BTRFS mount points
    cat >> "$config_file" << EOF
        "/": {"device": "${ROOT_PART}", "type": "btrfs", "subvolume": "@"},
        "/home": {"device": "${HOME_PART}", "type": "btrfs"},
        "/.snapshots": {"device": "${ROOT_PART}", "type": "btrfs", "subvolume": "@snapshots"},
        "/var/log": {"device": "${ROOT_PART}", "type": "btrfs", "subvolume": "@log"},
        "/var/cache": {"device": "${ROOT_PART}", "type": "btrfs", "subvolume": "@cache"}
    },
EOF

    # Add remaining configuration
    cat >> "$config_file" << EOF
    "nic": {"type": "NetworkManager"},
    "ntp": true,
    "profile": null,
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
    "bootloader": "grub-install",
    "swap": true,
    "users": {
        "${USERNAME}": {
            "sudo": true,
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
EOF

    # Verify JSON syntax
    progress "Verifying JSON syntax"
    if command -v python &>/dev/null; then
        if ! python -m json.tool "$config_file" >/dev/null 2>&1; then
            error "Generated JSON is invalid. Please check the configuration."
        fi
    fi

    success "Created and verified installation configuration"
    
    # Show configuration preview
    echo -e "\n${CYAN}Configuration Preview (sensitive data hidden):${NC}"
    grep -v "password" "$config_file" || true
    echo
}

# Function to run the installation
run_installation() {
    print_section "🚀 Running System Installation"
    
    progress "Starting archinstall"
    if ! archinstall --config "${CONFIG_DIR}/archinstall.json" --disk_layouts none; then
        error "Installation failed"
    fi
    success "Installation completed successfully"
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
        warn "No SSH keys found in root. Keys will need to be set up manually."
    fi
}

# Function to display success message
print_success() {
    echo
    echo -e "${GREEN}${BOLD}Installation Complete!${NC}"
    echo "You can now:"
    echo "1. Review any warnings or messages above"
    echo "2. Restart your system to boot into the new installation"
    echo "3. Log in with your username: $USERNAME"
    echo
    echo -e "${YELLOW}Note:${NC} Remember to remove the installation media before rebooting."
    echo
}

# Main function
main() {
    verify_root
    load_configs
    create_config
    run_installation
    
    if [[ "$COPY_SSH" =~ ^(y|yes)$ ]]; then
        copy_ssh_to_user
    fi
    
    print_success
}

# Run the script with error handling
trap 'error "An error occurred. Check the output above for details."' ERR
main "$@"
