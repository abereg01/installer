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

# Detect graphics card
detect_graphics() {
    print_section "🔍 Detecting Graphics Hardware"
    
    local gpu_info=$(lspci | grep -i vga)
    
    if [[ $gpu_info =~ "NVIDIA" ]]; then
        echo "nvidia"
    elif [[ $gpu_info =~ "AMD" ]] || [[ $gpu_info =~ "ATI" ]]; then
        echo "amd"
    elif [[ $gpu_info =~ "Intel" ]]; then
        echo "intel"
    else
        echo "unknown"
    fi
}

# Create archinstall configuration
create_config() {
    print_section "📝 Creating Installation Configuration"
    
    # VM Detection
    progress "Checking if running in VM"
    if systemd-detect-virt --vm &>/dev/null; then
        local is_vm="true"
        success "Running in VM"
    else
        local is_vm="false"
        success "Running on hardware"
    fi

    # Graphics Configuration
    if [ "$is_vm" = "true" ]; then
        local graphics="VMware / VirtualBox (open-source)"
    else
        local gpu=$(detect_graphics)
        case "$gpu" in
            "nvidia")
                local graphics="NVIDIA (proprietary)"
                ;;
            "amd")
                local graphics="AMD / ATI (open-source)"
                ;;
            "intel")
                local graphics="Intel (open-source)"
                ;;
            *)
                local graphics="Default (open-source)"
                ;;
        esac
    fi

    # Get user input
    echo
    read -p "$(echo -e "${BOLD}${BLUE}$ARROW${NC} Enter hostname: ")" hostname
    hostname=${hostname:-arch}

    while true; do
        read -s -p "$(echo -e "${BOLD}${BLUE}$ARROW${NC} Enter root password: ")" root_password
        echo
        read -s -p "$(echo -e "${BOLD}${BLUE}$ARROW${NC} Confirm root password: ")" root_password2
        echo
        if [ "$root_password" = "$root_password2" ]; then
            break
        fi
        warn "Passwords don't match. Please try again."
    done

    read -p "$(echo -e "${BOLD}${BLUE}$ARROW${NC} Enter username: ")" username
    while true; do
        read -s -p "$(echo -e "${BOLD}${BLUE}$ARROW${NC} Enter password for $username: ")" user_password
        echo
        read -s -p "$(echo -e "${BOLD}${BLUE}$ARROW${NC} Confirm password: ")" user_password2
        echo
        if [ "$user_password" = "$user_password2" ]; then
            break
        fi
        warn "Passwords don't match. Please try again."
    done

    # Load disk configuration
    if [ ! -f "/root/disk_config.txt" ]; then
        error "Disk configuration not found"
    fi
    source /root/disk_config.txt

    # Create archinstall config
    cat > /root/archinstall.json << EOF
{
    "additional-repositories": ["multilib"],
    "audio": "pulseaudio",
    "bootloader": "grub",
    "config_version": "2.5.1",
    "debug": false,
    "desktop-environment": null,
    "gfx_driver": "$graphics",
    "harddrives": [],
    "hostname": "$hostname",
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
    "root-password": "$root_password",
    "swap": true,
    "sys-encoding": "utf-8",
    "sys-language": "en_US",
    "timezone": "Europe/Stockholm",
    "users": {
        "$username": {
            "sudo": true,
            "password": "$user_password"
        }
    }
}
EOF

    success "Created installation configuration"
}

# Run archinstall
run_installation() {
    print_section "🚀 Running Arch Installation"
    
    progress "Starting installation"
    archinstall --config /root/archinstall.json || error "Installation failed"
    success "Installation completed"
}

# Main function
main() {
    print_header
    create_config
    run_installation
}

# Run the script
main
