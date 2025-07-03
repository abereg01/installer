# 🚀 System Configuration Installer

> 🎨 A beautiful, modern desktop environment setup for multiple Linux distributions

[![Made with Bash](https://img.shields.io/badge/Made%20with-Bash-1f425f.svg)](https://www.gnu.org/software/bash/)
[![Supports Arch](https://img.shields.io/badge/Supports-Arch-1793D1.svg?style=flat&logo=arch-linux)](https://archlinux.org/)
[![Supports Debian](https://img.shields.io/badge/Supports-Debian-A81D33.svg?style=flat&logo=debian)](https://www.debian.org/)
[![Supports Fedora](https://img.shields.io/badge/Supports-Fedora-294172.svg?style=flat&logo=fedora)](https://getfedora.org/)
[![Supports Void](https://img.shields.io/badge/Supports-Void-478061.svg?style=flat)](https://voidlinux.org/)

<div align="center">
  <img src="/api/placeholder/800/400" alt="Desktop Preview">
</div>

## ✨ Features

### 🖥️ Desktop Environments
- **[BSPWM](https://github.com/baskerville/bspwm)** - Minimal and powerful tiling window manager
- **[KDE Plasma](https://kde.org/plasma-desktop)** - Full-featured modern desktop
- **[DWM](https://dwm.suckless.org)** - Dynamic window manager for hackers
- **[Hyprland](https://hyprland.org)** - Beautiful Wayland compositor

### 🛠️ System Configuration
- 📁 Automated dotfiles management
- 📦 Intelligent package installation
- ⚙️ Service configuration
- 🔧 Repository setup

### 🎯 Pre-configured Software
| Category | Tools |
|----------|-------|
| 🔨 Development | `neovim`, `git`, `base-devel` |
| 📺 Terminal | `kitty`, `fish`, `starship` |
| 📊 Monitoring | `btop`, `neofetch` |
| 🎨 Customization | `picom`, `rofi`, `polybar` |

## 📋 Prerequisites

### 💻 System Requirements
- ✅ Fresh distribution installation
- 🌐 Active internet connection
- 💾 USB drive with SSH keys
- 👑 Sudo privileges

## 🚀 Installation

1. Clone with SSH for push access:
```bash
git clone git@github.com:yourusername/system-installer.git
cd system-installer
```

2. Make executable:
```bash
chmod +x install.sh
```

3. Launch:
```bash
./install.sh
```

## 🎨 Desktop Environments

### 🪟 BSPWM
- 📱 Minimal and efficient
- 🎯 Perfect for keyboard-driven workflow
- ⚡ Lightning fast

### 💫 KDE Plasma
- 🎨 Beautiful and customizable
- 🔧 Feature-rich
- 🖱️ User-friendly

### 🎯 DWM
- ⚡ Blazing fast
- 💪 Minimalist
- 🛠️ Highly hackable

### ✨ Hyprland
- 🌟 Modern animations
- 📱 Wayland native
- 🎮 GPU accelerated

## 📁 Final Directory Structure

## 🔧 Troubleshooting

### 🚨 Common Issues

#### 🔄 Service Issues
```bash
# systemd
systemctl status service-name

# runit
sv status service-name
```

#### 📦 Repository Problems
Distribution | Command
-------------|----------
![Arch](https://img.shields.io/badge/Arch-1793D1?logo=arch-linux) | `sudo pacman -Sy`
![Debian](https://img.shields.io/badge/Debian-A81D33?logo=debian) | `sudo apt update`
![Fedora](https://img.shields.io/badge/Fedora-294172?logo=fedora) | `sudo dnf check-update`
![Void](https://img.shields.io/badge/Void-478061) | `sudo xbps-install -S`

## 🤝 Contributing

1. 🔀 Fork the repository
2. 🌿 Create your feature branch
3. 💾 Commit your changes
4. 🚀 Push to the branch
5. ✨ Create a Pull Request

## 📜 License

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

<div align="center">
  
### 🌟 Star this repository if you find it helpful!

[![Made with ❤️](https://img.shields.io/badge/Made%20with-%E2%9D%A4%EF%B8%8F-red.svg)](https://github.com/yourusername)
</div>
