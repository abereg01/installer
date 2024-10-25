#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to print colored output
print_status() {
    echo -e "${BLUE}[*]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[+]${NC} $1"
}

print_error() {
    echo -e "${RED}[-]${NC} $1"
}

# Function to check internet connection
check_internet() {
    print_status "Checking internet connection..."
    if ! ping -c 1 google.com &> /dev/null; then
        print_error "No internet connection. Please connect to the internet and try again."
        exit 1
    fi
}

# Function to install essential packages
install_base_packages() {
    print_status "Installing essential packages..."
    sudo pacman -Sy --needed --noconfirm \
        base-devel git curl wget
}

# Function to install yay
install_yay() {
    print_status "Installing yay..."
    if ! command -v yay &> /dev/null; then
        git clone https://aur.archlinux.org/yay.git /tmp/yay
        cd /tmp/yay
        makepkg -si --noconfirm
        cd -
        rm -rf /tmp/yay
    fi
}

# Function to clone repositories
clone_repos() {
    print_status "Creating directory structure..."
    mkdir -p "$HOME/lib/images"
    mkdir -p "$HOME/lib/scripts"
    mkdir -p "$HOME/.theme"
    
    print_status "Cloning repositories..."
    
    # Clone dotfiles
    git clone https://github.com/abereg01/dotfiles.git /tmp/dotfiles
    cd /tmp/dotfiles
    git checkout bspwm
    
    # Clone other repositories
    git clone https://github.com/abereg01/wallpapers.git "$HOME/lib/images"
    git clone https://github.com/abereg01/scripts.git "$HOME/lib/scripts"
    git clone https://github.com/abereg01/themes.git "$HOME/.theme"
}

# Function to install packages
install_packages() {
    print_status "Installing required packages..."
    
    # X.org and display related
    sudo pacman -S --needed --noconfirm \
        xorg xorg-xinit xorg-server \
        
    # Display Manager
    sudo pacman -S --needed --noconfirm \
        sddm
        
    # Window manager and core components
    sudo pacman -S --needed --noconfirm \
        bspwm sxhkd \
        picom \
        polybar \
        rofi \
        dunst \
        
    # Terminal and shell
    sudo pacman -S --needed --noconfirm \
        kitty \
        fish \
        starship \
        
    # Development tools
    sudo pacman -S --needed --noconfirm \
        neovim \
        python-pip \
        nodejs npm \
        
    # System utilities
    sudo pacman -S --needed --noconfirm \
        bat \
        btop \
        lf \
        cava \
        fzf \
        ripgrep \
        
    # Applications
    sudo pacman -S --needed --noconfirm \
        firefox
}

# Function to setup SDDM
setup_sddm() {
    print_status "Setting up SDDM..."
    
    # Create bspwm.desktop file
    sudo mkdir -p /usr/share/xsessions
    cat << EOF | sudo tee /usr/share/xsessions/bspwm.desktop
[Desktop Entry]
Name=bspwm
Comment=Binary space partitioning window manager
Exec=bspwm
Type=Application
EOF

    # Enable SDDM service
    sudo systemctl enable sddm.service
    
    # Optional: Install a theme for SDDM (you can choose a different theme)
    yay -S --needed --noconfirm sddm-theme-sugar-candy-git
    
    # Configure SDDM theme
    sudo mkdir -p /etc/sddm.conf.d
    cat << EOF | sudo tee /etc/sddm.conf.d/theme.conf
[Theme]
Current=sugar-candy
EOF
}

# Function to setup NvChad
setup_nvchad() {
    print_status "Setting up NvChad..."
    
    # Backup existing nvim config if it exists
    [ -d ~/.config/nvim ] && mv ~/.config/nvim ~/.config/nvim.bak
    
    # Install NvChad
    git clone https://github.com/NvChad/NvChad ~/.config/nvim --depth 1

    # Copy custom configuration
    mkdir -p ~/.config/nvim/lua/custom
    cp -r /tmp/dotfiles/nvim/lua/* ~/.config/nvim/lua/custom/
}

# Function to setup dotfiles
setup_dotfiles() {
    print_status "Setting up dotfiles..."
    
    # Create necessary directories
    mkdir -p ~/.config

    # Copy configurations
    configs=("bspwm" "sxhkd" "polybar" "rofi" "dunst" "kitty" "fish" "bat" "btop" "cava" "lf" "picom.conf" "starship.toml")
    
    for config in "${configs[@]}"; do
        if [ -e "/tmp/dotfiles/$config" ]; then
            print_status "Setting up $config..."
            cp -r "/tmp/dotfiles/$config" ~/.config/
        fi
    done

    # Make scripts executable
    chmod +x ~/.config/bspwm/bspwmrc
    chmod +x ~/.config/polybar/launch.sh
    chmod +x ~/.config/bspwm/bin/*

    # Setup Fish as default shell
    if ! grep -q "$(which fish)" /etc/shells; then
        echo "$(which fish)" | sudo tee -a /etc/shells
    fi
    chsh -s "$(which fish)"
}

# Function to set environment variables
setup_environment() {
    print_status "Setting up environment variables..."
    
    # Create or append to ~/.xprofile
    cat << EOF >> ~/.xprofile
# Environment variables
export TERMINAL=kitty
export BROWSER=firefox
export EDITOR=nvim

# Input method
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
EOF
}

# Function to clean up
cleanup() {
    print_status "Cleaning up..."
    rm -rf /tmp/dotfiles
}

# Main installation
main() {
    print_status "Starting fresh Arch Linux installation..."

    # Check internet connection
    check_internet

    # Install base packages and yay
    install_base_packages
    install_yay

    # Clone repositories
    clone_repos

    # Install packages
    install_packages

    # Setup SDDM
    setup_sddm

    # Setup dotfiles
    setup_dotfiles

    # Setup environment
    setup_environment

    # Setup NvChad
    setup_nvchad

    # Final steps
    print_status "Installing additional dependencies..."
    
    # Install Mason.nvim dependencies
    pip install --user pynvim
    npm install -g neovim

    # Cleanup
    cleanup

    print_success "Installation completed!"
    print_status "Please reboot your system to start with SDDM"
    print_status "After rebooting:"
    print_status "1. Log in through SDDM"
    print_status "2. Run 'nvim' to complete NvChad setup"
}

# Check if script is run as root
if [ "$(id -u)" = 0 ]; then
    print_error "This script should not be run as root"
    exit 1
fi

# Run the script
main
