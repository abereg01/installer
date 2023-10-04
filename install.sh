#!/bin/bash
echo 'Scooby installation script'

mkdir $HOME/.config/ $HOME/scripts/ $HOME/downloads

# Base installation
sudo apt install $(cat $HOME/installer/installation_files/base) curl wget -y
sudo systemctl enable avahi-daemon &
sudo systemctl enable acpid

# Sources.list
sudo chmod +x $HOME/installer/installation_files/sourceslist.sh &
sh $HOME/installer/installation_files/sourceslist.sh 
sudo apt update 

# Ly
cd && mkdir software/ && cd software/
sudo apt install -y libpam0g-dev libxcb-xkb-dev
git clone --recurse-submodules https://github.com/fairyglade/ly
cd ly/
make
make run
sudo make install installsystemd
sudo systemctl enable ly.service

# Software
#sudo apt install $(cat $HOME/installer/installation_files/pkglist) -y
#sudo systemctl enable bluetooth
#sudo systemctl enable cups

# Nvim
#sudo chmod +x $HOME/installer/installation_files/nvim.sh
#sh $HOME/installer/installation_files/nvim.sh

# Fonts & getNF
#sudo apt install -y fonts-recommended \
#fonts-ubuntu fonts-font-awesome fonts-terminus
#fc-cache -f -v

# Pfetch
#wget https://github.com/dylanaraps/pfetch/archive/master.zip
#unzip master.zip
#sudo install pfetch-master/pfetch /usr/local/bin/
#ls -l /usr/local/bin/pfetch
#rm master.zip

#Picom
#Hitta korrekt version

#Starship
#curl -sS https://starship.rs/install.sh | sh

# Wallpapers
#cd && git clone https://github.com/abereg01/wallpapers.git

# Symlink
#git clone https://github.com/abereg01/dotfiles.git
#ln -s $HOME/dotfiles/.config/* $HOME/.config/
#ln -s $HOME/dotfiles/scripts/ $HOME/scripts
# Xsession & DWM
#if [[ ! -d /usr/share/xsessions ]]; then
#       sudo mkdir /usr/share/xsessions
#fi
#
#cat > ./temp << "EOF"
#[Desktop Entry]
#Encoding=UTF-8
#Name=dwm
#Comment=Dynamic window manager
#Exec=dwm
#Icon=dwm
#Type=Xsession
#EOF
#sudo cp ./temp /usr/share/xsessions/dwm.desktop;rm ./temp
#
#cd $HOME/dotfiles/.config/suckless/dwm/ && sudo make clean install

#Installer Removal
#cd && rm -rf $HOME/installer/
echo 'Installation done. Reboot.'
