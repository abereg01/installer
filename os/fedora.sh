#!/usr/bin/env bash

# Fedora specific installation script

# Minimum supported Fedora version
MIN_FEDORA_VERSION=41

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
    gparted
    zram-generator
    dnf-automatic
    # Development tools
    nodejs npm yarn
    python3-pip python3-devel
    podman podman-docker buildah
    chromium
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

GNOME_PACKAGES=(
    '@Workstation Product Environment'
    gnome-tweaks
    gnome-shell-extension-gsconnect
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

# Function to check Fedora version
check_fedora_version() {
    print_section "🔍 Checking Fedora Version"
    
    local current_version=$(rpm -E %fedora)
    if [ "$current_version" -lt "$MIN_FEDORA_VERSION" ]; then
        error "This script requires Fedora $MIN_FEDORA_VERSION or higher. Current version: $current_version"
        exit 1
    }
    success "Fedora version requirement met: $current_version"
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

# Function to setup additional repositories
setup_repositories() {
    print_section "📦 Setting Up Repositories"

    # Enable RPM Fusion repositories
    progress "Enabling RPM Fusion repositories"
    if ! sudo dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
                            https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm; then
        error "Failed to enable RPM Fusion repositories"
    fi
    success "Enabled RPM Fusion repositories"

    # Enable Copr repository for neovim nightly
    progress "Enabling Neovim repository"
    if ! sudo dnf copr enable -y agriffis/neovim-nightly; then
        error "Failed to enable Neovim repository"
    fi
    success "Enabled Neovim repository"

    # Add VSCode repository
    progress "Adding VSCode repository"
    if ! sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc; then
        error "Failed to import Microsoft key"
    fi
    if ! sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'; then
        error "Failed to add VSCode repository"
    fi
    success "Added VSCode repository"

    # Update package lists after adding repositories
    progress "Updating package lists"
    sudo dnf check-update || true  # This command returns 100 if updates are available
    success "Updated package lists"
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
    
    systemctl daemon-reload
    success "Configured ZRAM"
}

# Function to configure DNF
configure_dnf() {
    print_section "🔧 Configuring DNF"
    
    progress "Optimizing DNF configuration"
    echo 'max_parallel_downloads=10' | sudo tee -a /etc/dnf/dnf.conf
    echo 'fastestmirror=true' | sudo tee -a /etc/dnf/dnf.conf
    echo 'deltarpm=true' | sudo tee -a /etc/dnf/dnf.conf
    success "Optimized DNF configuration"
    
    progress "Configuring automatic updates"
    sudo systemctl enable --now dnf-automatic.timer
    success "Enabled automatic updates"
}

# Function to install multimedia codecs
install_multimedia_codecs() {
    print_section "🎵 Installing Multimedia Codecs"
    
    progress "Installing multimedia packages"
    sudo dnf groupupdate -y multimedia --setop="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin
    sudo dnf groupupdate -y sound-and-video
    success "Installed multimedia codecs"
}

# Function to update firmware
update_firmware() {
    print_section "🔄 Updating Firmware"
    
    progress "Installing fwupd"
    sudo dnf install -y fwupd
    
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
    sudo dnf install -y code
    
    progress "Installing Python development tools"
    pip install --user pylint black mypy pytest
    
    progress "Installing Node.js development tools"
    npm install -g typescript ts-node eslint prettier
    
    success "Installed development tools"
}

# Function to cleanup packages
cleanup_packages() {
    print_section "🧹 Cleaning Up"
    
    progress "Removing unused packages"
    sudo dnf autoremove -y
    
    progress "Cleaning DNF cache"
    sudo dnf clean all
    success "Cleanup complete"
}

# Function to install packages
install_packages() {
    print_section "📦 Installing Packages"

    # Update system first
    progress "Updating system"
    sudo dnf upgrade -y || {
        error "Failed to update system"
    }
    success "System updated"

    # Install base packages
    progress "Installing base packages"
    sudo dnf install -y "${BASE_PACKAGES[@]}" || {
        error "Failed to install base packages"
    }
    success "Installed base packages"

    # Install DE-specific packages
    case "$DESKTOP_ENV" in
        "BSPWM")
            progress "Installing BSPWM packages"
            sudo dnf install -y "${BSPWM_PACKAGES[@]}" || {
                error "Failed to install BSPWM packages"
            }
            success "Installed BSPWM packages"
            ;;
        "KDE")
            progress "Installing KDE packages"
            sudo dnf group install -y "${KDE_PACKAGES[@]}" || {
                error "Failed to install KDE packages"
            }
            # Add GNOME for Microsoft365/AD integration
            progress "Installing GNOME for Microsoft365 integration"
            sudo dnf group install -y "${GNOME_PACKAGES[@]}" || {
                warn "Failed to install GNOME components"
            }
            success "Installed KDE packages"
            ;;
        "DWM")
            progress "Installing DWM dependencies"
            sudo dnf install -y "${DWM_PACKAGES[@]}" || {
                error "Failed to install DWM dependencies"
            }
            install_dwm
            success "Installed DWM dependencies"
            ;;
        "Hyprland")
            progress "Installing Hyprland packages"
            sudo dnf install -y "${HYPRLAND_PACKAGES[@]}" || {
                error "Failed to install Hyprland packages"
            }
            success "Installed Hyprland packages"
            ;;
    esac

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

    # Configure PipeWire
    progress "Configuring PipeWire"
    systemctl --user --now enable pipewire pipewire-pulse
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
    check_fedora_version
    setup_repositories
    configure_dnf
    install_packages
    install_dev_tools
    install_multimedia_codecs
    configure_services
    configure_selinux
    configure_zram
    update_firmware
    cleanup_packages
}

# Run the installation
install_fedora
