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

print_section() {
    echo
    echo -e "${CYAN}${BOLD}$1${NC}"
    echo -e "${DIM}$(printf '%.s─' $(seq 1 $(tput cols)))${NC}"
}

# Function to detect graphics hardware
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

# Function to create archinstall configuration
create_config() {
    print_section "📝 Creating Installation Configuration"
    
    config_file="${CONFIG_DIR}/archinstall.json"
    graphics=$(detect_graphics)
    
    progress "Creating configuration file"

    # Export all necessary variables for Python
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

    # Create Python script as a heredoc without indentation
    cat << 'PYTHON_EOF' | python3
import json
import os

# Get all our installation variables from environment
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

# Create the configuration dictionary
config = {
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
            "https://ftp.acc.umu.se/mirror/archlinux/$repo/os/$arch": True,
            "https://ftp.lysator.liu.se/pub/archlinux/$repo/os/$arch": True,
            "https://ftp.myrveln.se/pub/linux/archlinux/$repo/os/$arch": True
        }
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

# Add boot partition if needed
if boot_choice == "yes":
    config["mount_points"]["/boot"] = {"device": boot_part, "type": "ext4"}

# Ensure the directory exists
os.makedirs(os.path.dirname(config_file), exist_ok=True)

# Write the configuration to file
with open(config_file, "w") as f:
    json.dump(config, f, indent=4)

print(f"Configuration written to {config_file}")
PYTHON_EOF

    if [ $? -ne 0 ]; then
        error "Failed to create configuration file"
    fi

    if [ ! -s "$config_file" ]; then
        error "Configuration file is empty or missing"
    fi
    
    success "Created installation configuration"
    
    # Show preview of configuration (excluding sensitive data)
    echo -e "\n${CYAN}Configuration Preview (sensitive data hidden):${NC}"
    grep -v "password" "$config_file" || true
    echo
}
create_config() {
    print_section "📝 Creating Installation Configuration"
    
    # These variables need to be inside the function
    config_file="${CONFIG_DIR}/archinstall.json"
    graphics=$(detect_graphics)
    
    # Export additional configuration for disks
    export INSTALL_CONFIG_FILE="$config_file"
    
    progress "Creating configuration file"

    # Create the configuration using Python
    python3 - << 'EOF'
import json
import os

# Get the configuration file path from environment
config_file = os.environ['INSTALL_CONFIG_FILE']

# Get all our installation variables from environment
graphics = os.environ['INSTALL_GRAPHICS']
root_disk = os.environ['INSTALL_ROOT_DISK']
hostname = os.environ['INSTALL_HOSTNAME']
username = os.environ['INSTALL_USERNAME']
password = os.environ['INSTALL_PASSWORD']
root_password = os.environ['ROOT_PASSWORD']
root_part = os.environ['INSTALL_ROOT_PART']
home_part = os.environ['INSTALL_HOME_PART']
boot_part = os.environ['INSTALL_BOOT_PART']
boot_choice = os.environ['INSTALL_BOOT_CHOICE']

# Create a disk layout configuration
disk_layout = {
    "config_type": "manual",
    "device": root_disk,
    "partitions": [
        {
            "mountpoint": "/",
            "filesystem": "btrfs",
            "device": root_part,
            "options": ["compress=zstd", "space_cache=v2", "noatime", "subvol=@"]
        },
        {
            "mountpoint": "/home",
            "filesystem": "btrfs",
            "device": home_part,
            "options": ["compress=zstd", "space_cache=v2", "noatime"]
        }
    ]
}
    python3 - << 'EOF'
import json
import os

# Get the configuration file path from environment
config_file = os.environ['CONFIG_FILE']

# Get installation variables from environment
graphics = os.environ['INSTALL_GRAPHICS']
root_disk = os.environ['INSTALL_ROOT_DISK']
hostname = os.environ['INSTALL_HOSTNAME']
username = os.environ['INSTALL_USERNAME']
password = os.environ['INSTALL_PASSWORD']
root_part = os.environ['INSTALL_ROOT_PART']
home_part = os.environ['INSTALL_HOME_PART']
boot_part = os.environ['INSTALL_BOOT_PART']
boot_choice = os.environ['INSTALL_BOOT_CHOICE']

# Create the configuration dictionary
config = {
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
            "https://ftp.acc.umu.se/mirror/archlinux/$repo/os/$arch": True,
            "https://ftp.lysator.liu.se/pub/archlinux/$repo/os/$arch": True,
            "https://ftp.myrveln.se/pub/linux/archlinux/$repo/os/$arch": True
        }
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
            "https://ftp.acc.umu.se/mirror/archlinux/$repo/os/$arch": True,
            "https://ftp.lysator.liu.se/pub/archlinux/$repo/os/$arch": True,
            "https://ftp.myrveln.se/pub/linux/archlinux/$repo/os/$arch": True
        }
    },
    "mount_points": {
        "/": {"device": root_part, "type": "btrfs", "subvolume": "@"},
        "/home": {"device": home_part, "type": "btrfs"},
        "/.snapshots": {"device": root_part, "type": "btrfs", "subvolume": "@snapshots"},
        "/var/log": {"device": root_part, "type": "btrfs", "subvolume": "@log"},
        "/var/cache": {"device": root_part, "type": "btrfs", "subvolume": "@cache"}
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
    # Add the root password configuration
    "root-password": os.environ['ROOT_PASSWORD'],
    # Update the user configuration format
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
    "custom-commands": [
        f"chown -R {username}:{username} /home/{username}",
        "systemctl enable NetworkManager",
        "systemctl enable sshd",
        "pacman -Sy --noconfirm archlinux-keyring"
    ]
}

# Add boot partition if needed
if boot_choice == "yes":
    config["mount_points"]["/boot"] = {"device": boot_part, "type": "ext4"}

# Ensure the directory exists
os.makedirs(os.path.dirname(config_file), exist_ok=True)

# Write the configuration to file
with open(config_file, "w") as f:
    json.dump(config, f, indent=4)

print(f"Configuration written to {config_file}")
EOF

    if [ $? -ne 0 ]; then
        error "Failed to create configuration file"
    fi

    if [ ! -s "$config_file" ]; then
        error "Configuration file is empty or missing"
    fi
    
    success "Created installation configuration"
    
    # Show preview of configuration (excluding sensitive data)
    echo -e "\n${CYAN}Configuration Preview (sensitive data hidden):${NC}"
    grep -v "password" "$config_file" || true
    echo
}

# Function to run the actual installation
run_installation() {
    print_section "🚀 Running System Installation"
    
    progress "Starting archinstall"
    if ! archinstall \
        --config "${CONFIG_DIR}/archinstall.json" \
        --silent \
        --disk-layout manual \
        --disk-encryption disable; then
        error "Installation failed"
    fi
    success "Installation completed"
}

# Function to copy SSH keys
copy_ssh_to_user() {
    print_section "🔑 Setting up User SSH Keys"
    
    if [ -d "/root/.ssh" ]; then
        user_home="/mnt/home/$USERNAME"
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

# Run the script with error handling
trap 'error "An error occurred. Check the output above for details."' ERR
main "$@"
