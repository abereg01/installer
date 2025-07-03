#!/bin/bash
set -e

# Ensure sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (sudo ./fedora-setup.sh)"
  exit 1
fi

USER_NAME=$(logname)
USER_HOME=$(eval echo ~$USER_NAME)

# Improve DNF performance
echo "==> Optimizing DNF..."
cat <<EOF >> /etc/dnf/dnf.conf
max_parallel_downloads=10
fastestmirror=True
EOF

echo "==> Updating system..."
dnf update -y

# Install core tools
echo "==> Installing core tools..."
dnf install -y fish neovim git curl gcc wget unzip stow \
    network-manager-applet blueman rofi dunst picom udiskie \
    polkit-gnome libnotify ripgrep feh ristretto imagemagick

# Install pywal manually (fallback)
echo "==> Installing pywal..."
sudo -u $USER_NAME python3 -m pip install --user pywal

# Btrfs + Snapper setup
echo "==> Setting up Btrfs Snapper..."
dnf install -y btrfs-progs snapper grub-btrfs snapper-gui
snapper -c root create-config /
systemctl enable --now snapper-timeline.timer snapper-cleanup.timer

# Configure snapper retention
cat <<EOF > /etc/snapper/configs/root
SUBVOLUME="/"
FSTYPE="btrfs"
ALLOW_USERS="$USER_NAME"
TIMELINE_CREATE="yes"
TIMELINE_CLEANUP="yes"
TIMELINE_LIMIT_HOURLY="0"
TIMELINE_LIMIT_DAILY="2"
TIMELINE_LIMIT_WEEKLY="1"
TIMELINE_LIMIT_MONTHLY="0"
TIMELINE_LIMIT_YEARLY="0"
NUMBER_CLEANUP="yes"
NUMBER_MIN_AGE="1800"
NUMBER_LIMIT="10"
EOF

# Force snapshot before reboot
echo "==> Creating final snapshot before reboot..."
snapper -c root create --description "Post-install snapshot"

grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg

# Hyprland stack
echo "==> Installing Hyprland + tools..."
dnf copr enable -y zirix/hyprland
dnf install -y hyprland hyprpaper waybar kitty

# BSPWM
echo "==> Installing BSPWM + sxhkd..."
dnf install -y bspwm sxhkd

# KDE Plasma (optional)
echo "==> Installing KDE Plasma..."
dnf groupinstall -y "KDE Plasma Workspaces"

# Display managers
echo "==> Installing SDDM display manager..."
dnf install -y sddm
systemctl enable sddm --now

# AD and Evolution
echo "==> Installing AD + Evolution..."
dnf install -y realmd sssd adcli oddjob oddjob-mkhomedir samba-common-tools \
    evolution evolution-ews

# Libinput + gestures support
echo "==> Installing input/gesture support..."
dnf install -y gnome-keyring gnome-control-center libinput-tools

# Wallpaper daemon
echo "==> Installing swww..."
dnf copr enable -y lloydde/swww
dnf install -y swww

# Dev tools
echo "==> Installing dev tools..."
dnf groupinstall -y "Development Tools"
dnf install -y docker-compose direnv npm docker kubernetes-client cargo
systemctl enable --now docker
usermod -aG docker $USER_NAME

# Multimedia support + RPMFusion
echo "==> Enabling RPM Fusion + multimedia support..."
dnf install -y \
  https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

dnf group install -y Multimedia
dnf install -y libavcodec-freeworld

# Apps: SSH, filezilla, lazygit, remmina, vlc
echo "==> Installing common apps..."
dnf install -y openssh openssh-clients filezilla lazygit remmina vlc

# Flatpak: Signal, Spotify
echo "==> Installing Flatpak apps..."
dnf install -y flatpak
sudo -u $USER_NAME flatpak --user remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
sudo -u $USER_NAME flatpak --user install -y flathub org.signal.Signal
sudo -u $USER_NAME flatpak install -y flathub com.spotify.Client

# Google Chrome and LibreWolf
echo "==> Installing Chrome and LibreWolf..."
dnf install -y fedora-workstation-repositories
dnf config-manager --set-enabled google-chrome
dnf install -y google-chrome-stable librewolf

# Clone dotfiles
echo "==> Cloning dotfiles..."
sudo -u $USER_NAME git clone https://github.com/abereg01/dotfiles.git $USER_HOME/dotfiles

# Symlink .config entries
echo "==> Symlinking config files..."
mkdir -p $USER_HOME/.config
for d in $USER_HOME/dotfiles/configs/*; do
  base=$(basename "$d")
  ln -sf "$d" "$USER_HOME/.config/$base"
done
chown -R $USER_NAME:$USER_NAME $USER_HOME/.config

# Set user-dirs.dirs
echo "==> Setting user directories..."
cat <<EOF > $USER_HOME/.config/user-dirs.dirs
XDG_DESKTOP_DIR=\"$USER_HOME/\"
XDG_DOWNLOAD_DIR=\"$USER_HOME/dls/\"
XDG_TEMPLATES_DIR=\"$USER_HOME/lib/\"
XDG_PUBLICSHARE_DIR=\"$USER_HOME/lib/\"
XDG_DOCUMENTS_DIR=\"$USER_HOME/lib/\"
XDG_MUSIC_DIR=\"$USER_HOME/lib/\"
XDG_PICTURES_DIR=\"$USER_HOME/lib/images/\"
XDG_VIDEOS_DIR=\"$USER_HOME/lib/\"
EOF
chown $USER_NAME:$USER_NAME $USER_HOME/.config/user-dirs.dirs

# Install starship manually
sudo -u $USER_NAME sh -c "curl -sS https://starship.rs/install.sh | sh -s -- -y"

# Build and install eza from source
echo "==> Building eza from source..."
sudo -u $USER_NAME git clone https://github.com/eza-community/eza.git $USER_HOME/eza
cd $USER_HOME/eza
sudo -u $USER_NAME cargo install --path .
cd ..
rm -rf $USER_HOME/eza

# SSH key generation for GitHub
if [ ! -f "$USER_HOME/.ssh/id_ed25519" ]; then
  echo "==> Generating SSH key for GitHub (ed25519)..."
  sudo -u $USER_NAME ssh-keygen -t ed25519 -C "$USER_NAME@$(hostname)"
  eval "$(ssh-agent -s)"
  ssh-add "$USER_HOME/.ssh/id_ed25519"
  echo "SSH key generated. Add the following to your GitHub account:"
  cat "$USER_HOME/.ssh/id_ed25519.pub"
  read -p "Press enter when you've added the key to GitHub..."
fi

# Final touches
echo "==> Final system tweaks..."
usermod -aG wheel $USER_NAME
chsh -s /usr/bin/fish $USER_NAME

# Final message
echo "==> Setup complete."
echo
read -p "Login Screen (SDDM): Search and install \"Eucalyptus Drop\" theme via 'Get New Theme'. Do you want to reboot now? [y/N]: " reboot_answer
if [[ "$reboot_answer" =~ ^[Yy]$ ]]; then
  reboot
else
  echo "Reboot later to finish setup."
fi

