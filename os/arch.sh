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
    git clone https://aur.archlinux.org/yay.git /tmp/yay > /dev/null 2>&1 || {
        error "Failed to clone yay"
    }
    
    progress "Building yay"
    (cd /tmp/yay && makepkg -si --noconfirm) > /dev/null 2>&1 || {
        error "Failed to build yay"
    }
    
    rm -rf /tmp/yay
    success "Installed yay successfully"
}

# Function to install packages
install_packages() {
    print_section "📦 Installing Packages"

    # Update system first
    progress "Updating system"
    sudo pacman -Syu --noconfirm > /dev/null 2>&1 || {
        error "Failed to update system"
    }
    success "System updated"

    # Install base packages
    progress "Installing base packages"
    sudo pacman -S --needed --noconfirm "${BASE_PACKAGES[@]}" > /dev/null 2>&1 || {
        error "Failed to install base packages"
    }
    success "Installed base packages"

    # Install DE-specific packages
    case "$DESKTOP_ENV" in
        "BSPWM")
            progress "Installing BSPWM packages"
            sudo pacman -S --needed --noconfirm "${BSPWM_PACKAGES[@]}" > /dev/null 2>&1 || {
                error "Failed to install BSPWM packages"
            }
            success "Installed BSPWM packages"
            ;;
        "KDE")
            progress "Installing KDE packages"
            sudo pacman -S --needed --noconfirm "${KDE_PACKAGES[@]}" > /dev/null 2>&1 || {
                error "Failed to install KDE packages"
            }
            success "Installed KDE packages"
            ;;
        "DWM")
            progress "Installing DWM dependencies"
            sudo pacman -S --needed --noconfirm "${DWM_PACKAGES[@]}" > /dev/null 2>&1 || {
                error "Failed to install DWM dependencies"
            }
            success "Installed DWM dependencies"
            
            # Clone and build DWM
            progress "Building DWM"
            git clone https://git.suckless.org/dwm /tmp/dwm
            (cd /tmp/dwm && sudo make clean install) > /dev/null 2>&1 || {
                error "Failed to build DWM"
            }
            success "Built and installed DWM"
            ;;
        "Hyprland")
            progress "Installing Hyprland packages"
            sudo pacman -S --needed --noconfirm "${HYPRLAND_PACKAGES[@]}" > /dev/null 2>&1 || {
                error "Failed to install Hyprland packages"
            }
            success "Installed Hyprland packages"
            ;;
    esac

    # Install AUR packages
    install_yay
    
    progress "Installing AUR packages"
    yay -S --needed --noconfirm getnf notify-send.sh google-chrome > /dev/null 2>&1 || {
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

# Main Arch installation function
install_arch() {
    install_packages
    configure_services
}

# Run the installation
install_arch
