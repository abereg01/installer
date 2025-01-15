#!/usr/bin/env bash

# Script version and directory setup
VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors and styling
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
ITALIC='\033[3m'
NC='\033[0m'

# Unicode symbols
CHECK_MARK="\033[0;32m✓\033[0m"
CROSS_MARK="\033[0;31m✗\033[0m"
ARROW="→"
GEAR="⚙"
KEY="🔑"
FOLDER="📁"

# Required tools
REQUIRED_TOOLS=(
    "git"
    "curl"
    "sudo"
    "rsync"
)

# Helper functions
print_centered() {
    local text="$1"
    local width=$((($TERM_WIDTH - ${#text}) / 2))
    printf "%${width}s%s%${width}s\n" "" "$text" ""
}

print_header() {
    clear
    echo -e "${BOLD}${BLUE}"
    print_centered "╔════════════════════════════════════════╗"
    print_centered "║     System Configuration Installer     ║"
    print_centered "║              v${VERSION}                   ║"
    print_centered "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo
}

print_section() {
    echo
    echo -e "${CYAN}${BOLD}$1${NC}"
    echo -e "${DIM}$(printf '%.s─' $(seq 1 $(tput cols)))${NC}"
}

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

# Function to check prerequisites
check_prerequisites() {
    print_section "🔍 Checking Prerequisites"
    
    local missing_tools=()
    for tool in "${REQUIRED_TOOLS[@]}"; do
        progress "Checking for $tool"
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
            error "$tool not found" "no_exit"
        else
            success "Found $tool"
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        error "Missing required tools: ${missing_tools[*]}"
    fi
    success "All prerequisites met"
}

# Function to check network
check_network() {
    print_section "🌐 Checking Network Connection"
    
    progress "Testing internet connectivity"
    if ! ping -c 1 archlinux.org &> /dev/null; then
        error "No internet connection available"
    fi
    success "Network connection verified"
}

# Function to verify SSH
verify_ssh() {
    print_section "🔒 Verifying SSH Connection"
    
    progress "Testing SSH connectivity"
    if ! ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
        warn "SSH connection to GitHub failed. Check your SSH key configuration."
        return 1
    fi
    success "SSH connection verified"
    return 0
}

# Function to copy SSH keys
mount_usb_and_copy_ssh() {
    print_section "🔑 Setting up SSH Keys"
    
    progress "Looking for installation media"
    
    # First, try to find the installation media
    local media_mount="/run/archiso/bootmnt"
    if [ ! -d "$media_mount" ]; then
        # Try to find and mount the USB device
        local usb_device=$(lsblk -rpo "name,type,mountpoint" | grep 'part' | awk '$3=="" {print $1}' | head -n 1)
        if [ -n "$usb_device" ]; then
            progress "Found potential USB device: $usb_device"
            mkdir -p "$media_mount"
            if ! mount "$usb_device" "$media_mount"; then
                warn "Could not mount USB device"
            fi
        fi
    fi

    # Check possible SSH key locations
    local ssh_locations=(
        "/root/.ssh"
        "$media_mount/secure/.ssh"
        "$media_mount/.ssh"
    )

    for location in "${ssh_locations[@]}"; do
        progress "Checking for SSH keys in $location"
        if [ -d "$location" ] && [ -n "$(ls -A "$location" 2>/dev/null)" ]; then
            progress "Found SSH keys in $location"
            mkdir -p /root/.ssh
            cp -r "$location/"* /root/.ssh/ 2>/dev/null
            chmod 700 /root/.ssh
            chmod 600 /root/.ssh/* 2>/dev/null
            success "SSH keys configured"
            return 0
        fi
    done

    # If no keys found, offer to generate new ones
    echo
    echo -e "${YELLOW}No existing SSH keys found. Would you like to:${NC}"
    echo "1) Generate new SSH keys"
    echo "2) Skip SSH key setup"
    read -p "$(echo -e "${BOLD}${BLUE}$ARROW${NC} Choose an option [1-2]: ")" ssh_choice
    
    case "$ssh_choice" in
        1)
            progress "Generating new SSH key"
            mkdir -p /root/.ssh
            ssh-keygen -t ed25519 -C "arch_install_$(date +%Y%m%d)" -f /root/.ssh/id_ed25519 -N ""
            chmod 700 /root/.ssh
            chmod 600 /root/.ssh/*
            
            # Display the public key
            echo
            echo -e "${YELLOW}Here is your public SSH key:${NC}"
            cat /root/.ssh/id_ed25519.pub
            echo
            echo -e "${YELLOW}Add this key to your GitHub account before continuing.${NC}"
            echo -e "${YELLOW}Visit: https://github.com/settings/keys${NC}"
            echo
            read -p "$(echo -e "${BOLD}${BLUE}$ARROW${NC} Press Enter when ready to continue...")"
            success "SSH key generated"
            return 0
            ;;
        2)
            warn "Skipping SSH key setup"
            return 1
            ;;
        *)
            warn "Invalid option. Skipping SSH key setup"
            return 1
            ;;
    esac
}

# Function to gather user input
gather_user_input() {
    print_section "📝 Installation Configuration"

    read -p "$(echo -e "${BOLD}${BLUE}$ARROW${NC} Do you want to copy SSH keys from USB? [Y/n]: ")" copy_ssh
    export COPY_SSH="${copy_ssh,,}"

    read -p "$(echo -e "${BOLD}${BLUE}$ARROW${NC} Enter hostname: ")" hostname
    export HOSTNAME=${hostname:-arch}

    while true; do
        read -s -p "$(echo -e "${BOLD}${BLUE}$ARROW${NC} Enter root password: ")" root_password
        echo
        read -s -p "$(echo -e "${BOLD}${BLUE}$ARROW${NC} Confirm root password: ")" root_password2
        echo
        if [ "$root_password" = "$root_password2" ]; then
            export ROOT_PASSWORD="$root_password"
            break
        fi
        warn "Passwords don't match. Please try again."
    done

    while true; do
        read -p "$(echo -e "${BOLD}${BLUE}$ARROW${NC} Enter username: ")" username
        if [[ "$username" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
            export USERNAME="$username"
            break
        else
            warn "Invalid username. Use only lowercase letters, numbers, - and _"
        fi
    done
    
    while true; do
        read -s -p "$(echo -e "${BOLD}${BLUE}$ARROW${NC} Enter password for $username: ")" user_password
        echo
        read -s -p "$(echo -e "${BOLD}${BLUE}$ARROW${NC} Confirm password: ")" user_password2
        echo
        if [ "$user_password" = "$user_password2" ]; then
            export USER_PASSWORD="$user_password"
            break
        fi
        warn "Passwords don't match. Please try again."
    done

    # Save configuration
    cat > /root/install_config << EOF
COPY_SSH="$COPY_SSH"
HOSTNAME="$HOSTNAME"
USERNAME="$USERNAME"
ROOT_PASSWORD="$ROOT_PASSWORD"
USER_PASSWORD="$USER_PASSWORD"
EOF

    chmod 600 /root/install_config
    success "Configuration saved"
}

# Main function
main() {
    # Set up error handling
    set -e
    trap 'error "An error occurred on line $LINENO"' ERR

    # Initial setup
    print_header
    check_prerequisites
    check_network

    # Check if we're on Arch installation media
    if [ -f /etc/arch-release ]; then
        progress "Starting Arch Linux installation"
        
        # Clean any existing configs
        rm -f /root/install_config /root/disk_config.txt
        
        # Gather user input and handle SSH
        gather_user_input
        if [[ "$COPY_SSH" =~ ^(y|yes)$ ]]; then
            if mount_usb_and_copy_ssh; then
                if ! verify_ssh; then
                    warn "SSH verification failed. Installation will continue, but you may want to check your SSH setup later."
                fi
            else
                warn "SSH key setup skipped. Installation will continue without SSH configuration."
            fi
        fi
        
        # Run BTRFS setup
        BTRFS_SCRIPT="$SCRIPT_DIR/preinstall/arch/btrfs.sh"
        if [ -f "$BTRFS_SCRIPT" ]; then
            print_section "💽 Running BTRFS Setup"
            progress "Running BTRFS setup"
            chmod +x "$BTRFS_SCRIPT"
            
            # Run BTRFS setup
            if ! "$BTRFS_SCRIPT"; then
                error "BTRFS setup failed"
            fi
            
            # Verify BTRFS setup created necessary configurations
            progress "Verifying BTRFS configuration"
            if [ ! -f "/root/disk_config.txt" ]; then
                error "BTRFS setup did not create disk configuration"
            fi
            
            # Display disk configuration for verification
            echo -e "\n${CYAN}Disk Configuration:${NC}"
            cat "/root/disk_config.txt"
            echo
            
            read -p "$(echo -e "${BOLD}${BLUE}$ARROW${NC} Does this disk configuration look correct? [Y/n]: ")" confirm
            case "${confirm,,}" in
                ""|y|yes)
                    success "BTRFS setup completed"
                    ;;
                *)
                    error "Installation aborted by user"
                    ;;
            esac
        else
            error "BTRFS script not found at: $BTRFS_SCRIPT"
        fi
        
        # Run archinstall
        ARCHINSTALL_SCRIPT="$SCRIPT_DIR/preinstall/arch/archinstall.sh"
        if [ -f "$ARCHINSTALL_SCRIPT" ]; then
            print_section "🚀 Running Arch Installation"
            
            # Verify all required configurations exist
            progress "Verifying configurations"
            if [ ! -f "/root/install_config" ]; then
                error "User configuration file missing"
            fi
            if [ ! -f "/root/disk_config.txt" ]; then
                error "Disk configuration file missing"
            fi
            
            # Display configurations for verification
            echo -e "\n${CYAN}Installation Configuration:${NC}"
            grep -v "PASSWORD" "/root/install_config" || true
            echo -e "\n${CYAN}Disk Configuration:${NC}"
            cat "/root/disk_config.txt"
            echo
            
            read -p "$(echo -e "${BOLD}${BLUE}$ARROW${NC} Ready to proceed with installation? [Y/n]: ")" proceed
            case "${proceed,,}" in
                ""|y|yes)
                    chmod +x "$ARCHINSTALL_SCRIPT"
                    progress "Running Arch installation"
                    if ! "$ARCHINSTALL_SCRIPT"; then
                        error "Arch installation failed"
                    fi
                    success "Arch installation completed"
                    ;;
                *)
                    error "Installation aborted by user"
                    ;;
            esac
            
            # Ask about reboot
            echo
            read -p "$(echo -e "${BOLD}${BLUE}$ARROW${NC} Installation complete. Reboot now? [Y/n]: ")" reboot_choice
            case "${reboot_choice,,}" in
                ""|y|yes)
                    systemctl reboot
                    ;;
                *)
                    echo "Please reboot manually when ready."
                    exit 0
                    ;;
            esac
        else
            error "Archinstall script not found at: $ARCHINSTALL_SCRIPT"
        fi
    else
        error "This script must be run from Arch installation media"
    fi
}

# Start the installation
main "$@"
