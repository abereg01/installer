#!/bin/bash
# This script was made by Scooby. With borrowed code that has been heavily modified. 

echo 'Scooby Debian/DWM installation script'

#Base installation
sudo apt install $(cat $HOME/installer/installation_files/-y

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
sudo apt install $(cat $HOME/installer/installation_files/pkglist) -y
sudo systemctl enable bluetooth
sudo systemctl enable cups

# Nvim
sudo chmod +x $HOME/installer/installation_files/nvim.sh
sh $HOME/installer/installation_files/nvim.sh

#getNF
# launch getNF
#sudo apt install sudo apt install -y fonts-recommended fonts-ubuntu fonts-font-awesome fonts-terminus
# fc-cache -f -v

#Pfetch
#Hitta install script

#Picom
#Hitta korrekt version

#Starship
curl -sS https://starship.rs/install.sh | sh


# Xsession & DWM
if [[ ! -d /usr/share/xsessions ]]; then
	sudo mkdir /usr/share/xsessions
fi

cat > ./temp << "EOF"
[Desktop Entry]
Encoding=UTF-8
Name=dwm
Comment=Dynamic window manager
Exec=dwm
Icon=dwm
Type=Xsession
EOF
sudo cp ./temp /usr/share/xsessions/dwm.desktop;rm ./temp

# Symlink
cd $HOME/dotfiles/.config/suckless/dwm/ && sudo make clean install

#Installer Removal
cd && rm -rf $HOME/XXXXX
echo 'Installation done. Reboot.'
