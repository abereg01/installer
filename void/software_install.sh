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

# Function to install Pfetch
install_pfetch() {
    print_message "Installing Pfetch"
    wget https://github.com/dylanaraps/pfetch/archive/master.zip
    unzip master.zip
    sudo install pfetch-master/pfetch /usr/local/bin/
    rm master.zip pfetch-master -rf
}

# Function to install Starship
install_starship() {
    print_message "Installing Starship"
    curl -sS https://starship.rs/install.sh | sh
}

install_additional_software
install_display_manager
install_pfetch
install_starship
