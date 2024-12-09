#!/usr/bin/env bash

# Debian/Ubuntu specific installation script

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

# Function to setup additional repositories
setup_repositories() {
    print_section "📦 Setting Up Repositories"

    # Add Fish shell repository
    progress "Adding Fish shell repository"
    sudo apt-add-repository ppa:fish-shell/release-3 -y > /dev/null 2>&1
    success "Added Fish shell repository"

    # Add Neovim repository
    progress "Adding Neovim repository"
    sudo add-apt-repository ppa:neovim-ppa/unstable -y > /dev/null 2>&1
    success "Added Neovim repository"

    # Setup Starship repository
    progress "Setting up Starship repository"
    curl -sS https://starship.rs/install.sh | sh > /dev/null 2>&1
    success "Setup Starship repository"

    # Add Kitty repository
    progress "Adding Kitty repository"
    curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin > /dev/null 2>&1
    success "Added Kitty repository"

    # Add eza (replacement for exa)
    progress "Setting up eza repository"
    sudo mkdir -p /etc/apt/keyrings
    wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/eza.gpg
    echo "deb [signed-by=/etc/apt/keyrings/eza.gpg] http://deb.debian.org/debian unstable main" | sudo tee /etc/apt/sources.list.d/eza.list
    success "Added eza repository"

    # Add Hyprland repository if selected
    if [ "$DESKTOP_ENV" = "Hyprland" ]; then
        progress "Adding Hyprland repository"
        sudo add-apt-repository ppa:hyprland-dev/ppa -y > /dev/null 2>&1
        success "Added Hyprland repository"
    fi

    # Update package lists after adding repositories
    progress "Updating package lists"
    sudo apt update > /dev/null 2>&1
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

# Function to install btop from source
install_btop() {
    print_section "📦 Installing btop"
    
    progress "Cloning btop repository"
    git clone https://github.com/aristocratos/btop.git /tmp/btop > /dev/null 2>&1 || {
        error "Failed to clone btop"
    }
    
    progress "Building btop"
    (cd /tmp/btop && make && sudo make install) > /dev/null 2>&1 || {
        error "Failed to build btop"
    }
    
    rm -rf /tmp/btop
    success "Installed btop successfully"
}

# Function to install Google Chrome
install_chrome() {
    print_section "📦 Installing Google Chrome"

    progress "Downloading Chrome package"
    wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/chrome.deb || {
        error "Failed to download Chrome"
    }

    progress "Installing Chrome"
    sudo dpkg -i /tmp/chrome.deb > /dev/null 2>&1 || {
        sudo apt-get install -f -y > /dev/null 2>&1
    }
    rm /tmp/chrome.deb
    success "Installed Google Chrome"
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
    sudo apt update && sudo apt upgrade -y > /dev/null 2>&1 || {
        error "Failed to update system"
    }
    success "System updated"

    # Install base packages
    progress "Installing base packages"
    sudo apt install -y "${BASE_PACKAGES[@]}" > /dev/null 2>&1 || {
        error "Failed to install base packages"
    }
    success "Installed base packages"

    # Install DE-specific packages
    case "$DESKTOP_ENV" in
        "BSPWM")
            progress "Installing BSPWM packages"
            sudo apt install -y "${BSPWM_PACKAGES[@]}" > /dev/null 2>&1 || {
                error "Failed to install BSPWM packages"
            }
            success "Installed BSPWM packages"
            ;;
        "KDE")
            progress "Installing KDE packages"
            sudo apt install -y "${KDE_PACKAGES[@]}" > /dev/null 2>&1 || {
                error "Failed to install KDE packages"
            }
            success "Installed KDE packages"
            ;;
        "DWM")
            progress "Installing DWM dependencies"
            sudo apt install -y "${DWM_PACKAGES[@]}" > /dev/null 2>&1 || {
                error "Failed to install DWM dependencies"
            }
            install_dwm
            ;;
        "Hyprland")
            progress "Installing Hyprland packages"
            sudo apt install -y "${HYPRLAND_PACKAGES[@]}" > /dev/null 2>&1 || {
                error "Failed to install Hyprland packages"
            }
            success "Installed Hyprland packages"
            ;;
    esac

    # Install additional software
    install_btop
    install_chrome

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

# Main Debian/Ubuntu installation function
install_debian() {
    setup_repositories
    install_packages
    configure_services
}

# Run the installation
install_debian
