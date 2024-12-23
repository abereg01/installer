#!/usr/bin/env bash

# Version
VERSION="1.0.0"

# Import common functions if not already imported
if [ -z "$SCRIPT_DIR" ]; then
    echo "Error: This script should be sourced from install.sh"
    exit 1
fi

# Base packages
BASE_PACKAGES=(
    # Shell and Terminal
    fish
    starship
    kitty 
    alacritty
    
    # Editors and Development
    neovim
    vim
    git
    curl
    wget
    
    # Development Tools
    nodejs
    npm
    yarn
    python
    python-pip
    python-setuptools
    python-pynvim
    nodejs-neovim
    base-devel
    docker
    docker-compose
    cmake
    
    # System Utilities
    dunst
    libnotify
    thunar
    feh
    eza
    bat
    btop
    ripgrep
    unzip
    gparted
    xdg-utils
    xdg-user-dirs
    
    # File Management and Navigation
    fzf
    fd
    
    # System Tweaks and Configuration
    arcolinux-tweak-tool
    
    # Additional Tools
    timeshift
    timeshift-autosnap
    grub-btrfs
    btrbk
    
    # Fonts
    ttf-jetbrains-mono
)

# Function to verify packages
verify_packages() {
    print_section "📦 Verifying Package Installation"
    local failed=0
    
    for pkg in "${BASE_PACKAGES[@]}"; do
        progress "Checking $pkg"
        if ! pacman -Q "$pkg" &>/dev/null; then
            warn "Package $pkg not installed"
            failed=1
        else
            success "Found $pkg"
        fi
    done
    
    return $failed
}

# Function to verify AUR helper
verify_aur_helper() {
    print_section "🔧 Checking AUR Helper"
    
    if ! command -v yay &>/dev/null; then
        progress "Installing yay"
        git clone https://aur.archlinux.org/yay.git /tmp/yay
        (cd /tmp/yay && makepkg -si --noconfirm)
        rm -rf /tmp/yay
        success "Installed yay"
    else
        success "yay already installed"
    fi
}

# Function to configure services
configure_services() {
    print_section "🔧 Configuring Services"

    local services=(
        docker
        bluetooth
        cups
    )

    for service in "${services[@]}"; do
        progress "Enabling $service"
        sudo systemctl enable "$service" || warn "Failed to enable $service"
        success "Enabled $service"
    done

    # Add user to docker group
    sudo usermod -aG docker "$USER"
}

# Function to configure zram
configure_zram() {
    print_section "🔧 Configuring ZRAM"
    
    progress "Creating ZRAM configuration"
    sudo tee /etc/systemd/zram-generator.conf > /dev/null << EOF
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
EOF
    
    progress "Reloading systemd"
    sudo systemctl daemon-reload
    success "Configured ZRAM"
}

# Function to cleanup packages
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
    verify_aur_helper
    verify_packages
    configure_services
    configure_zram
    cleanup_packages
}

# Run the installation
install_arch
