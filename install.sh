#!/bin/bash
clear
echo '##############################'
echo '# Scooby installation script #'
echo '##############################'
sleep 3

mkdir $HOME/.config/ $HOME/scripts/ $HOME/downloads

# Base installation
clear
echo '############################'
echo '#  Installing Base System  #'
echo '############################'
sleep 3
sudo apt install $(cat $HOME/installer/installation_files/base) curl wget -y
sudo systemctl enable avahi-daemon &
sudo systemctl enable acpid

# Ly
clear
echo '############################'
echo '#       Installing Ly      #'
echo '############################'
sleep 3
cd && mkdir software/ && cd software/
sudo apt install -y libpam0g-dev libxcb-xkb-dev
git clone --recurse-submodules https://github.com/fairyglade/ly
cd ly/
make
sudo make install installsystemd
sudo systemctl enable ly.service

# Software
clear
echo '############################'
echo '#    Installing Software   #'
echo '############################'
sleep 3
sudo apt update
sudo apt install $(cat $HOME/installer/installation_files/pkglist) -y

sudo systemctl enable bluetooth
sudo systemctl enable cups

# Fonts & getNF
clear
echo '############################'
echo '#     Installing fonts     #'
echo '############################'
sleep 3
sudo apt install -y fonts-recommended \
fonts-ubuntu fonts-font-awesome fonts-terminus
fc-cache -f -v

# Nvim
clear
echo '############################'
echo '#      Installing Nvim     #'
echo '############################'
sleep 3
sudo chmod +x $HOME/installer/installation_files/nvim.sh
sh $HOME/installer/installation_files/nvim.sh

# Pfetch
clear
echo '############################'
echo '#     Installing Pfetch    #'
echo '############################'
sleep 3
wget https://github.com/dylanaraps/pfetch/archive/master.zip
unzip master.zip
sudo install pfetch-master/pfetch /usr/local/bin/
ls -l /usr/local/bin/pfetch
rm master.zip

#Picom
#Hitta korrekt version

#Starship
clear
echo '############################'
echo '#    Installing Starship   #'
echo '############################'
sleep 3
curl -sS https://starship.rs/install.sh | sh

# Wallpapers
clear
echo '############################'
echo '#  Downloading Wallpapers  #'
echo '############################'
sleep 3
cd && git clone https://github.com/abereg01/wallpapers.git

# Symlink
clear
echo '############################'
echo '#     Creating Symlinks    #'
echo '############################'
sleep 3
git clone https://github.com/abereg01/dotfiles.git
ln -s $HOME/dotfiles/.config/* $HOME/.config/
ln -s $HOME/dotfiles/scripts/* $HOME/scripts/
ln -s $HOME/dotfiles/.local/share/dwm/ $HOME/.local/share/

#Xsession & DWM
clear
echo '############################'
echo '#      Installing DWM      #'
echo '############################'
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

cd $HOME/dotfiles/.config/suckless/dwm/ && sudo make clean install

chsh -s `which fish`

# Prop Software
#clear
#echo 'Adding Sources'
#sleep 3
#chmod +x $HOME/installer/installation_files/sourceslist.sh &
#sh $HOME/installer/installation_files/sourceslist.sh 

#sudo apt update 
sudo apt install $(cat $HOME/installer/installation_files/prop_software) -y

#Installer Removal
cd && rm -rf $HOME/installer/
clear
# git clone https://github.com/abereg01
echo '#################################'
echo '# Installation done. Rebooting. #'
echo '#################################'
sleep 2
sudo reboot
