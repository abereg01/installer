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

# Get terminal width
TERM_WIDTH=$(tput cols)

# Script directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set config directory based on environment
if [ -f /etc/archiso-release ]; then
    CONFIG_DIR="/root/.config"
else
    CONFIG_DIR="$HOME/.config"
fi

# Repository URLs
DOTFILES_REPO="git@github.com:abereg01/dotfiles.git"
WALLPAPERS_REPO="git@github.com:abereg01/wallpapers.git"
SCRIPTS_REPO="git@github.com:abereg01/scripts.git"
THEMES_REPO="git@github.com:abereg01/themes.git"

# Desktop Environment Options
declare -A DE_OPTIONS=(
    ["1"]="BSPWM"
    ["2"]="KDE"
    ["3"]="DWM"
    ["4"]="Hyprland"
)

# Required tools
REQUIRED_TOOLS=(
    "git"
    "curl"
    "sudo"
    "rsync"
)

setup_logging() {
    LOG_FILE="/root/installer_$(date +%Y%m%d_%H%M%S).log"
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
    exec 1> >(tee -a "$LOG_FILE")
    exec 2> >(tee -a "$LOG_FILE" >&2)
    echo "Installation log started at $(date)"
}

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
    echo -e "${DIM}$(printf '%.s─' $(seq 1 $TERM_WIDTH))${NC}"
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
    echo -e "\r${YELLOW}⚠ WARNING:${NC} $1"
}

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

check_network() {
    print_section "🌐 Checking Network Connection"
    
    progress "Testing internet connectivity"
    if ! ping -c 1 github.com &> /dev/null; then
        error "No internet connection available"
    fi
    success "Network connection verified"
}

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

mount_usb_and_copy_ssh() {
    print_section "🔑 Setting up SSH Keys"
    
    progress "Detecting installation USB"
    local usb_device=""
    while read -r device; do
        if mount | grep -q "^$device"; then
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

    local mount_point="/mnt/usb"
    mkdir -p "$mount_point"

    progress "Mounting USB"
    if ! mount "$usb_device" "$mount_point"; then
        error "Failed to mount USB" "no_exit"
        return 1
    fi
    success "Mounted USB"

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

    umount "$mount_point"
    rm -r "$mount_point"
}

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

    cat > /root/install_config << EOF
COPY_SSH="$COPY_SSH"
HOSTNAME="$HOSTNAME"
USERNAME="$USERNAME"
ROOT_PASSWORD="$ROOT_PASSWORD"
USER_PASSWORD="$USER_PASSWORD"
EOF

    success "Configuration saved"
}

select_desktop_environment() {
    print_section "🖥️  Desktop Environment Selection"
    
    echo -e "${BOLD}Available Desktop Environments:${NC}"
    for key in $(echo "${!DE_OPTIONS[@]}" | tr ' ' '\n' | sort -n); do
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
    
    mkdir -p "$CONFIG_DIR"
    export DESKTOP_ENV="$selected_de"
    echo "DESKTOP_ENV=$selected_de" > "$CONFIG_DIR/de_config"
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
    
    if [[ "$DESKTOP_ENV" =~ ^(BSPWM|DWM)$ ]]; then
        progress "Cleaning AUR cache"
        yay -Sc --noconfirm &>/dev/null
        success "Cleaned AUR cache"
    fi
}

verify_installation() {
    print_section "✅ Verifying Installation"
    
    local required_dirs=(
        "$CONFIG_DIR"
    )
    
    local failed=0
    
    for dir in "${required_dirs[@]}"; do
        progress "Checking $dir"
        if [ -d "$dir" ]; then
            success "Found $dir"
        else
            warn "Missing $dir"
            failed=1
        fi
    done
    
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
    echo "- Check the logs in /root/installer_*.log"
    echo "- Verify your configurations in ~/.config"
    echo "- Run 'verify_installation' to check components"
    echo
}

main() {
   setup_logging
   print_header
   check_script_permissions
   check_prerequisites
   check_network

   if [ -f /etc/os-release ]; then
       . /etc/os-release
       case "$ID" in
           "arch")
               if [ -f /etc/archiso-release ]; then
                   progress "Starting Arch Linux installation"
                   gather_user_input
                   
                   if [[ "$COPY_SSH" =~ ^(y|yes)$ ]]; then
                       mount_usb_and_copy_ssh && verify_ssh
                   fi
                   
                   if [ -f "$SCRIPT_DIR/preinstall/arch/btrfs.sh" ]; then
                       bash "$SCRIPT_DIR/preinstall/arch/btrfs.sh" || error "BTRFS setup failed"
                       success "BTRFS setup completed"
                       
                       if [ -f "$SCRIPT_DIR/preinstall/arch/archinstall.sh" ]; then
                           bash "$SCRIPT_DIR/preinstall/arch/archinstall.sh" || error "Arch installation failed"
                           success "Arch installation completed"
                           
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
                           error "archinstall.sh not found"
                       fi
                   else
                       error "btrfs.sh not found"
                   fi
               else
                   # Post-installation setup
                   select_desktop_environment
                   source "$SCRIPT_DIR/os/arch.sh"
               fi
               ;;
           "debian"|"ubuntu")
               select_desktop_environment
               source "$SCRIPT_DIR/os/debian.sh"
               ;;
           "fedora")
               select_desktop_environment
               source "$SCRIPT_DIR/os/fedora.sh"
               ;;
           "void")
               select_desktop_environment
               source "$SCRIPT_DIR/os/void.sh"
               ;;
           *)
               error "Unsupported distribution: $ID"
               ;;
       esac
   else
       error "Unable to detect distribution"
   fi
   
   # Only run these for post-installation
   if [ ! -f /etc/archiso-release ]; then
       verify_installation
       cleanup
       print_completion_message
   fi
}

# Run the installer with error handling
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
   set -E  # Inherit ERR trap by shell functions
   trap 'echo "Error on line $LINENO. Check log at $LOG_FILE"; exit 1' ERR
   main "$@"
fi
