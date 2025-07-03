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
    polkit-gnome libnotify ripgrep

# Install pywal for ricing
echo "==> Installing pywal..."
dnf install -y python3-pywal

# Btrfs + Snapper setup
echo "==> Setting up Btrfs Snapper..."
dnf install -y btrfs-progs snapper grub-btrfs snapper-gui
snapper -c root create-config /
systemctl enable --now snapper-timeline.timer snapper-cleanup.timer
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
dnf remove -y gdm || true
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
sudo dnf install -y libavcodec-freeworld

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

