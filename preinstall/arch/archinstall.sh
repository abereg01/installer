#!/usr/bin/env bash

# Script version
VERSION="1.0.0"

# Import styling from main script if exists
if [ -f "../../../install.sh" ]; then
    source "../../../install.sh"
else
    # Fallback styling
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    NC='\033[0m'
    CHECK_MARK="\033[0;32m✓\033[0m"
    CROSS_MARK="\033[0;31m✗\033[0m"
    ARROW="→"
fi

# Load user configuration
if [ ! -f "/root/install_config" ]; then
    error "Installation configuration not found"
fi
source /root/install_config

# Load disk configuration
if [ ! -f "/root/disk_config.txt" ]; then
    error "Disk configuration not found"
fi
source /root/disk_config.txt

# Detect graphics card
detect_graphics() {
    print_section "🔍 Detecting Graphics Hardware"
    
    # VM Detection
    if systemd-detect-virt --vm &>/dev/null; then
        success "Running in VM, using VMware/VirtualBox drivers"
        echo "VMware / VirtualBox (open-source)"
        return
    fi
    
    # Hardware detection
    local gpu_info=$(lspci | grep -i vga)
    progress "Detected GPU: $gpu_info"
    
    if [[ $gpu_info =~ "NVIDIA" ]]; then
        success "NVIDIA GPU detected, using proprietary drivers"
        echo "NVIDIA (proprietary)"
    elif [[ $gpu_info =~ "AMD" ]] || [[ $gpu_info =~ "ATI" ]]; then
        success "AMD GPU detected, using open-source drivers"
        echo "AMD / ATI (open-source)"
    elif [[ $gpu_info =~ "Intel" ]]; then
        success "Intel GPU detected, using open-source drivers"
        echo "Intel (open-source)"
    else
        warn "Unknown GPU, using default drivers"
        echo "Default (open-source)"
    fi
}

# Create archinstall configuration
create_config() {
    print_section "📝 Creating Installation Configuration"
    
    # Detect graphics
    local graphics=$(detect_graphics)

    # Create archinstall config
    progress "Generating configuration file"
    cat > /root/archinstall.json << EOF
{
    "additional-repositories": ["multilib"],
    "audio": "pipewire",
    "bootloader": "grub",
    "config_version": "2.5.1",
    "debug": false,
    "desktop-environment": null,
    "gfx_driver": "$graphics",
    "harddrives": [],
    "hostname": "$HOSTNAME",
    "kernels": ["linux"],
    "keyboard-languages": ["us", "se"],
    "keyboard-layout": "us",
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

    # Add mount points from disk configuration
    if [[ "$BOOT_CHOICE" == "yes" ]]; then
        cat >> /root/archinstall.json << EOF
        "/boot": {"device": "$BOOT_PART", "type": "fat32"},
EOF
    fi

    cat >> /root/archinstall.json << EOF
        "/": {"device": "$ROOT_PART", "type": "btrfs", "subvolume": "@"},
        "/home": {"device": "$HOME_PART", "type": "btrfs"},
        "/.snapshots": {"device": "$ROOT_PART", "type": "btrfs", "subvolume": "@snapshots"},
        "/var/log": {"device": "$ROOT_PART", "type": "btrfs", "subvolume": "@log"},
        "/var/cache": {"device": "$ROOT_PART", "type": "btrfs", "subvolume": "@cache"}
    },
    "nic": {"NetworkManager": true},
    "ntp": true,
    "profile": {"xorg": true},
    "root-password": "$ROOT_PASSWORD",
    "swap": true,
    "sys-encoding": "utf-8",
    "sys-language": "en_US",
    "timezone": "Europe/Stockholm",
    "users": {
        "$USERNAME": {
            "sudo": true,
            "password": "$USER_PASSWORD"
        }
    },
    "packages": ["git"]
}
EOF

    success "Created installation configuration"
}

# Run archinstall
run_installation() {
    print_section "🚀 Running Arch Installation"
    
    progress "Starting installation"
    if ! archinstall --config /root/archinstall.json; then
        error "Installation failed"
    fi
    success "Installation completed"
}

# Copy SSH keys to new user's home
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

# Main function
main() {
    print_header
    create_config
    run_installation
    
    if [[ "$COPY_SSH" =~ ^(y|yes)$ ]]; then
        copy_ssh_to_user
    fi
}

# Run the script with error handling
trap 'error "An error occurred. Check the output above for details."' ERR
main
