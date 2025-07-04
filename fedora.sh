#!/bin/bash
set -e

# Logging setup
LOG_FILE="/tmp/fedora-setup.log"
echo "==== Fedora Setup Started at $(date) ====" | tee -a "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1
trap 'echo "❌ Error on line $LINENO. Exiting." | tee -a "$LOG_FILE"; exit 1' ERR

# Ensure sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (sudo ./fedora-setup.sh)"
  exit 1
fi

USER_NAME=$(logname)
USER_HOME=$(eval echo ~$USER_NAME)

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

# Ensure pip3 is available now
if ! command -v pip3 &>/dev/null; then
  echo "pip3 is required but could not be installed. Please install python3-pip manually and rerun the script."
  exit 1
fi

# Install pywal manually
echo "==> Installing pywal..."
sudo -u $USER_NAME python3 -m pip install --user pywal || true

# Btrfs + Snapper setup
echo "==> Setting up Btrfs Snapper..."
install_if_missing btrfs-progs snapper

echo "==> Installing grub-btrfs..."
dnf copr enable -y kylegospo/grub-btrfs

# Remove timeshift version if present (they conflict)
if rpm -q grub-btrfs-timeshift &>/dev/null; then
  echo "Removing grub-btrfs-timeshift to avoid conflict..."
  dnf remove -y grub-btrfs-timeshift
fi

install_if_missing grub-btrfs
systemctl enable --now grub-btrfs.path

snapper -c root create-config /
systemctl enable --now snapper-cleanup.timer

# Install Btrfs Assistant
install_if_missing btrfs-assistant python3-dnf-plugin-snapper libdnf5-plugin-actions

# Configure DNF Snapper hooks
mkdir -p /etc/dnf/libdnf5-plugins/actions.d
cat <<EOF > /etc/dnf/libdnf5-plugins/actions.d/snapper.actions
# Get snapshot description
pre_transaction::::/usr/bin/sh -c echo\\ \"tmp.cmd=\\\$(ps\\ -o\\ command\\ --no-headers\\ -p\\ '\${pid}')\"
# Creates pre snapshot before the transaction and stores the snapshot number
pre_transaction::::/usr/bin/sh -c echo\\ \"tmp.snapper_pre_number=\\\$(snapper\\ create\\ -t\\ pre\\ -p\\ -d\\ '\${tmp.cmd}')\"
# Creates post snapshot if pre was created
post_transaction::::/usr/bin/sh -c [\\ -n\\ \"\${tmp.snapper_pre_number}\"\\ ]\\ \&\&\\ snapper\\ create\\ -t\\ post\\ --pre-number\\ \"\${tmp.snapper_pre_number}\"\\ -d\\ \"\${tmp.cmd}\"\\ \\;\\ echo\\ tmp.snapper_pre_number\\ \\;\\ echo\\ tmp.cmd
EOF

# Final snapshot
echo "==> Creating final snapshot before reboot..."
snapper -c root create --description "Post-install snapshot"

# Finish
echo "==> Fedora Setup Complete."
echo "Check log at: $LOG_FILE"
