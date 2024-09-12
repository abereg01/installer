#!/bin/bash

source ./utils.sh

# Function to install additional software
install_additional_software() {
    print_message "Installing Additional Software"
    packages=(
        dunst cava rofi ueberzug libnotify feh ristretto mpv ncmpcpp ytfzf 
        thunar zathura scrot mousepad fish-shell tty-clock samba htop eza unzip
        fzf sxhkd cups bluez blueman numlockx pulseaudio alsa-utils pavucontrol
        volumeicon fd neovim firefox vlc neovim flatpak bat zoxide 

        # Packages for Apple Magic Trackpad support
        bluez-utils xf86-input-mtrack 
    )
    for package in "${packages[@]}"; do
        install_package "$package"
    done
    sudo ln -s /etc/sv/bluetoothd /var/service/
    sudo ln -s /etc/sv/cupsd /var/service/
}

# Function to install and configure SLIM display manager
install_display_manager() {
    print_message "Installing Display Manager (SLIM)"
    install_package "slim"
    sudo ln -s /etc/sv/slim /var/service/
}

# Function to install Rxfetch
install_rxfetch() {
    print_message "Installing Pfetch"
    git clone https://github.com/mangeshrex/rxfetch
    cd rxfetch
    cp ttf-material-design-icons/* $HOME/.local/share/fonts
    fc-cache -fv
    sudo cp rxfetch /usr/local/bin
    cd ..
    rm -rf rxfetch
}

# Function to install Starship
install_starship() {
    print_message "Installing Starship"
    curl -sS https://starship.rs/install.sh | sh
}

install_additional_software
install_display_manager
install_rxfetch
install_starship
