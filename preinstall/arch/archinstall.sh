#!/usr/bin/env bash

# Script version
VERSION="1.0.0"

# Default path for configs
CONFIG_DIR="/root"
INSTALL_CONFIG="${CONFIG_DIR}/install_config"
DISK_CONFIG="${CONFIG_DIR}/disk_config.txt"

# Source styling directly instead of trying to locate install.sh
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'
CHECK_MARK="\033[0;32m✓\033[0m"
CROSS_MARK="\033[0;31m✗\033[0m"
ARROW="→"

# Helper functions
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

# Load configurations
load_configs() {
    print_section "📋 Loading Configurations"
    
    if [ ! -f "$INSTALL_CONFIG" ]; then
        error "Installation configuration not found at $INSTALL_CONFIG"
    fi
    source "$INSTALL_CONFIG"
    success "Loaded installation config"

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
}

# Detect graphics hardware
detect_graphics() {
    print_section "🔍 Detecting Graphics Hardware"
    
    # VM Detection
    if systemd-detect-virt --vm &>/dev/null; then
        local graphics="vmware"
        success "Detected VM environment, using vmware drivers"
        echo "$graphics"
        return
    fi
    
    # Hardware detection
    local gpu_info=$(lspci | grep -i vga)
    local graphics=""
    
    if [[ $gpu_info =~ "NVIDIA" ]]; then
        graphics="nvidia"
        success "Detected NVIDIA GPU"
    elif [[ $gpu_info =~ "AMD" ]] || [[ $gpu_info =~ "ATI" ]]; then
        graphics="amd"
        success "Detected AMD GPU"
    elif [[ $gpu_info =~ "Intel" ]]; then
        graphics="intel"
        success "Detected Intel GPU"
    else
        graphics="default"
        warn "Unknown GPU, using default drivers"
    fi
    
    echo "$graphics"
}

# Create archinstall configuration
create_config() {
    print_section "📝 Creating Archinstall Configuration"
    
    # Detect graphics
    local graphics=$(detect_graphics)
    progress "Creating configuration file"
    
    cat > "${CONFIG_DIR}/archinstall.json" << EOF
{
    "additional-repositories": ["multilib"],
    "audio": "pipewire",
    "bootloader": "grub-install",
    "config_version": "2.5.1",
    "debug": false,
    "desktop-environment": null,
    "gfx_driver": "${graphics}",
    "harddrives": ["${ROOT_DISK}"],
    "hostname": "${HOSTNAME}",
    "kernels": ["linux"],
    "keyboard-language": "us",
    "mirror-region": {
        "Sweden": {
            "http://ftp.acc.umu.se/mirror/archlinux/\$repo/os/\$arch": true,
            "http://ftp.lysator.liu.se/pub/archlinux/\$repo/os/\$arch": true,
            "http://ftp.myrveln.se/pub/linux/archlinux/\$repo/os/\$arch": true,
            "https://ftp.acc.umu.se/mirror/archlinux/\$repo/os/\$arch": true,
            "https://ftp.lysator.liu.se/pub/archlinux/\$repo/os/\$arch": true,
            "https://ftp.myrveln.se/pub/linux/archlinux/\$repo/os/\$arch": true
        }
    },
    "mount_points": {
EOF

    # Add mount points based on disk configuration
    if [ "$BOOT_CHOICE" = "yes" ]; then
        cat >> "${CONFIG_DIR}/archinstall.json" << EOF
        "/boot": {"device": "${BOOT_PART}", "type": "ext4"},
EOF
    fi

    cat >> "${CONFIG_DIR}/archinstall.json" << EOF
        "/": {"device": "${ROOT_PART}", "type": "btrfs", "subvolume": "@"},
        "/home": {"device": "${HOME_PART}", "type": "btrfs"},
        "/.snapshots": {"device": "${ROOT_PART}", "type": "btrfs", "subvolume": "@snapshots"},
        "/var/log": {"device": "${ROOT_PART}", "type": "btrfs", "subvolume": "@log"},
        "/var/cache": {"device": "${ROOT_PART}", "type": "btrfs", "subvolume": "@cache"}
    },
    "nic": {"type": "NetworkManager"},
    "ntp": true,
    "profile": null,
    "services": ["NetworkManager"],
    "sys-encoding": "utf-8",
    "sys-language": "en_US",
    "timezone": "UTC",
    "bootloader": "grub-install",
    "swap": true,
    "users": {
        "${USERNAME}": {
            "sudo": true,
            "password": "${USER_PASSWORD}"
        }
    }
}
EOF

    success "Created archinstall configuration"
}

# Run archinstall
run_installation() {
    print_section "🚀 Running Arch Installation"
    
    progress "Starting archinstall"
    if ! archinstall --config "${CONFIG_DIR}/archinstall.json" --disk_layouts none; then
        error "Installation failed"
    fi
    success "Installation completed successfully"
}

# Copy SSH keys if requested
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

# Main execution
main() {
    # Load configurations
    load_configs
    
    # Create archinstall config
    create_config
    
    # Run installation
    run_installation
    
    # Copy SSH keys if requested
    if [[ "$COPY_SSH" =~ ^(y|yes)$ ]]; then
        copy_ssh_to_user
    fi
}

# Run the script with error handling
trap 'error "An error occurred. Check the output above for details."' ERR
main "$@"
