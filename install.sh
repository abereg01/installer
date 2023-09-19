#!/bin/bash
#This script was made by Abereg01, with modifications from various sources.

echo 'Scooby Debian/DWM installation script'

#Base installation
sudo apt install -y \
	xorg xbacklight xbindkeys xvkbd xinput xorg-dev \
	build-essential intel-microcode network-manager-gnome \
	lxappearance dialog mtools dosfstools avahi-daemon acpi \
	acpid gvfs-ba ckends xfce4-power-manager

sudo systemctl enable avahi-daemon
sudo systemctl enable acpid

#Sources.list
sudo chmod +x $HOME/installer/installation_files/sourceslist.sh
sh $HOME/installer/installation_files/sourceslist.sh
sudo apt update

#Ly
cd && mkdir -p software/ly && cd software/ly/
sudo apt install -y libpam0g-dev libxcb-xkb-dev
git clone --recurse-submodules https://github.com/fairyglade/ly
make
sudo make install installsystmd
sudo systemctl enable ly.service

#Software
sudo apt install $(cat $HOME/installer/installation_files/pkglist | perl -pe 's|\n| |g') -y

#Pfetch
#Hitta install script

#Picom
#Hitta korrekt version

#Starship
curl -sS https://starship.rs/install.sh | sh

#Installer Removal
cd && rm -rf $HOME/XXXXX
echo 'Installation done. Reboot.'
