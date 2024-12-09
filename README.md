# System Configuration Installer

A comprehensive installer for setting up complete desktop environments across multiple Linux distributions. Currently supports Arch Linux, Debian/Ubuntu, Fedora, and Void Linux.

## Features

- 🖥️ Multiple desktop environment options:
  - BSPWM
  - KDE Plasma
  - DWM
  - Hyprland

- 🛠️ Complete system configuration:
  - Dotfiles management
  - Package installation
  - Service configuration
  - Repository setup

- 📦 Pre-configured software suite:
  - Development tools
  - Terminal utilities
  - System monitors
  - Desktop applications

## Prerequisites

### System Requirements
- A fresh installation of one of the supported distributions
- Internet connection
- USB drive with SSH keys
- Sudo privileges

### Required Directory Structure on USB
```
/path/to/usb/
└── secure/
    └── .ssh/
        ├── agent.env
        ├── config
        ├── id_ed25519_arch
        ├── id_ed25519_arch.pub
        ├── id_ed25519_work
        ├── id_ed25519_work.pub
        ├── known_hosts
        └── known_hosts.old
```

### Distribution-Specific Requirements

#### Arch Linux
- Base system installation
- Base-devel package group
- Network connectivity configured

#### Debian/Ubuntu
- Standard system installation
- build-essential package
- Network connectivity configured

#### Fedora
- Standard system installation
- Development Tools group
- Network connectivity configured

#### Void Linux
- Base system installation
- base-devel package
- Network connectivity configured

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/system-installer.git
cd system-installer
```

2. Make the installer executable:
```bash
chmod +x install.sh
```

3. Run the installer:
```bash
./install.sh
```

4. Follow the prompts to:
   - Provide USB drive path
   - Select desktop environment
   - Confirm system configuration

## Desktop Environments

### BSPWM
- Minimal tiling window manager
- Configured with:
  - Polybar
  - Rofi
  - Picom
  - SXHKD

### KDE Plasma
- Full-featured desktop environment
- Includes:
  - Plasma workspace
  - KDE applications
  - System settings

### DWM
- Dynamic window manager
- Built from source
- Minimal configuration

### Hyprland
- Wayland compositor
- Modern features
- Dynamic tiling

## Post-Installation

1. Log out of your current session

2. Start your chosen desktop environment:
   - BSPWM: `startx ~/.xinitrc bspwm`
   - KDE: Select from display manager
   - DWM: `startx ~/.xinitrc dwm`
   - Hyprland: `Hyprland`

3. Verify installations:
   - Check dotfiles in ~/.config
   - Test SSH key functionality
   - Verify service status

## Directory Structure After Installation

```
$HOME/
├── .config/           # Configuration files
├── dotfiles/         # Your dotfiles
├── lib/
│   ├── scripts/     # System scripts
│   └── images/      # Wallpapers
└── .themes/         # Theme files
```

## Troubleshooting

### Common Issues

1. SSH Key Problems
```bash
# Check SSH key permissions
chmod 600 ~/.ssh/id_*
chmod 644 ~/.ssh/*.pub
```

2. Service Issues
```bash
# Check service status (systemd)
systemctl status <service-name>

# Check service status (runit)
sv status <service-name>
```

3. Repository Problems
```bash
# Refresh package databases
# Arch
sudo pacman -Sy

# Debian/Ubuntu
sudo apt update

# Fedora
sudo dnf check-update

# Void
sudo xbps-install -S
```

### Distribution-Specific Notes

#### Arch Linux
- AUR helper (yay) is installed automatically
- Ensure multilib repository is enabled if needed

#### Debian/Ubuntu
- Some packages may require additional repositories
- Neovim 0.10+ requires unstable repository

#### Fedora
- RPM Fusion repositories are enabled automatically
- SELinux is set to permissive mode

#### Void Linux
- Non-free repository is enabled automatically
- Some packages may need to be built from source

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a new Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
