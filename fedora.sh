#!/bin/bash
set -e

LOG_FILE="/tmp/fedora-setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1
trap 'echo "❌ Error on line $LINENO. Exiting."; exit 1' ERR

# Ensure sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (sudo ./fedora-setup.sh)"
  exit 1
fi

USER_NAME=$(logname)
USER_HOME=$(eval echo ~$USER_NAME)

# Ensure python3-pip exists early
echo "==> Ensuring python3-pip is available..."
dnf install -y python3-pip

# Verify pip3 module works
echo "==> Checking for pip3 module..."
if ! python3 -m pip --version &>/dev/null; then
  echo "❌ pip3 module is missing or broken. Install with: sudo dnf install -y python3-pip"
  exit 1
fi

# Optimize DNF
echo "==> Optimizing DNF..."
grep -q '^max_parallel_downloads=' /etc/dnf/dnf.conf || echo 'max_parallel_downloads=10' >> /etc/dnf/dnf.conf
grep -q '^fastestmirror=' /etc/dnf/dnf.conf || echo 'fastestmirror=True' >> /etc/dnf/dnf.conf

# Update system
echo "==> Updating system..."
dnf update -y

# Install helpers
install_if_missing() {
  for pkg in "$@"; do
    if ! rpm -q "$pkg" &>/dev/null; then
      echo "Installing $pkg..."
      dnf install -y "$pkg"
    else
      echo "Skipping $pkg (already installed)"
    fi
  done
}

group_install_if_missing() {
  for group in "$@"; do
    if ! dnf group list installed | grep -q "$group"; then
      dnf groupinstall -y "$group"
    else
      echo "Skipping group $group (already installed)"
    fi
  done
}

# Core packages
echo "==> Installing core tools..."
install_if_missing fish neovim git curl gcc wget unzip \
  network-manager-applet blueman rofi dunst picom udiskie \
  libnotify ripgrep feh ristretto ImageMagick

# Pywal
echo "==> Installing pywal..."
sudo -u $USER_NAME python3 -m pip install --user pywal || true

# Btrfs Snapper
echo "==> Setting up Btrfs Snapper..."
install_if_missing btrfs-progs snapper

if [ ! -f /etc/snapper/configs/root ]; then
  snapper -c root create-config /
else
  echo "Snapper config already exists, skipping..."
fi

systemctl enable --now snapper-cleanup.timer

# grub-btrfs
echo "==> Installing grub-btrfs..."
dnf copr enable -y kylegospo/grub-btrfs
install_if_missing grub-btrfs

# ✅ SKIP manual .snapshots mount setup
echo "==> Skipping manual .snapshots creation and mount (handled by snapper)..."

# grub-btrfs.path
echo "==> Enabling grub-btrfs.path..."
systemctl enable --now grub-btrfs.path || true

# Btrfs Assistant & Snapper plugin
install_if_missing btrfs-assistant python3-dnf-plugin-snapper libdnf5-plugin-actions

# Snapper plugin actions
echo "==> Configuring dnf Snapper plugin..."
mkdir -p /etc/dnf/libdnf5-plugins/actions.d
cat <<EOF > /etc/dnf/libdnf5-plugins/actions.d/snapper.actions
# Get snapshot description
pre_transaction::::/usr/bin/sh -c echo\ "tmp.cmd=\$(ps\ -o\ command\ --no-headers\ -p\ '\${pid}')"
# Creates pre snapshot before the transaction and stores the snapshot number
pre_transaction::::/usr/bin/sh -c echo\ "tmp.snapper_pre_number=\$(snapper\ create\ -t\ pre\ -p\ -d\ '\${tmp.cmd}')"
# Creates post snapshot after the transaction
post_transaction::::/usr/bin/sh -c [\ -n\ "\${tmp.snapper_pre_number}"\ ]\ \&\&\ snapper\ create\ -t\ post\ --pre-number\ "\${tmp.snapper_pre_number}"\ -d\ "\${tmp.cmd}"\ \;\ echo\ tmp.snapper_pre_number\ \;\ echo\ tmp.cmd
EOF

# Final post-install snapshot
echo "==> Creating final snapshot before reboot..."
snapper -c root create --description "Post-install snapshot"

echo "✅ Fedora setup completed successfully."
echo "You can view the full log at: $LOG_FILE"
