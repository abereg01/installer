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
    
    progress "Detecting SSH keys"
    local ssh_dirs=(
        "/root/.ssh"
        "/run/archiso/bootmnt/secure/.ssh"
        "/run/archiso/bootmnt/.ssh"
    )

    for ssh_dir in "${ssh_dirs[@]}"; do
        if [ -d "$ssh_dir" ]; then
            progress "Found SSH keys in $ssh_dir"
            mkdir -p /root/.ssh
            cp -r "$ssh_dir/"* /root/.ssh/
            chmod 700 /root/.ssh
            chmod 600 /root/.ssh/*
            success "SSH keys configured"
            return 0
        fi
    done

    warn "No SSH keys found"
    return 1
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
            mount_usb_and_copy_ssh && verify_ssh
        fi
        
        # Run BTRFS setup
        BTRFS_SCRIPT="$SCRIPT_DIR/preinstall/arch/btrfs.sh"
        if [ -f "$BTRFS_SCRIPT" ]; then
            progress "Running BTRFS setup"
            chmod +x "$BTRFS_SCRIPT"
            "$BTRFS_SCRIPT" || error "BTRFS setup failed"
            success "BTRFS setup completed"
        else
            error "BTRFS script not found at: $BTRFS_SCRIPT"
        fi
        
        # Run archinstall
        ARCHINSTALL_SCRIPT="$SCRIPT_DIR/preinstall/arch/archinstall.sh"
        if [ -f "$ARCHINSTALL_SCRIPT" ]; then
            progress "Running Arch installation"
            chmod +x "$ARCHINSTALL_SCRIPT"
            "$ARCHINSTALL_SCRIPT" || error "Arch installation failed"
            success "Arch installation completed"
            
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
