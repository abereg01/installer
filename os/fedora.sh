#!/usr/bin/env bash

# Fedora specific installation script

# Base packages for all installations
BASE_PACKAGES=(
    '@Development Tools'
    git curl wget
    NetworkManager network-manager-applet
    pipewire pipewire-alsa pipewire-pulseaudio pipewire-jack-audio-connection-kit
    fish starship
    kitty
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
    '@KDE Plasma Workstation'
    kde-apps
    plasma-workspace
)

DWM_PACKAGES=(
    libX11-devel libXft-devel libXinerama-devel
    xorg-x11-server-Xorg xorg-x11-xinit
    make gcc
)

HYPRLAND_PACKAGES=(
    hyprland
    waybar wofi
    grim slurp
    wl-clipboard
)

# Function to setup additional repositories
setup_repositories() {
    print_section "📦 Setting Up Repositories"

    # Enable RPM Fusion repositories
    progress "Enabling RPM Fusion repositories"
    sudo dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
                       https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm \
                       > /dev/null 2>&1
    success "Enabled RPM Fusion repositories"

    # Enable Copr repository for neovim nightly
    progress "Enabling Neovim repository"
    sudo dnf copr enable -y agriffis/neovim-nightly > /dev/null 2>&1
    success "Enabled Neovim repository"

    # Add VSCode repository
    progress "Adding VSCode repository"
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
    success "Added VSCode repository"

    # Add Google Chrome repository
    progress "Adding Google Chrome repository"
    sudo dnf config-manager --set-enabled google-chrome > /dev/null 2>&1
    success "Added Google Chrome repository"

    # Update package lists after adding repositories
    progress "Updating package lists"
    sudo dnf check-update > /dev/null 2>&1
    success "Updated package lists"
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

# Function to install packages
install_packages() {
    print_section "📦 Installing Packages"

    # Update system first
    progress "Updating system"
    sudo dnf upgrade -y > /dev/null 2>&1 || {
        error "Failed to update system"
    }
    success "System updated"

    # Install base packages
    progress "Installing base packages"
    sudo dnf install -y "${BASE_PACKAGES[@]}" > /dev/null 2>&1 || {
        error "Failed to install base packages"
    }
    success "Installed base packages"

    # Install DE-specific packages
    case "$DESKTOP_ENV" in
        "BSPWM")
            progress "Installing BSPWM packages"
            sudo dnf install -y "${BSPWM_PACKAGES[@]}" > /dev/null 2>&1 || {
                error "Failed to install BSPWM packages"
            }
            success "Installed BSPWM packages"
            ;;
        "KDE")
            progress "Installing KDE packages"
            sudo dnf group install -y "${KDE_PACKAGES[@]}" > /dev/null 2>&1 || {
                error "Failed to install KDE packages"
            }
            success "Installed KDE packages"
            ;;
        "DWM")
            progress "Installing DWM dependencies"
            sudo dnf install -y "${DWM_PACKAGES[@]}" > /dev/null 2>&1 || {
                error "Failed to install DWM dependencies"
            }
            install_dwm
            ;;
        "Hyprland")
            progress "Installing Hyprland packages"
            sudo dnf install -y "${HYPRLAND_PACKAGES[@]}" > /dev/null 2>&1 || {
                error "Failed to install Hyprland packages"
            }
            success "Installed Hyprland packages"
            ;;
    esac

    # Install Google Chrome
    progress "Installing Google Chrome"
    sudo dnf install -y google-chrome-stable > /dev/null 2>&1 || {
        warn "Failed to install Google Chrome"
    }
    success "Installed Google Chrome"

    # Verify neovim version after installation
    check_neovim_version
}

# Function to configure services
configure_services() {
    print_section "🔧 Configuring Services"

    local SERVICES=(
        NetworkManager
        sddm
    )

    for service in "${SERVICES[@]}"; do
        progress "Enabling $service"
        sudo systemctl enable "$service" > /dev/null 2>&1 || {
            warn "Failed to enable $service"
            continue
        }
        success "Enabled $service"
    done

    # Configure PipeWire
    progress "Configuring PipeWire"
    systemctl --user --now enable pipewire pipewire-pulse > /dev/null 2>&1
    success "Configured PipeWire"
}

# Function to configure SELinux
configure_selinux() {
    print_section "🔒 Configuring SELinux"
    
    progress "Setting SELinux to permissive mode"
    sudo setenforce 0
    sudo sed -i 's/^SELINUX=.*$/SELINUX=permissive/' /etc/selinux/config
    success "Set SELinux to permissive mode"
}

# Main Fedora installation function
install_fedora() {
    setup_repositories
    install_packages
    configure_services
    configure_selinux
}

# Run the installation
install_fedora
