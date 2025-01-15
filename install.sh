#!/usr/bin/env bash

# Script version
VERSION="1.0.0"

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
DOWNLOAD="📥"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set config directory based on environment
if [ -f /etc/archiso-release ]; then
    CONFIG_DIR="/root"
else
    CONFIG_DIR="$HOME/.config"
fi

# Required tools
REQUIRED_TOOLS=(
    "git"
    "curl"
    "sudo"
    "rsync"
)

# Function to set up logging
setup_logging() {
    LOG_FILE="/root/installer_$(date +%Y%m%d_%H%M%S).log"
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
    exec 1> >(tee -a "$LOG_FILE")
    exec 2> >(tee -a "$LOG_FILE" >&2)
    echo "Installation log started at $(date)"
}

# Function to print centered text
print_centered() {
    local text="$1"
    local width=$((($TERM_WIDTH - ${#text}) / 2))
    printf "%${width}s%s%${width}s\n" "" "$text" ""
}

# Function to print header
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

# Function to print section header
print_section() {
    echo
    echo -e "${CYAN}${BOLD}$1${NC}"
    echo -e "${DIM}$(printf '%.s─' $(seq 1 $(tput cols)))${NC}"
}

# Progress and status functions
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

# Function to check root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "Please run as root"
    fi
}

# Debug configuration function
debug_config() {
    local config_file=$1
    if [ -f "$config_file" ]; then
        echo "Content of $config_file:"
        cat "$config_file"
        echo "File permissions:"
        ls -l "$config_file"
    else
        echo "Config file $config_file does not exist!"
    fi
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

# Function to mount USB and copy SSH keys
mount_usb_and_copy_ssh() {
    print_section "🔑 Setting up SSH Keys"
    
    progress "Detecting installation USB"
    local usb_device=$(findmnt -n -o SOURCE /run/archiso/bootmnt 2>/dev/null)
    
    if [ -z "$usb_device" ]; then
        error "Could not find USB device" "no_exit"
        return 1
    fi
    success "Found USB device: $usb_device"

    # Check for SSH directory in various locations
    local ssh_locations=(
        "/run/archiso/bootmnt/secure/.ssh"
        "/run/archiso/bootmnt/.ssh"
        "/root/.ssh"
    )

    for ssh_dir in "${ssh_locations[@]}"; do
        if [ -d "$ssh_dir" ]; then
            progress "Copying SSH keys from $ssh_dir"
            mkdir -p /root/.ssh
            cp -r "$ssh_dir/"* /root/.ssh/
            chmod 700 /root/.ssh
            chmod 600 /root/.ssh/*
            success "SSH keys copied"
            return 0
        fi
    done

    error "SSH directory not found in known locations" "no_exit"
    return 1
}

# Function to gather user input
gather_user_input() {
    print_section "📝 Installation Configuration"

    # Ensure we're in the right directory
    cd /root || error "Failed to change to /root directory"

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

    # Username validation
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

    # Create config with proper permissions
    local config_file="/root/install_config"
    cat > "$config_file" << EOF
COPY_SSH="$COPY_SSH"
HOSTNAME="$HOSTNAME"
USERNAME="$USERNAME"
ROOT_PASSWORD="$ROOT_PASSWORD"
USER_PASSWORD="$USER_PASSWORD"
EOF

    # Set proper permissions
    chmod 600 "$config_file"

    # Debug output
    progress "Verifying configuration"
    debug_config "$config_file"
    success "Configuration saved"
}

# Function to verify installation files
verify_installation_files() {
    print_section "🔍 Verifying Installation Files"
    
    progress "Checking installation files"
    
    local required_files=(
        "/root/install_config"
        "$SCRIPT_DIR/preinstall/arch/btrfs.sh"
        "$SCRIPT_DIR/preinstall/arch/archinstall.sh"
    )
    
    for file in "${required_files[@]}"; do
        if [ -f "$file" ]; then
            success "Found $file"
            debug_config "$file"
        else
            error "Missing required file: $file" "no_exit"
        fi
    done
}

# Function to run installation
run_installation() {
    print_section "🚀 Running Installation"

    # Run BTRFS setup
    if [ -f "$SCRIPT_DIR/preinstall/arch/btrfs.sh" ]; then
        progress "Running BTRFS setup"
        bash "$SCRIPT_DIR/preinstall/arch/btrfs.sh" || error "BTRFS setup failed"
        success "BTRFS setup completed"
    else
        error "BTRFS setup script not found"
    fi

    # Verify disk_config exists after BTRFS setup
    if [ ! -f "/root/disk_config.txt" ]; then
        error "Disk configuration file not created by BTRFS setup"
    fi

    # Run Arch installation
    if [ -f "$SCRIPT_DIR/preinstall/arch/archinstall.sh" ]; then
        progress "Running Arch installation"
        bash "$SCRIPT_DIR/preinstall/arch/archinstall.sh" || error "Arch installation failed"
        success "Arch installation completed"
    else
        error "Arch installation script not found"
    fi
}

# Main function
main() {
    setup_logging
    print_header
    check_root
    check_prerequisites
    check_network

    # Check if we're running from the Arch ISO
    if [ -f /etc/arch-release ] && ! [ -f /etc/hostname ]; then
        progress "Starting Arch Linux installation"
        
        # Clear any existing configs
        rm -f /root/install_config /root/disk_config.txt
        
        # Gather user input
        gather_user_input
        
        # Copy SSH keys if requested
        if [[ "$COPY_SSH" =~ ^(y|yes)$ ]]; then
            mount_usb_and_copy_ssh && verify_ssh
        fi
        
        # Verify installation files
        verify_installation_files
        
        # Run installation
        run_installation
        
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
        error "This script must be run from the Arch installation media"
    fi
}

# Run the installer with error handling
trap 'error "An error occurred on line $LINENO. Check the log at $LOG_FILE"' ERR
main "$@"
