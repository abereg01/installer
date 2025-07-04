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

snapper -c root create-config /
systemctl enable --now snapper-cleanup.timer

# Install grub-btrfs
echo "==> Installing grub-btrfs..."
dnf copr enable -y kylegospo/grub-btrfs
install_if_missing grub-btrfs

# Ensure .snapshots mount exists
echo "==> Ensuring .snapshots subvolume exists..."
SNAPSHOT_MOUNTPOINT="/.snapshots"
if [ ! -d "$SNAPSHOT_MOUNTPOINT" ]; then
  mkdir -p "$SNAPSHOT_MOUNTPOINT"
  ROOT_PART=$(findmnt -n -o SOURCE /)
  btrfs subvolume create /.snapshots || true
  echo "$ROOT_PART /.snapshots btrfs subvol=.snapshots,defaults 0 0" >> /etc/fstab
  mount /.snapshots
fi

echo "==> Enabling grub-btrfs.path..."
systemctl enable --now grub-btrfs.path

# Install btrfs-assistant and dnf5 plugin
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

# Remaining install steps follow unchanged...


# Finish
echo "==> Fedora Setup Complete."
echo "Check log at: $LOG_FILE"
