#!/usr/bin/env bash

# Debian/Ubuntu specific installation script

# Minimum supported versions
MIN_UBUNTU_VERSION="22.04"
MIN_DEBIAN_VERSION="12"

# Base packages for all installations
BASE_PACKAGES=(
    build-essential
    git curl wget
    network-manager network-manager-gnome
    pipewire pipewire-audio pipewire-pulse
    fish
    kitty
    vim
    dunst libnotify-bin
    thunar
    sddm
    feh bat ripgrep unzip
    gparted
    zram-tools
    # Development tools
    nodejs npm
    python3-pip python3-dev
    docker.io docker-compose
)

# Desktop environment specific packages
BSPWM_PACKAGES=(
    bspwm sxhkd polybar rofi picom
    dmenu
)

KDE_PACKAGES=(
    kde-plasma-desktop
    kde-standard
    dolphin konsole
)

GNOME_PACKAGES=(
    ubuntu-desktop
    gnome-tweaks
    gnome-shell-extensions
)

DWM_PACKAGES=(
    libx11-dev libxft-dev libxinerama-dev
    xorg x11-xserver-utils
    build-essential
)

HYPRLAND_PACKAGES=(
    hyprland
    waybar wofi
    grim slurp
    wl-clipboard
)

# Function to check system version
check_system_version() {
    print_section "🔍 Checking System Version"
    
    if [ -f /etc/debian_version ]; then
        local version=$(cat /etc/debian_version)
        if [ "$(printf '%s\n' "$MIN_DEBIAN_VERSION" "$version" | sort -V | head -n1)" != "$MIN_DEBIAN_VERSION" ]; then
            error "This script requires Debian $MIN_DEBIAN_VERSION or higher. Current version: $version"
        fi
    elif [ -f /etc/lsb-release ]; then
        local version=$(awk -F'=' '/DISTRIB_RELEASE/ {print $2}' /etc/lsb-release)
        if [ "$(printf '%s\n' "$MIN_UBUNTU_VERSION" "$version" | sort -V | head -n1)" != "$MIN_UBUNTU_VERSION" ]; then
            error "This script requires Ubuntu $MIN_UBUNTU_VERSION or higher. Current version: $version"
        fi
    fi
    success "System version requirement met"
}

# Function to setup additional repositories
setup_repositories() {
    print_section "📦 Setting Up Repositories"

    # Add Fish shell repository
    progress "Adding Fish shell repository"
    if ! sudo apt-add-repository ppa:fish-shell/release-3 -y; then
        error "Failed to add Fish shell repository"
    fi
    success "Added Fish shell repository"

    # Add Neovim repository
    progress "Adding Neovim repository"
    if ! sudo add-apt-repository ppa:neovim-ppa/unstable -y; then
        error "Failed to add Neovim repository"
    fi
    success "Added Neovim repository"

    # Setup Starship repository
    progress "Setting up Starship repository"
    if ! curl -sS https://starship.rs/install.sh | sh; then
        error "Failed to install Starship"
    fi
    success "Setup Starship repository"

    # Add Kitty repository
    progress "Adding Kitty repository"
    if ! curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin; then
        error "Failed to add Kitty repository"
    fi
    success "Added Kitty repository"

    # Add eza repository
    progress "Setting up eza repository"
    sudo mkdir -p /etc/apt/keyrings
    if ! wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/eza.gpg; then
        error "Failed to add eza key"
    fi
    echo "deb [signed-by=/etc/apt/keyrings/eza.gpg] http://deb.debian.org/debian unstable main" | sudo tee /etc/apt/sources.list.d/eza.list
    success "Added eza repository"

    # Add Hyprland repository if selected
    if [ "$DESKTOP_ENV" = "Hyprland" ]; then
        progress "Adding Hyprland repository"
        if ! sudo add-apt-repository ppa:hyprland-dev/ppa -y; then
            error "Failed to add Hyprland repository"
        fi
        success "Added Hyprland repository"
    fi

    # Add VS Code repository
    progress "Adding VS Code repository"
    if ! wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/packages.microsoft.gpg; then
        error "Failed to download Microsoft key"
    fi
    sudo install -o root -g root -m 644 /tmp/packages.microsoft.gpg /etc/apt/trusted.gpg.d/
    echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" | sudo tee /etc/apt/sources.list.d/vscode.list
    rm /tmp/packages.microsoft.gpg
    success "Added VS Code repository"

    # Update package lists
    progress "Updating package lists"
    if ! sudo apt update; then
        error "Failed to update package lists"
    fi
    success "Updated package lists"
}

# Function to configure ZRAM
configure_zram() {
    print_section "🔧 Configuring ZRAM"
    
    progress "Creating ZRAM configuration"
    echo -e "ALGO=zstd\nPERCENT=50" | sudo tee /etc/default/zramswap
    sudo systemctl restart zramswap
    success "Configured ZRAM"
}

# Function to update firmware
update_firmware() {
    print_section "🔄 Updating Firmware"
    
    progress "Installing fwupd"
    sudo apt install -y fwupd
    
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
    
    progress "Installing VS Code"
    sudo apt install -y code
    
    progress "Installing Python development tools"
    pip3 install --user pylint black mypy pytest
    
    progress "Installing Node.js development tools"
    sudo npm install -g typescript ts-node eslint prettier
    
    success "Installed development tools"
}

# Function to install multimedia codecs
install_multimedia_codecs() {
    print_section "🎵 Installing Multimedia Codecs"
    
    if [ -f /etc/lsb-release ]; then
        # Ubuntu
        sudo apt install -y ubuntu-restricted-extras
    else
        # Debian
        sudo apt install -y libavcodec-extra
        sudo apt install -y multimedia-audio-plugins
    fi
    
    success "Installed multimedia codecs"
}

# Rest of your existing functions (install_btop, install_chrome, install_dwm, etc.)
# ... (keep them as they are)

# Function to cleanup packages
cleanup_packages() {
    print_section "🧹 Cleaning Up"
    
    progress "Removing unused packages"
    sudo apt autoremove -y
    
    progress "Cleaning package cache"
    sudo apt clean
    success "Cleanup complete"
}

# Main Debian/Ubuntu installation function
install_debian() {
    check_system_version
    setup_repositories
    install_packages
    install_dev_tools
    install_multimedia_codecs
    configure_services
    configure_zram
    update_firmware
    cleanup_packages
}

# Run the installation
install_debian
