#!/usr/bin/env bash

# Void Linux specific installation script

# Base packages for all installations
BASE_PACKAGES=(
    base-devel 
    git curl wget
    NetworkManager
    pipewire pipewire-alsa pipewire-pulse pipewire-jack
    fish
    kitty
    neovim vim
    dunst libnotify
    thunar
    sddm
    feh eza bat btop ripgrep unzip
    xtools
    gparted
    zram-generator
    # Development tools
    nodejs python3-pip python3-devel
    docker docker-compose
)

# Desktop environment specific packages (keep your existing definitions)
# ... (BSPWM_PACKAGES, KDE_PACKAGES, DWM_PACKAGES, HYPRLAND_PACKAGES)

# Function to check system
check_system() {
    print_section "🔍 Checking System"
    
    if ! [ -f /etc/void-release ]; then
        error "This script requires Void Linux"
    fi
    success "System check passed"
}

# Function to configure XBPS
configure_xbps() {
    print_section "🔧 Configuring XBPS"
    
    # Create configuration directory
    sudo mkdir -p /etc/xbps.d
    
    # Configure parallel downloads
    echo 'repository=https://alpha.de.repo.voidlinux.org/current' | sudo tee /etc/xbps.d/00-repository-main.conf
    echo 'repository=https://alpha.de.repo.voidlinux.org/current/nonfree' | sudo tee /etc/xbps.d/10-repository-nonfree.conf
    
    success "Configured XBPS"
}

# Function to configure ZRAM
configure_zram() {
    print_section "🔧 Configuring ZRAM"
    
    progress "Creating ZRAM configuration"
    sudo tee /etc/systemd/zram-generator.conf > /dev/null << EOF
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
EOF
    
    success "Configured ZRAM"
}

# Function to update firmware
update_firmware() {
    print_section "🔄 Updating Firmware"
    
    progress "Installing fwupd"
    sudo xbps-install -y fwupd
    
    progress "Checking for firmware updates"
    sudo fwupdmgr get-devices
    sudo fwupdmgr refresh
    sudo fwupdmgr get-updates
    
    progress "Installing firmware updates"
    sudo fwupdmgr update
    success "Firmware update complete"
}

# Function to install development tools
install_dev_tools() {
    print_section "🛠️ Installing Development Tools"
    
    # Install VS Code
    progress "Installing VS Code"
    sudo xbps-install -y vscode
    
    # Install Python tools
    progress "Installing Python development tools"
    pip install --user pylint black mypy pytest
    
    # Install Node.js tools
    progress "Installing Node.js development tools"
    sudo npm install -g typescript ts-node eslint prettier
    
    success "Installed development tools"
}

# Keep your existing functions (install_starship, install_dwm, install_chrome)
# ... (keep them as they are)

# Function to cleanup packages
cleanup_packages() {
    print_section "🧹 Cleaning Up"
    
    progress "Removing unused packages"
    sudo xbps-remove -O
    
    progress "Cleaning package cache"
    sudo xbps-remove -y
    success "Cleanup complete"
}

# Main Void installation function
install_void() {
    check_system
    configure_xbps
    enable_nonfree
    install_packages
    install_dev_tools
    configure_services
    configure_zram
    update_firmware
    cleanup_packages
}

# Run the installation
install_void
