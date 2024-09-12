#!/bin/bash

source ./utils.sh

# Function to install base system
install_base_system() {
    print_message "Installing Base System"
    sudo xbps-install -Syu
    sudo xbps-install -y xorg xbacklight xbindkeys xvkbd xinput xorg-server-devel base-devel \
        linux-headers intel-ucode networkmanager-openvpn network-manager-applet lxappearance \
        dialog mtools dosfstools avahi acpi acpid gvfs xfce4-power-manager curl wget
}

create_directories
install_base_system
