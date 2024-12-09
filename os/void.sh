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
)

# Desktop environment specific packages
BSPWM_PACKAGES=(
    bspwm sxhkd polybar rofi picom
    dmenu
)

KDE_PACKAGES=(
    kde5
    kde5-baseapps
    plasma-desktop
    dolphin konsole
)

DWM_PACKAGES=(
    libX11-devel libXft-devel libXinerama-devel
    xorg
    make gcc
)

HYPRLAND_PACKAGES=(
    hyprland
    waybar wofi
    grim slurp
    wl-clipboard
)

# Function to enable non-free repository
enable_nonfree() {
    print_section "📦 Enabling Non-Free Repository"
    
    progress "Adding non-free repository"
    sudo xbps-install -Sy void-repo-nonfree > /dev/null 2>&1 || {
        error "Failed to enable non-free repository"
    }
    success "Enabled non-free repository"
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

# Function to install starship
install_starship() {
    print_section "📦 Installing Starship"
    
    progress "Downloading Starship installer"
    curl -sS https://starship.rs/install.sh | sh > /dev/null 2>&1 || {
        error "Failed to install Starship"
    }
    success "Installed Starship"
}

# Function to install DWM
install_dwm() {
    print_section "📦 Installing DWM"
    
    progress "Cloning DWM repository"
    git clone https://git.suckless.org/dwm /tmp/dwm || {
        error "Failed to clone DWM"
    }
    
    progress "Building DWM"
    (cd /tmp/dwm && sudo make clean install) > /dev/null 2>&1 || {
        error "Failed to build DWM"
    }
    
    rm -rf /tmp/dwm
    success "Built and installed DWM"
}

# Function to install Chrome
install_chrome() {
    print_section "📦 Installing Google Chrome"

    progress "Downloading Chrome"
    wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm -O /tmp/chrome.rpm || {
        error "Failed to download Chrome"
    }

    progress "Converting RPM to XBPS package"
    cd /tmp
    rpm2xbps chrome.rpm || {
        error "Failed to convert Chrome package"
    }

    progress "Installing Chrome"
    sudo xbps-rindex -a chrome.xbps
    sudo xbps-install -y chrome > /dev/null 2>&1 || {
        error "Failed to install Chrome"
    }

    rm -f /tmp/chrome.rpm /tmp/chrome.xbps
    success "Installed Google Chrome"
}

# Function to install packages
install_packages() {
    print_section "📦 Installing Packages"

    # Update system first
    progress "Updating system"
    sudo xbps-install -Su > /dev/null 2>&1 || {
        error "Failed to update system"
    }
    success "System updated"

    # Install base packages
    progress "Installing base packages"
    sudo xbps-install -Sy "${BASE_PACKAGES[@]}" > /dev/null 2>&1 || {
        error "Failed to install base packages"
    }
    success "Installed base packages"

    # Install DE-specific packages
    case "$DESKTOP_ENV" in
        "BSPWM")
            progress "Installing BSPWM packages"
            sudo xbps-install -y "${BSPWM_PACKAGES[@]}" > /dev/null 2>&1 || {
                error "Failed to install BSPWM packages"
            }
            success "Installed BSPWM packages"
            ;;
        "KDE")
            progress "Installing KDE packages"
            sudo xbps-install -y "${KDE_PACKAGES[@]}" > /dev/null 2>&1 || {
                error "Failed to install KDE packages"
            }
            success "Installed KDE packages"
            ;;
        "DWM")
            progress "Installing DWM dependencies"
            sudo xbps-install -y "${DWM_PACKAGES[@]}" > /dev/null 2>&1 || {
                error "Failed to install DWM dependencies"
            }
            install_dwm
            ;;
        "Hyprland")
            progress "Installing Hyprland packages"
            sudo xbps-install -y "${HYPRLAND_PACKAGES[@]}" > /dev/null 2>&1 || {
                error "Failed to install Hyprland packages"
            }
            success "Installed Hyprland packages"
            ;;
    esac

    # Install additional software
    install_chrome
    install_starship

    # Verify neovim version after installation
    check_neovim_version
}

# Function to configure services using runit
configure_services() {
    print_section "🔧 Configuring Services"

    local SERVICES=(
        NetworkManager
        sddm
        dbus
    )

    for service in "${SERVICES[@]}"; do
        progress "Enabling $service"
        sudo ln -s /etc/sv/$service /var/service/ > /dev/null 2>&1 || {
            warn "Failed to enable $service"
            continue
        }
        success "Enabled $service"
    done

    # Configure PipeWire
    progress "Configuring PipeWire"
    mkdir -p ~/.config/pipewire
    cp /usr/share/pipewire/*.conf ~/.config/pipewire/ > /dev/null 2>&1
    success "Configured PipeWire"
}

# Main Void installation function
install_void() {
    enable_nonfree
    install_packages
    configure_services
}

# Run the installation
install_void
