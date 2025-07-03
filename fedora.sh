#!/bin/bash
set -e

# Ensure sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (sudo ./fedora-setup.sh)"
  exit 1
fi

USER_NAME=$(logname)
USER_HOME=$(eval echo ~$USER_NAME)

# Check for pip before continuing
if ! command -v pip3 &>/dev/null; then
  echo "pip3 is required but not installed. Please install python3-pip manually and rerun the script."
  exit 1
fi

# Improve DNF performance
echo "==> Optimizing DNF..."
grep -q '^max_parallel_downloads=' /etc/dnf/dnf.conf || echo 'max_parallel_downloads=10' >> /etc/dnf/dnf.conf
grep -q '^fastestmirror=' /etc/dnf/dnf.conf || echo 'fastestmirror=True' >> /etc/dnf/dnf.conf

echo "==> Updating system..."
dnf update -y

install_if_missing() {
  for pkg in "$@"; do
    if ! rpm -q $pkg &>/dev/null; then
      dnf install -y $pkg
    fi
  done
}

group_install_if_missing() {
  for group in "$@"; do
    if ! dnf group list installed | grep -q "$group"; then
      dnf groupinstall -y "$group"
    fi
  done
}

# Install core tools
echo "==> Installing core tools..."
install_if_missing fish neovim git curl gcc wget unzip \
    network-manager-applet blueman rofi dunst picom udiskie \
    libnotify ripgrep feh ristretto ImageMagick python3-pip

# Install pywal manually (fallback)
echo "==> Installing pywal..."
sudo -u $USER_NAME python3 -m pip install --user pywal || true

# Btrfs + Snapper setup
echo "==> Setting up Btrfs Snapper..."
install_if_missing btrfs-progs snapper

echo "==> Installing grub-btrfs..."
dnf copr enable -y kylegospo/grub-btrfs
install_if_missing grub-btrfs grub-btrfs-timeshift
systemctl enable --now grub-btrfs.path

snapper -c root create-config /
systemctl enable --now snapper-cleanup.timer

# Install btrfs-assistant
install_if_missing btrfs-assistant python3-dnf-plugin-snapper libdnf5-plugin-actions

# Configure dnf5 Snapper actions
mkdir -p /etc/dnf/libdnf5-plugins/actions.d
cat <<EOF > /etc/dnf/libdnf5-plugins/actions.d/snapper.actions
# Get snapshot description
pre_transaction::::/usr/bin/sh -c echo\ "tmp.cmd=\$(ps\ -o\ command\ --no-headers\ -p\ '\${pid}')"
# Creates pre snapshot before the transaction and stores the snapshot number in the "tmp.snapper_pre_number"  variable.
pre_transaction::::/usr/bin/sh -c echo\ "tmp.snapper_pre_number=\$(snapper\ create\ -t\ pre\ -p\ -d\ '\${tmp.cmd}')"

# If the variable "tmp.snapper_pre_number" exists, it creates post snapshot after the transaction and removes the variable "tmp.snapper_pre_number".
post_transaction::::/usr/bin/sh -c [\ -n\ "\${tmp.snapper_pre_number}"\ ]\ \&\&\ snapper\ create\ -t\ post\ --pre-number\ "\${tmp.snapper_pre_number}"\ -d\ "\${tmp.cmd}"\ \;\ echo\ tmp.snapper_pre_number\ \;\ echo\ tmp.cmd
EOF

# Create final snapshot
echo "==> Creating final snapshot before reboot..."
snapper -c root create --description "Post-install snapshot"

# Hyprland stack
echo "==> Installing Hyprland + tools..."
dnf copr enable -y zirix/hyprland
install_if_missing hyprland hyprpaper waybar kitty

# BSPWM
echo "==> Installing BSPWM + sxhkd..."
install_if_missing bspwm sxhkd

# KDE Plasma (optional)
echo "==> Installing KDE Plasma..."
group_install_if_missing "KDE Plasma Workspaces"

# Display manager
echo "==> Installing SDDM display manager..."
install_if_missing sddm
dnf remove -y gdm || true
systemctl enable sddm --now

# AD and Evolution
echo "==> Installing AD + Evolution..."
install_if_missing realmd sssd adcli oddjob oddjob-mkhomedir samba-common-tools \
    evolution evolution-ews

# Libinput + gestures support
echo "==> Installing input/gesture support..."
install_if_missing gnome-keyring gnome-control-center libinput-tools

# Wallpaper daemon
echo "==> Installing swww..."
dnf copr enable -y lloydde/swww
install_if_missing swww

# Dev tools
echo "==> Installing dev tools..."
group_install_if_missing "Development Tools"
install_if_missing docker-compose direnv npm docker kubernetes-client cargo
systemctl enable --now docker
usermod -aG docker $USER_NAME

# Multimedia + RPMFusion
echo "==> Enabling RPM Fusion + multimedia support..."
install_if_missing fedora-workstation-repositories
dnf install -y \
  https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
group_install_if_missing Multimedia
install_if_missing libavcodec-freeworld

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
XDG_DESKTOP_DIR="$USER_HOME/"
XDG_DOWNLOAD_DIR="$USER_HOME/dls/"
XDG_TEMPLATES_DIR="$USER_HOME/lib/"
XDG_PUBLICSHARE_DIR="$USER_HOME/lib/"
XDG_DOCUMENTS_DIR="$USER_HOME/lib/"
XDG_MUSIC_DIR="$USER_HOME/lib/"
XDG_PICTURES_DIR="$USER_HOME/lib/images/"
XDG_VIDEOS_DIR="$USER_HOME/lib/"
EOF
chown $USER_NAME:$USER_NAME $USER_HOME/.config/user-dirs.dirs

# Install starship
echo "==> Installing starship..."
sudo -u $USER_NAME sh -c "curl -sS https://starship.rs/install.sh | sh -s -- -y"

# Build and install eza from source
echo "==> Building eza from source..."
sudo -u $USER_NAME git clone https://github.com/eza-community/eza.git $USER_HOME/eza
cd $USER_HOME/eza
sudo -u $USER_NAME cargo install --path .
cd ..
rm -rf $USER_HOME/eza

# Additional tools
echo "==> Installing misc apps..."
install_if_missing filezilla lazygit remmina vlc flatpak
sudo -u $USER_NAME flatpak --user remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
sudo -u $USER_NAME flatpak --user install -y flathub org.signal.Signal
flatpak install -y flathub com.spotify.Client
dnf install -y google-chrome-stable
install_if_missing librewolf

# SSH keygen
echo "==> Generating SSH key for GitHub... (ed25519)"
sudo -u $USER_NAME ssh-keygen -t ed25519 -C "$USER_NAME@$(hostname)" -f "$USER_HOME/.ssh/id_ed25519" -N ""
eval "$(ssh-agent -s)"
ssh-add "$USER_HOME/.ssh/id_ed25519"

# Final touches
echo "==> Finalizing setup..."
usermod -aG wheel $USER_NAME
chsh -s /usr/bin/fish $USER_NAME

echo
read -p "Login Screen (SDDM): Search and install 'Eucalyptus Drop' theme via 'Get New Theme'. Reboot now? [y/N]: " reboot_answer
if [[ "$reboot_answer" =~ ^[Yy]$ ]]; then
  reboot
else
  echo "Reboot later to finish setup."
fi

