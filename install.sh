#!/usr/bin/env bash

# Script version
VERSION="1.0.0"

# Colors and styling (keeping your existing scheme)
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

# Unicode symbols (keeping your existing ones)
CHECK_MARK="\033[0;32m✓\033[0m"
CROSS_MARK="\033[0;31m✗\033[0m"
ARROW="→"
GEAR="⚙"
KEY="🔑"
FOLDER="📁"
DOWNLOAD="📥"

# Get terminal width
TERM_WIDTH=$(tput cols)

# Script directories (keeping your existing structure)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="$HOME"
CONFIG_DIR="$HOME_DIR/.config"
DOTFILES_DIR="$HOME_DIR/dotfiles"
SCRIPTS_DIR="$HOME_DIR/lib/scripts"
IMAGES_DIR="$HOME_DIR/lib/images"
THEMES_DIR="$HOME_DIR/.themes"
SSH_DIR="$HOME_DIR/.ssh"

# Repository URLs (keeping your existing ones)
DOTFILES_REPO="git@github.com:abereg01/dotfiles.git"
WALLPAPERS_REPO="git@github.com:abereg01/wallpapers.git"
SCRIPTS_REPO="git@github.com:abereg01/scripts.git"
THEMES_REPO="git@github.com:abereg01/themes.git"

mount_usb_and_copy_ssh() {
    print_section "🔑 Setting up SSH Keys"
    
    # Find USB drive
    progress "Detecting installation USB"
    local usb_device=""
    while read -r device; do
        if mount | grep -q "^$device"; then
            # Skip if already mounted
            continue
        fi
        if file -s "$device" | grep -qi "fat\|iso9660"; then
            usb_device="$device"
            break
        fi
    done < <(lsblk -pnl -o NAME | grep -E 'sd[a-z][0-9]|nvme[0-9]n[0-9]p[0-9]')

    if [ -z "$usb_device" ]; then
        error "Could not find USB device" "no_exit"
        return 1
    fi
    success "Found USB device: $usb_device"

    # Create mount point
    local mount_point="/mnt/usb"
    mkdir -p "$mount_point"

    # Mount USB
    progress "Mounting USB"
    if ! mount "$usb_device" "$mount_point"; then
        error "Failed to mount USB" "no_exit"
        return 1
    fi
    success "Mounted USB"

    # Copy SSH keys
    progress "Copying SSH keys"
    if [ -d "$mount_point/secure/.ssh" ]; then
        mkdir -p /root/.ssh
        cp -r "$mount_point/secure/.ssh/"* /root/.ssh/
        chmod 700 /root/.ssh
        chmod 600 /root/.ssh/*
        success "SSH keys copied"
    else
        error "SSH directory not found on USB" "no_exit"
        return 1
    fi

    # Unmount USB
    umount "$mount_point"
    rm -r "$mount_point"
}

# USB and backup paths (keeping your existing ones)
USB_PATH="/run/media/andreas/YUMI"
SSH_BACKUP="$USB_PATH/secure/.ssh"

if [ "$ID" == "arch" ]; then
    print_section "🚀 Arch Linux Pre-installation"
    
    # Check if we're in the installation environment
    if [ -f /etc/archiso-release ]; then
        progress "Running BTRFS setup"
        if [ -f "$SCRIPT_DIR/preinstall/arch/btrfs.sh" ]; then
            bash "$SCRIPT_DIR/preinstall/arch/btrfs.sh" || error "BTRFS setup failed"
            success "BTRFS setup completed"
            
            progress "Running Arch installation"
            if [ -f "$SCRIPT_DIR/preinstall/arch/archinstall.sh" ]; then
                bash "$SCRIPT_DIR/preinstall/arch/archinstall.sh" || error "Arch installation failed"
                success "Arch installation completed"
            else
                error "archinstall.sh not found"
            fi
        else
            error "btrfs.sh not found"
        fi
    fi
fi

gather_user_input() {
    print_section "📝 Installation Configuration"

    # SSH Keys
    read -p "$(echo -e "${BOLD}${BLUE}$ARROW${NC} Do you want to copy SSH keys from USB? [Y/n]: ")" copy_ssh
    export COPY_SSH="${copy_ssh,,}"

    # Hostname
    read -p "$(echo -e "${BOLD}${BLUE}$ARROW${NC} Enter hostname: ")" hostname
    export HOSTNAME=${hostname:-arch}

    # Root password
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

    # User account
    read -p "$(echo -e "${BOLD}${BLUE}$ARROW${NC} Enter username: ")" username
    export USERNAME="$username"
    
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

    success "Configuration saved"
}

# Desktop Environment Options (keeping your existing ones)
declare -A DE_OPTIONS=(
    ["1"]="BSPWM"
    ["2"]="KDE"
    ["3"]="DWM"
    ["4"]="Hyprland"
)

# Required tools for the script
REQUIRED_TOOLS=(
    "git"
    "curl"
    "sudo"
    "rsync"
)

# Function to print centered text (keeping your existing one)
print_centered() {
    local text="$1"
    local width=$((($TERM_WIDTH - ${#text}) / 2))
    printf "%${width}s%s%${width}s\n" "" "$text" ""
}

# Function to print header (enhanced version of yours)
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

# Function to print section header (keeping your existing one)
print_section() {
    echo
    echo -e "${CYAN}${BOLD}$1${NC}"
    echo -e "${DIM}$(printf '%.s─' $(seq 1 $TERM_WIDTH))${NC}"
}

# Enhanced progress and status functions (building on your existing ones)
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
    echo -e "\r${YELLOW}⚠ WARNING:${NC} $1"
}

# Enhanced prerequisites check (building on your existing one)
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

# Enhanced network check
check_network() {
    print_section "🌐 Checking Network Connection"
    
    progress "Testing internet connectivity"
    if ! ping -c 1 github.com &> /dev/null; then
        error "No internet connection available"
    fi
    success "Network connection verified"
    
    # Make SSH check optional
    progress "Testing SSH connectivity"
    if ! ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
        warn "SSH connection to GitHub failed. Some features may be limited."
        warn "You can continue without SSH setup."
    else
        success "SSH connection verified"
    fi
}

# Enhanced USB check (building on your existing one)
check_usb() {
    print_section "🔑 Checking USB Drive"
    
    progress "Checking USB drive"
    if [ ! -d "$USB_PATH" ]; then
        error "USB drive not found at $USB_PATH"
    fi
    success "Found USB drive"
    
    progress "Checking SSH keys"
    if [ ! -d "$SSH_BACKUP" ]; then
        error "SSH directory not found at $SSH_BACKUP"
    fi
    success "Found SSH keys"
    
    # Additional permission checks
    progress "Checking USB permissions"
    if [ ! -r "$USB_PATH" ] || [ ! -w "$USB_PATH" ]; then
        error "Insufficient permissions on USB drive"
    fi
    success "USB permissions verified"
}

check_script_permissions() {
    print_section "🔑 Checking Script Permissions"
    
    local scripts=(
        "$SCRIPT_DIR/preinstall/arch/btrfs.sh"
        "$SCRIPT_DIR/preinstall/arch/archinstall.sh"
        "$SCRIPT_DIR/os/arch.sh"
        "$SCRIPT_DIR/os/debian.sh"
        "$SCRIPT_DIR/os/fedora.sh"
        "$SCRIPT_DIR/os/void.sh"
    )

    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            progress "Checking permissions for $(basename $script)"
            if [ ! -x "$script" ]; then
                chmod +x "$script"
            fi
            success "$(basename $script) is executable"
        fi
    done
}

# Enhanced DE selection (building on your existing one)
select_desktop_environment() {
    print_section "🖥️  Desktop Environment Selection"
    
    echo -e "${BOLD}Available Desktop Environments:${NC}"
    for key in "${!DE_OPTIONS[@]}"; do
        echo -e "${BLUE}$key${NC}) ${DE_OPTIONS[$key]}"
    done
    echo
    
    local selected_de=""
    while [ -z "$selected_de" ]; do
        read -p "$(echo -e ${BOLD}${BLUE}$ARROW${NC} Select desktop environment [1-4]: )" de_choice
        if [[ -n "${DE_OPTIONS[$de_choice]}" ]]; then
            selected_de="${DE_OPTIONS[$de_choice]}"
            success "Selected $selected_de"
        else
            warn "Invalid selection. Please try again."
        fi
    done
    
    # Export selection and save to config
    export DESKTOP_ENV="$selected_de"
    echo "DESKTOP_ENV=$selected_de" > "$CONFIG_DIR/de_config"
}

# Enhanced cleanup (building on your existing one)
cleanup() {
    print_section "🧹 Cleaning Up"
    
    local temp_files=(
        "/tmp/installer_*"
        "/tmp/config_backup_*"
        "/tmp/de_setup_*"
    )
    
    for file in "${temp_files[@]}"; do
        progress "Removing $file"
        rm -rf $file 2>/dev/null
        success "Cleaned $file"
    done
    
    # Clean package cache based on DE
    case "$DESKTOP_ENV" in
        "BSPWM"|"DWM")
            progress "Cleaning AUR cache"
            yay -Sc --noconfirm &>/dev/null
            success "Cleaned AUR cache"
            ;;
    esac
}

# Enhanced installation verification (building on your existing one)
verify_installation() {
    print_section "✅ Verifying Installation"
    
    local required_dirs=(
        "$DOTFILES_DIR"
        "$CONFIG_DIR"
        "$SCRIPTS_DIR"
        "$SSH_DIR"
    )
    
    local required_configs=(
        "fish"
        "nvim"
        "starship.toml"
    )
    
    local failed=0
    
    # Check directories
    for dir in "${required_dirs[@]}"; do
        progress "Checking $dir"
        if [ -d "$dir" ]; then
            success "Found $dir"
        else
            warn "Missing $dir"
            failed=1
        fi
    done
    
    # Check configs
    for config in "${required_configs[@]}"; do
        progress "Checking $config configuration"
        if [ -e "$CONFIG_DIR/$config" ]; then
            success "Found $config configuration"
        else
            warn "Missing $config configuration"
            failed=1
        fi
    done
    
    # Check DE-specific components
    case "$DESKTOP_ENV" in
        "BSPWM")
            progress "Checking BSPWM configuration"
            if [ -f "$CONFIG_DIR/bspwm/bspwmrc" ] && [ -f "$CONFIG_DIR/sxhkd/sxhkdrc" ]; then
                success "BSPWM configuration verified"
            else
                warn "BSPWM configuration incomplete"
                failed=1
            fi
            ;;
        "KDE")
            progress "Checking KDE configuration"
            if [ -d "$CONFIG_DIR/plasma-workspace" ]; then
                success "KDE configuration verified"
            else
                warn "KDE configuration incomplete"
                failed=1
            fi
            ;;
    esac
    
    if [ $failed -eq 1 ]; then
        warn "Some components need attention"
    else
        success "All components verified"
    fi
}

# Enhanced completion message (building on your existing one)
print_completion_message() {
    echo
    print_centered "${GREEN}${BOLD}Installation Complete!${NC}"
    echo
    echo -e "${CYAN}Next steps:${NC}"
    echo "1. Log out and back in"
    
    case "$DESKTOP_ENV" in
        "BSPWM")
            echo "2. Start BSPWM: exec bspwm"
            echo "3. Check ~/.config/bspwm for your configurations"
            ;;
        "KDE")
            echo "2. Select KDE Plasma from your display manager"
            echo "3. Check System Settings for your configurations"
            ;;
        "DWM")
            echo "2. Start DWM: exec dwm"
            echo "3. Check ~/.dwm for your configurations"
            ;;
        "Hyprland")
            echo "2. Start Hyprland: exec Hyprland"
            echo "3. Check ~/.config/hypr for your configurations"
            ;;
    esac
    
    echo
    echo -e "${YELLOW}Note:${NC} If you encounter any issues:"
    echo "- Check the logs in /tmp/installer_log"
    echo "- Verify your configurations in ~/.config"
    echo "- Run 'verify_installation' to check components"
    echo
}



# Main installation function
main() {
    print_header
    
    # Initial checks
    check_prerequisites
    check_network
    
    # Ask about SSH keys
    read -p "$(echo -e "${BOLD}${BLUE}$ARROW${NC} Do you want to copy SSH keys from USB? [Y/n]: ")" copy_ssh
    if [[ "${copy_ssh,,}" =~ ^(y|yes|)$ ]]; then
        mount_usb_and_copy_ssh
    fi
    
    # Initial checks
    check_script_permissions
    check_prerequisites
    check_network
    check_usb

        read -p "$(echo -e "${BOLD}${BLUE}$ARROW${NC} Do you want to copy SSH keys from USB? [Y/n]: ")" copy_ssh
    if [[ "${copy_ssh,,}" =~ ^(y|yes|)$ ]]; then
        mount_usb_and_copy_ssh
    fi
    
    # Select desktop environment
    select_desktop_environment
    
    # Source OS-specific script
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            "arch")
                source "$SCRIPT_DIR/os/arch.sh"
                ;;
            "debian"|"ubuntu")
                source "$SCRIPT_DIR/os/debian.sh"
                ;;
            "fedora")
                source "$SCRIPT_DIR/os/fedora.sh"
                ;;
            "void")
                source "$SCRIPT_DIR/os/void.sh"
                ;;
            *)
                error "Unsupported distribution: $ID"
                ;;
        esac
    else
        error "Unable to detect distribution"
    fi
    
    # Final steps
    verify_installation
    cleanup
    print_completion_message
}

# Run the installer with error handling
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    trap 'error "An error occurred. Check /tmp/installer_log for details."' ERR
    main "$@"
fi
