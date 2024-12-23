#!/usr/bin/env bash

# Version
VERSION="1.0.0"

# Import common functions if not already imported
if [ -z "$SCRIPT_DIR" ]; then
    echo "Error: This script should be sourced from install.sh"
    exit 1
fi

# Base packages (enhanced version of yours)
BASE_PACKAGES=(
    # System base
    base base-devel
    git curl wget
    networkmanager network-manager-applet
    
    # Audio
    pipewire pipewire-alsa pipewire-pulse pipewire-jack
    
    # Shell and tools
    fish starship
    kitty alacritty
    neovim vim
    
    # System utilities
    dunst libnotify
    thunar
    sddm
    feh eza bat btop ripgrep unzip
    timeshift timeshift-autosnap
    grub-btrfs btrbk
    
    # Development tools
    nodejs npm yarn
    python python-pip python-setuptools
    docker docker-compose
    
    # System management
    gparted
    zram-generator
)

# Desktop environment specific packages (keeping your existing ones)
BSPWM_PACKAGES=(
    bspwm sxhkd polybar rofi picom
    dmenu
)

KDE_PACKAGES=(
    plasma plasma-wayland-session
    kde-applications
    dolphin konsole
    plasma-nm plasma-pa
)

DWM_PACKAGES=(
    libx11 libxft libxinerama
    xorg-server xorg-xinit
    st dmenu
)

HYPRLAND_PACKAGES=(
    hyprland xdg-desktop-portal-hyprland
    waybar wofi
    grim slurp
    wl-clipboard
)

# Function to check Arch version (enhanced)
check_arch_version() {
    print_section "🔍 Checking System Requirements"
    
    progress "Verifying system"
    if ! grep -q "Arch Linux" /etc/os-release; then
        error "This script requires Arch Linux"
    fi
    success "System requirements met"

    progress "Checking kernel version"
    local kernel_version=$(uname -r | cut -d. -f1,2)
    if (( $(echo "$kernel_version < 5.15" | bc -l) )); then
        warn "Kernel version $kernel_version might be too old"
    else
        success "Kernel version $kernel_version is compatible"
    fi
}

# Function to configure pacman (enhanced)
configure_pacman() {
    print_section "🔧 Configuring Pacman"
    
    local pacman_conf="/etc/pacman.conf"
    progress "Backing up pacman configuration"
    sudo cp "$pacman_conf" "${pacman_conf}.backup"
    success "Created pacman configuration backup"
    
    progress "Optimizing pacman configuration"
    sudo sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 10/' "$pacman_conf"
    sudo sed -i 's/#Color/Color/' "$pacman_conf"
    sudo sed -i 's/#VerbosePkgLists/VerbosePkgLists/' "$pacman_conf"
    
    # Add custom repositories if needed
    if ! grep -q "\[multilib\]" "$pacman_conf"; then
        echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" | sudo tee -a "$pacman_conf" >/dev/null
    fi
    
    success "Optimized pacman configuration"
}

# Function to check and configure neovim (enhanced)
check_neovim_version() {
    print_section "🔍 Checking Neovim Version"
    
    progress "Verifying Neovim installation"
    if ! command -v nvim &>/dev/null; then
        error "Neovim is not installed"
    fi
    
    progress "Checking Neovim version"
    local nvim_version=$(nvim --version | head -n1 | cut -d ' ' -f2)
    local required_version="0.10.0"
    
    if [ "$(printf '%s\n' "$required_version" "$nvim_version" | sort -V | head -n1)" != "$required_version" ]; then
        error "Neovim version must be at least 0.10.0. Found version: $nvim_version"
    fi
    success "Neovim version requirement met: $nvim_version"
}

# Function to install yay (enhanced)
install_yay() {
    print_section "📦 Installing AUR Helper"
    
    if command -v yay &>/dev/null; then
        success "yay is already installed"
        return
    fi

    progress "Creating temp directory"
    local temp_dir=$(mktemp -d)
    cd "$temp_dir" || error "Failed to create temporary directory"
    
    progress "Cloning yay repository"
    git clone https://aur.archlinux.org/yay.git . || error "Failed to clone yay"
    
    progress "Building yay"
    makepkg -si --noconfirm || error "Failed to build yay"
    
    cd - >/dev/null
    rm -rf "$temp_dir"
    success "Installed yay successfully"
}

# Function to configure ZRAM (enhanced)
configure_zram() {
    print_section "🔧 Configuring ZRAM"
    
    progress "Creating ZRAM configuration"
    sudo mkdir -p /etc/systemd
    sudo tee /etc/systemd/zram-generator.conf > /dev/null << EOF
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
EOF
    
    progress "Reloading systemd"
    sudo systemctl daemon-reload
    success "Configured ZRAM"
    
    progress "Verifying ZRAM configuration"
    if ! grep -q "zram0" /proc/swaps; then
        warn "ZRAM not active yet. Will be enabled on next boot."
    else
        success "ZRAM is active"
    fi
}

# Function to update firmware (enhanced)
update_firmware() {
    print_section "🔄 Updating Firmware"
    
    progress "Installing fwupd"
    sudo pacman -S --needed --noconfirm fwupd || error "Failed to install fwupd"
    
    progress "Refreshing firmware list"
    sudo fwupdmgr refresh --force
    
    progress "Checking for firmware updates"
    if sudo fwupdmgr get-updates &>/dev/null; then
        progress "Installing firmware updates"
        sudo fwupdmgr update
        success "Firmware update complete"
    else
        success "No firmware updates available"
    fi
}

# Function to install multimedia support (enhanced)
install_multimedia() {
    print_section "🎵 Installing Multimedia Support"
    
    local multimedia_packages=(
        gst-plugins-base
        gst-plugins-good
        gst-plugins-bad
        gst-plugins-ugly
        gst-libav
        ffmpeg
        vlc
    )
    
    progress "Installing multimedia packages"
    sudo pacman -S --needed --noconfirm "${multimedia_packages[@]}" || {
        error "Failed to install multimedia packages" "no_exit"
        return 1
    }
    
    success "Installed multimedia codecs"
}

# Function to install development tools (enhanced)
install_dev_tools() {
    print_section "🛠️ Installing Development Tools"
    
    # VS Code installation
    progress "Installing VS Code"
    yay -S --needed --noconfirm visual-studio-code-bin || warn "Failed to install VS Code"
    
    # Python tools
    progress "Installing Python development tools"
    pip install --user --no-warn-script-location pylint black mypy pytest || warn "Failed to install some Python tools"
    
    # Node.js tools
    progress "Installing Node.js development tools"
    sudo npm install -g typescript ts-node eslint prettier || warn "Failed to install some Node.js tools"
    
    # Docker configuration
    progress "Configuring Docker"
    sudo systemctl enable docker.service
    sudo usermod -aG docker "$USER"
    
    success "Installed development tools"
}

# Function to install packages (enhanced)
install_packages() {
    print_section "📦 Installing Packages"

    # Update system first
    progress "Updating system"
    sudo pacman -Syu --noconfirm || error "Failed to update system"
    success "System updated"

    # Install base packages
    progress "Installing base packages"
    sudo pacman -S --needed --noconfirm "${BASE_PACKAGES[@]}" || error "Failed to install base packages"
    success "Installed base packages"

    # Install DE-specific packages
    case "$DESKTOP_ENV" in
        "BSPWM")
            progress "Installing BSPWM packages"
            sudo pacman -S --needed --noconfirm "${BSPWM_PACKAGES[@]}" || error "Failed to install BSPWM packages"
            success "Installed BSPWM packages"
            ;;
        "KDE")
            progress "Installing KDE packages"
            sudo pacman -S --needed --noconfirm "${KDE_PACKAGES[@]}" || {
                error "Failed to install KDE packages" "no_exit"
                return 1
            }
            success "Installed KDE packages"
            ;;
        "DWM")
            progress "Installing DWM dependencies"
            sudo pacman -S --needed --noconfirm "${DWM_PACKAGES[@]}" || error "Failed to install DWM dependencies"
            
            # Clone and build DWM
            local temp_dir=$(mktemp -d)
            cd "$temp_dir"
            progress "Building DWM"
            git clone https://git.suckless.org/dwm . || error "Failed to clone DWM"
            sudo make clean install || error "Failed to build DWM"
            cd - >/dev/null
            rm -rf "$temp_dir"
            success "Built and installed DWM"
            ;;
        "Hyprland")
            progress "Installing Hyprland packages"
            sudo pacman -S --needed --noconfirm "${HYPRLAND_PACKAGES[@]}" || error "Failed to install Hyprland packages"
            success "Installed Hyprland packages"
            ;;
    esac

    # Install AUR helper and packages
    install_yay
    
    progress "Installing AUR packages"
    yay -S --needed --noconfirm getnf notify-send.sh google-chrome || warn "Some AUR packages failed to install"
    success "Installed AUR packages"
}

# Function to configure services (enhanced)
configure_services() {
    print_section "🔧 Configuring Services"

    local services=(
        NetworkManager
        sddm
        pipewire-pulse
        docker
        bluetooth  # Added bluetooth
        cups      # Added printing
    )

    for service in "${services[@]}"; do
        progress "Enabling $service"
        if systemctl is-enabled "$service" &>/dev/null; then
            success "$service is already enabled"
        else
            sudo systemctl enable "$service" || warn "Failed to enable $service"
            success "Enabled $service"
        fi
    done

    # Additional service configurations
    progress "Configuring service settings"
    sudo systemctl mask systemd-rfkill.service systemd-rfkill.socket || warn "Failed to mask rfkill service"
    success "Configured service settings"
}

# Function to cleanup packages (enhanced)
cleanup_packages() {
    print_section "🧹 Cleaning Up"
    
    progress "Cleaning package cache"
    sudo pacman -Sc --noconfirm
    
    progress "Removing orphaned packages"
    if [[ $(pacman -Qdtq) ]]; then
        sudo pacman -Rns $(pacman -Qdtq) --noconfirm || warn "Some orphaned packages could not be removed"
    fi
    
    progress "Clearing pacman cache"
    sudo paccache -r
    success "Cleaned package cache"
}

# Main Arch installation function
install_arch() {
    check_arch_version
    configure_pacman
    install_packages
    install_dev_tools
    install_multimedia
    configure_services
    configure_zram
    update_firmware
    cleanup_packages
}

# Run the installation
install_arch "
