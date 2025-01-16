#!/usr/bin/env bash

# Script version
VERSION="1.0.0"

# Configuration paths
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

# Helper functions
progress() { echo -ne "${ITALIC}${DIM}$1...${NC}"; }
success() { echo -e "\r${CHECK_MARK} $1"; }
error() { echo -e "\r${CROSS_MARK} ${RED}ERROR:${NC} $1"; if [ "$2" != "no_exit" ]; then exit 1; fi; }
warn() { echo -e "\r${YELLOW}WARNING:${NC} $1"; }

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
}

# Detect graphics hardware
detect_graphics() {
    print_section "🔍 Detecting Graphics Hardware"
    
    if systemd-detect-virt --vm &>/dev/null; then
        success "VM detected - using vmware drivers"
        echo "vmware"
        return
    fi
    
    gpu_info=$(lspci | grep -i vga)
    graphics="default"
    
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

# Create configuration
create_config() {
    print_section "📝 Creating Installation Configuration"
    
    local config_file="${CONFIG_DIR}/archinstall.json"
    local graphics=$(detect_graphics)
    
    progress "Creating configuration file"

    # Export variables for Python
    export INSTALL_GRAPHICS="$graphics"
    export INSTALL_ROOT_DISK="$ROOT_DISK"
    export INSTALL_HOSTNAME="$HOSTNAME"
    export INSTALL_USERNAME="$USERNAME"
    export INSTALL_PASSWORD="$USER_PASSWORD"
    export INSTALL_ROOT_PASSWORD="$ROOT_PASSWORD"
    export INSTALL_ROOT_PART="$ROOT_PART"
    export INSTALL_HOME_PART="$HOME_PART"
    export INSTALL_BOOT_PART="$BOOT_PART"
    export INSTALL_BOOT_CHOICE="$BOOT_CHOICE"
    export CONFIG_FILE="$config_file"

    python3 << "EndOfPython"
import json
import os

# Get variables from environment
graphics = os.environ['INSTALL_GRAPHICS']
root_disk = os.environ['INSTALL_ROOT_DISK']
hostname = os.environ['INSTALL_HOSTNAME']
username = os.environ['INSTALL_USERNAME']
password = os.environ['INSTALL_PASSWORD']
root_password = os.environ['INSTALL_ROOT_PASSWORD']
root_part = os.environ['INSTALL_ROOT_PART']
home_part = os.environ['INSTALL_HOME_PART']
boot_part = os.environ['INSTALL_BOOT_PART']
boot_choice = os.environ['INSTALL_BOOT_CHOICE']
config_file = os.environ['CONFIG_FILE']

config = {
    "additional-repositories": ["multilib"],
    "audio": "Pipewire",
    "bootloader": "Grub",
    "config_version": "2.7.1",
    "debug": True,
    "desktop-environment": None,
    "gfx_driver": graphics,
    "harddrives": [root_disk],
    "hostname": hostname,
    "kernels": ["linux"],
    "keyboard-language": "us",
    "mirror-region": {
        "Sweden": {
            "https://ftp.acc.umu.se/mirror/archlinux/\$repo/os/\$arch": True,
            "https://ftp.lysator.liu.se/pub/archlinux/\$repo/os/\$arch": True,
            "https://ftp.myrveln.se/pub/linux/archlinux/\$repo/os/\$arch": True
        }
    },
    "disk_config": {
        "device": root_disk,
        "partitions": [
            {
                "type": "primary",
                "boot": True,
                "filesystem": {
                    "format": "btrfs",
                    "mount_point": "/",
                    "options": ["compress=zstd", "space_cache=v2", "noatime", "subvol=@"]
                }
            }
        ],
        "hooks": ["base", "udev", "autodetect", "modconf", "block", "filesystems", "keyboard", "fsck"]
    },
    "mount_points": {
        "/": {"device": root_part, "type": "btrfs", "subvolume": "@"},
        "/home": {"device": home_part, "type": "btrfs"},
        "/.snapshots": {"device": root_part, "type": "btrfs", "subvolume": "@snapshots"},
        "/var/log": {"device": root_part, "type": "btrfs", "subvolume": "@log"},
        "/var/cache": {"device": root_part, "type": "btrfs", "subvolume": "@cache"}
    },
    "network": {
        "type": "nm"
    },
    "ntp": True,
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
    "root-password": root_password,
    "users": {
        username: {
            "sudo": True,
            "password": password,
            "shell": "/bin/bash"
        }
    },
    "custom-commands": [
        f"chown -R {username}:{username} /home/{username}",
        "systemctl enable NetworkManager",
        "systemctl enable sshd",
        "pacman -Sy --noconfirm archlinux-keyring"
    ]
}
    "additional-repositories": ["multilib"],
    "audio": "Pipewire",
    "bootloader": "Grub",
    "config_version": "2.5.1",
    "debug": True,
    "desktop-environment": None,
    "gfx_driver": graphics,
    "harddrives": [root_disk],
    "hostname": hostname,
    "kernels": ["linux"],
    "keyboard-language": "us",
    "mirror-region": {
        "Sweden": {
            "https://ftp.acc.umu.se/mirror/archlinux/\$repo/os/\$arch": True,
            "https://ftp.lysator.liu.se/pub/archlinux/\$repo/os/\$arch": True,
            "https://ftp.myrveln.se/pub/linux/archlinux/\$repo/os/\$arch": True
        }
    },
    "disk": {
        "device": root_disk,
        "type": "manual",
        "partitions": [
            {
                "mountpoint": "/",
                "type": "btrfs",
                "start": "0%",
                "size": "100%",
                "device": root_part,
                "wipe": False,
                "mount_options": ["compress=zstd", "space_cache=v2", "noatime", "subvol=@"]
            },
            {
                "mountpoint": "/home",
                "type": "btrfs",
                "device": home_part,
                "wipe": False,
                "mount_options": ["compress=zstd", "space_cache=v2", "noatime"]
            },
            {
                "mountpoint": "/.snapshots",
                "type": "btrfs",
                "device": root_part,
                "wipe": False,
                "mount_options": ["compress=zstd", "space_cache=v2", "noatime", "subvol=@snapshots"]
            },
            {
                "mountpoint": "/var/log",
                "type": "btrfs",
                "device": root_part,
                "wipe": False,
                "mount_options": ["compress=zstd", "space_cache=v2", "noatime", "subvol=@log"]
            },
            {
                "mountpoint": "/var/cache",
                "type": "btrfs",
                "device": root_part,
                "wipe": False,
                "mount_options": ["compress=zstd", "space_cache=v2", "noatime", "subvol=@cache"]
            }
        ]
    },
    "mount_points": {
        "/": {"device": root_part, "type": "btrfs", "subvolume": "@"},
        "/home": {"device": home_part, "type": "btrfs"},
        "/.snapshots": {"device": root_part, "type": "btrfs", "subvolume": "@snapshots"},
        "/var/log": {"device": root_part, "type": "btrfs", "subvolume": "@log"},
        "/var/cache": {"device": root_part, "type": "btrfs", "subvolume": "@cache"}
    },
    "network": {
        "type": "NetworkManager",
        "config_type": "nm"
    },
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
    "root-password": root_password,
    "superusers": {
        username: {
            "password": password
        }
    },
    "users": {
        username: {
            "sudo": True,
            "password": password,
            "shell": "/bin/bash"
        }
    },
    "custom-commands": [
        f"chown -R {username}:{username} /home/{username}",
        "systemctl enable NetworkManager",
        "systemctl enable sshd",
        "pacman -Sy --noconfirm archlinux-keyring"
    ]
}

if boot_choice == "yes":
    config["mount_points"]["/boot"] = {"device": boot_part, "type": "ext4"}

with open(config_file, "w") as f:
    json.dump(config, f, indent=4)

print(f"Configuration written to {config_file}")
EndOfPython

    if [ $? -ne 0 ]; then
        error "Failed to create configuration file"
    fi

    if [ ! -s "$config_file" ]; then
        error "Configuration file is empty or missing"
    fi
    
    success "Created installation configuration"
    
    echo -e "\n${CYAN}Configuration Preview (sensitive data hidden):${NC}"
    grep -v "password" "$config_file" || true
    echo
}

# Run installation
run_installation() {
    print_section "🚀 Running System Installation"
    
    progress "Starting archinstall"
    if ! archinstall \
        --config "${CONFIG_DIR}/archinstall.json" \
        --silent \
        --no-progress \
        --debug; then
        error "Installation failed"
        echo "Check /var/log/archinstall/install.log for details"
    fi
    success "Installation completed"
}

# Copy SSH keys
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

# Main function
main() {
    if [ "$EUID" -ne 0 ]; then
        error "Please run as root"
    fi

    load_configs
    create_config
    run_installation
    
    if [[ "$COPY_SSH" =~ ^(y|yes)$ ]]; then
        copy_ssh_to_user
    fi
}

# Run the script
trap 'error "An error occurred. Check the output above for details."' ERR
main "$@"
