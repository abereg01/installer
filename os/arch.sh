#!/usr/bin/env bash

# Arch Linux specific installation script

# Base packages for all installations
BASE_PACKAGES=(
    base base-devel
    git curl wget
    networkmanager network-manager-applet
    pipewire pipewire-alsa pipewire-pulse pipewire-jack
    fish starship
    kitty alacritty
    neovim vim
    dunst libnotify
    thunar
    sddm
    feh eza bat btop ripgrep unzip
    # Development tools
    nodejs npm yarn
    python python-pip python-setuptools
    docker docker-compose
    gparted
    zram-generator
)

# Desktop environment specific packages
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

GNOME_PACKAGES=(
    gnome
    gnome-tweaks
    gnome-shell-extensions
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

# Check Arch Linux
check_arch_version() {
    print_section "🔍 Checking System Requirements"
    
    progress "Verifying system"
    if ! grep -q "Arch Linux" /etc/os-release; then
        error "This script requires Arch Linux"
    fi
    success "System requirements met"
}

# Configure pacman
configure_pacman() {
    print_section "🔧 Configuring Pacman"
    
    progress "Optimizing pacman configuration"
    sudo sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 10/' /etc/pacman.conf
    sudo sed -i 's/#Color/Color/' /etc/pacman.conf
    sudo sed -i 's/#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf
    
    success "Optimized pacman configuration"
}

# Function to check neovim version requirement
check_neovim_version() {
    print_section "🔍 Checking Neovim Version"
    
    progress "Verifying Neovim version"
    local nvim_version=$(nvim --version | head -n1 | cut -d ' ' -f2)
    local required_version="0.10.0"
    
    if [ "$(printf '%s\n' "$required_version" "$nvim_version" | sort -V | head -n1)" != "$required_version" ]; then
        error "Neovim version must be at least 0.10.0. Found version: $nvim_version"
    fi
    success "Neovim version requirement met: $nvim_version"
}

# Function to install yay
install_yay() {
    print_section "📦 Installing AUR Helper"
    
    if command -v yay &> /dev/null; then
        success "yay is already installed"
        return
    }

    progress "Cloning yay repository"
    git clone https://aur.archlinux.org/yay.git /tmp/yay || {
        error "Failed to clone yay"
    }
    
    progress "Building yay"
    (cd /tmp/yay && makepkg -si --noconfirm) || {
        error "Failed to build yay"
    }
    
    rm -rf /tmp/yay
    success "Installed yay successfully"
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
    
    systemctl daemon-reload
    success "Configured ZRAM"
}

# Function to update firmware
update_firmware() {
    print_section "🔄 Updating Firmware"
    
    progress "Installing fwupd"
    sudo pacman -S --needed --noconfirm fwupd
    
    progress "Checking for firmware updates"
    sudo fwupdmgr get-devices
    sudo fwupdmgr refresh
    sudo fwupdmgr get-updates
    
    progress "Installing firmware updates"
    sudo fwupdmgr update
    success "Firmware update complete"
}

# Function to install multimedia support
install_multimedia() {
    print_section "🎵 Installing Multimedia Support"
    
    progress "Installing multimedia packages"
    sudo pacman -S --needed --noconfirm \
        gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugins-ugly \
        gst-libav ffmpeg
        
    success "Installed multimedia codecs"
}

# Function to install development tools
install_dev_tools() {
    print_section "🛠️ Installing Development Tools"
    
    progress "Installing VS Code"
    yay -S --needed --noconfirm visual-studio-code-bin
    
    progress "Installing Python development tools"
    pip install --user pylint black mypy pytest
    
    progress "Installing Node.js development tools"
    npm install -g typescript ts-node eslint prettier
    
    success "Installed development tools"
}

# Function to install packages
install_packages() {
    print_section "📦 Installing Packages"

    # Update system first
    progress "Updating system"
    sudo pacman -Syu --noconfirm || {
        error "Failed to update system"
    }
    success "System updated"

    # Install base packages
    progress "Installing base packages"
    sudo pacman -S --needed --noconfirm "${BASE_PACKAGES[@]}" || {
        error "Failed to install base packages"
    }
    success "Installed base packages"

    # Install DE-specific packages
    case "$DESKTOP_ENV" in
        "BSPWM")
            progress "Installing BSPWM packages"
            sudo pacman -S --needed --noconfirm "${BSPWM_PACKAGES[@]}" || {
                error "Failed to install BSPWM packages"
            }
            success "Installed BSPWM packages"
            ;;
        "KDE")
            progress "Installing KDE packages"
            sudo pacman -S --needed --noconfirm "${KDE_PACKAGES[@]}" || {
                error "Failed to install KDE packages"
            }
            # Add GNOME for Microsoft365/AD integration
            progress "Installing GNOME for Microsoft365 integration"
            sudo pacman -S --needed --noconfirm "${GNOME_PACKAGES[@]}" || {
                warn "Failed to install GNOME components"
            }
            success "Installed KDE packages"
            ;;
        "DWM")
            progress "Installing DWM dependencies"
            sudo pacman -S --needed --noconfirm "${DWM_PACKAGES[@]}" || {
                error "Failed to install DWM dependencies"
            }
            success "Installed DWM dependencies"
            
            # Clone and build DWM
            progress "Building DWM"
            git clone https://git.suckless.org/dwm /tmp/dwm
            (cd /tmp/dwm && sudo make clean install) || {
                error "Failed to build DWM"
            }
            success "Built and installed DWM"
            ;;
        "Hyprland")
            progress "Installing Hyprland packages"
            sudo pacman -S --needed --noconfirm "${HYPRLAND_PACKAGES[@]}" || {
                error "Failed to install Hyprland packages"
            }
            success "Installed Hyprland packages"
            ;;
    esac

    # Install AUR packages
    install_yay
    
    progress "Installing AUR packages"
    yay -S --needed --noconfirm getnf notify-send.sh google-chrome || {
        warn "Some AUR packages failed to install"
    }
    success "Installed AUR packages"

    # Verify neovim version after installation
    check_neovim_version
}

# Function to configure services
configure_services() {
    print_section "🔧 Configuring Services"

    local SERVICES=(
        NetworkManager
        sddm
        pipewire-pulse
        docker
    )

    for service in "${SERVICES[@]}"; do
        progress "Enabling $service"
        sudo systemctl enable "$service" > /dev/null 2>&1 || {
            warn "Failed to enable $service"
            continue
        }
        success "Enabled $service"
    done
}

# Function to cleanup packages
cleanup_packages() {
    print_section "🧹 Cleaning Up"
    
    progress "Cleaning package cache"
    sudo pacman -Sc --noconfirm
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
install_arch
