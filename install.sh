#!/bin/bash
# This script was made by Scooby. With borrowed code that has been heavily modified. 

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

sudo systemctl enable bluetooth
sudo systemctl enable cups

#getNF

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

#SUCKLESS
#cd && mkdir $HOME/.config/suckless && cd $HOME/.config/suckless/
#tools=( "dwm" "dmenu" "st" "slstatus" "slock" "tabbed" )
#for tool in ${tools[@]}
#do
#	git clone git://git.suckless.org/$tool
#	cd $HOME/.config/suckless/$tool;make;sudo make clean install;cd ..
#done
#
#cd && rm -rf $HOME/.config/suckless/

# SYMLINK SUCKLESS
# MAKE CLEAN INSTALL

# SYMLINK
# SYMLINK DOC




#Installer Removal
cd && rm -rf $HOME/XXXXX
echo 'Installation done. Reboot.'
