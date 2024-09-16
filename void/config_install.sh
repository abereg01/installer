#!/bin/bash

source ./utils.sh

# Function to download wallpapers
download_wallpapers() {
    print_message "Downloading Wallpapers"
    git clone https://github.com/abereg01/wallpapers.git $HOME/wallpapers
}

# Function to setup dotfiles
setup_dotfiles() {
    print_message "Setting up dotfiles"
    git clone https://github.com/abereg01/dotfiles.git $HOME/dotfiles
    ln -sf $HOME/dotfiles/.config/* $HOME/.config/
    ln -sf $HOME/dotfiles/scripts/* $HOME/scripts/
    mkdir -p $HOME/.local/share
    ln -sf $HOME/dotfiles/.local/share/dwm/ $HOME/.local/share/
}

# Function to install and configure DWM
install_dwm() {
    print_message "Installing DWM"
    sudo mkdir -p /usr/share/xsessions
    cat > ./temp << "EOF"
[Desktop Entry]
Encoding=UTF-8
Name=dwm
Comment=Dynamic window manager
Exec=$HOME/dotfiles/.config/chadwm/scripts/./run.sh
Icon=dwm
Type=Application
EOF
    sudo mv ./temp /usr/share/xsessions/dwm.desktop
    cd $HOME/dotfiles/.config/suckless/dwm/ && sudo make clean install
}

# Function to install fonts
install_fonts() {
    print_message "Installing fonts"
    sudo xbps-install -y font-adobe-source-code-pro font-awesome font-fira-ttf \
        font-ibm-plex-ttf noto-fonts-ttf
    fc-cache -f -v
#    cd "$HOME"/scripts/getnf && ./getnf
#    rm -rf "$HOME"/NerdFonts
}

download_wallpapers
setup_dotfiles
install_dwm
install_fonts
