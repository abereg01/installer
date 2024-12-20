#!/usr/bin/env bash

# Main system installer script
# Handles UI, checks, and desktop environment selection

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

# Directories
HOME_DIR="$HOME"
CONFIG_DIR="$HOME_DIR/.config"
DOTFILES_DIR="$HOME_DIR/dotfiles"
SCRIPTS_DIR="$HOME_DIR/lib/scripts"
IMAGES_DIR="$HOME_DIR/lib/images"
THEMES_DIR="$HOME_DIR/.themes"
SSH_DIR="$HOME_DIR/.ssh"

# Repository URLs
DOTFILES_REPO="git@github.com:abereg01/dotfiles.git"
WALLPAPERS_REPO="git@github.com:abereg01/wallpapers.git"
SCRIPTS_REPO="git@github.com:abereg01/scripts.git"
THEMES_REPO="git@github.com:abereg01/themes.git"

# Set USB path and SSH backup location
USB_PATH="/run/media/andreas/YUMI"
SSH_BACKUP="$USB_PATH/secure/.ssh"

# Desktop Environment Options
declare -A DE_OPTIONS=(
    ["1"]="BSPWM"
    ["2"]="KDE"
    ["3"]="DWM"
    ["4"]="Hyprland"
)

# Function to print centered text
print_centered() {
    local text="$1"
    local width=$((($TERM_WIDTH - ${#text}) / 2))
    printf "%${width}s%s%${width}s\n" "" "$text" ""
}

# Function to print header
print_header() {
    clear
    echo
    echo -e "${BOLD}${BLUE}"
    print_centered "╔════════════════════════════════════════╗"
    print_centered "║     System Configuration Installer     ║"
    print_centered "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo
}

# Function to print section header
print_section() {
    echo
    echo -e "${CYAN}${BOLD}$1${NC}"
    echo -e "${DIM}$(printf '%.s─' $(seq 1 $TERM_WIDTH))${NC}"
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
    exit 1
}

warn() {
    echo -e "\r${YELLOW}⚠ WARNING:${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_section "🔍 Checking Prerequisites"
    
    local REQUIRED_COMMANDS=(git curl sudo)
    local MISSING_COMMANDS=()

    for cmd in "${REQUIRED_COMMANDS[@]}"; do
        progress "Checking for $cmd"
        if ! command -v "$cmd" &> /dev/null; then
            MISSING_COMMANDS+=("$cmd")
        else
            success "Found $cmd"
        fi
    done

    if [ ${#MISSING_COMMANDS[@]} -ne 0 ]; then
        error "Missing required commands: ${MISSING_COMMANDS[*]}"
    fi
    success "All prerequisites met"
}

# Check network connection
check_network() {
    print_section "🌐 Checking Network Connection"
    
    progress "Testing internet connectivity"
    if ping -c 1 github.com &> /dev/null; then
        success "Network connection verified"
    else
        error "No internet connection available"
    fi
}

# Check for USB drive and SSH keys
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
}

# Select desktop environment
select_desktop_environment() {
    print_section "🖥️  Desktop Environment Selection"
    
    echo -e "${BOLD}Available Desktop Environments:${NC}"
    for key in "${!DE_OPTIONS[@]}"; do
        echo -e "${BLUE}$key${NC}) ${DE_OPTIONS[$key]}"
    done
    echo

    while true; do
        read -p "$(echo -e ${BOLD}${BLUE}$ARROW${NC} Select desktop environment [1-4]: )" de_choice
        if [[ -n "${DE_OPTIONS[$de_choice]}" ]]; then
            selected_de="${DE_OPTIONS[$de_choice]}"
            success "Selected $selected_de"
            break
        else
            warn "Invalid selection. Please try again."
        fi
    done

    # Export selection for OS-specific script
    export DESKTOP_ENV="$selected_de"
}

# Cleanup function
cleanup() {
    print_section "🧹 Cleaning Up"
    
    progress "Removing temporary files"
    rm -rf /tmp/installer_* 2>/dev/null
    success "Cleanup complete"
}

# Verify installation
verify_installation() {
    print_section "✅ Verifying Installation"
    
    local REQUIRED_DIRS=("$DOTFILES_DIR" "$CONFIG_DIR" "$SCRIPTS_DIR")
    local FAILED=0
    
    for dir in "${REQUIRED_DIRS[@]}"; do
        progress "Checking $dir"
        if [ -d "$dir" ]; then
            success "Found $dir"
        else
            warn "Missing $dir"
            FAILED=1
        fi
    done
    
    if [ $FAILED -eq 1 ]; then
        warn "Some components may need attention"
    else
        success "All components verified"
    fi
}

# Print completion message
print_completion_message() {
    echo
    print_centered "${GREEN}${BOLD}Installation Complete!${NC}"
    echo
    echo -e "${CYAN}Next steps:${NC}"
    echo "1. Log out and back in"
    case "$DESKTOP_ENV" in
        "BSPWM")
            echo "2. Start BSPWM: exec bspwm"
            ;;
        "KDE")
            echo "2. Select KDE from your display manager"
            ;;
        "DWM")
            echo "2. Start DWM: exec dwm"
            ;;
        "Hyprland")
            echo "2. Start Hyprland: exec Hyprland"
            ;;
    esac
    echo "3. Check ~/.config for your configurations"
    echo
    echo -e "${YELLOW}Note:${NC} If you encounter any issues, check the logs in /tmp/installer_log"
}

# Main installation function
main() {
    print_header
    
    # Initial checks
    check_prerequisites
    check_network
    check_usb
    
    # Select desktop environment
    select_desktop_environment
    
    # Detect OS and source appropriate script
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

# Run the installer
main
