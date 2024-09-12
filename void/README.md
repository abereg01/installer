# 🚀 Void Linux Installation Script

## 📋 Overview

This set of scripts automates the installation and configuration process for a customized Void Linux system. It includes base system installation, additional software, and personal configurations.

## 🛠 Components

The installation process is divided into several scripts:

1. `main_install.sh`: The main script that orchestrates the entire installation process.
2. `utils.sh`: Contains utility functions used by other scripts.
3. `base_install.sh`: Installs the base Void Linux system.
4. `software_install.sh`: Installs additional software and utilities.
5. `config_install.sh`: Sets up personal configurations and dotfiles.

## 🔧 Features

- 📦 Base Void Linux system installation
- 🖥️ DWM (Dynamic Window Manager) setup
- 🎨 Personal dotfiles configuration
- 📱 Support for Apple Magic Trackpad
- 🔤 Custom font installation
- 🖼️ Wallpaper download
- ⌨️ Fish shell as default

## 🚀 Usage

1. Clone this repository:
   ```
   git clone https://github.com/abereg01/void/void-linux-install.git
   cd void-linux-install
   ```

2. Make all scripts executable:
   ```
   chmod +x *.sh
   ```

3. Run the main installation script:
   ```
   ./main_install.sh
   ```

⚠️ **Note**: This script will make significant changes to your system. Make sure to review each script and adjust according to your needs before running.

## 📋 Requirements

- A fresh Void Linux installation
- Internet connection
- Sudo privileges

## 🛠 Customization

You can customize the installation by modifying the following files:

- `software_install.sh`: Add or remove packages from the `packages` array.
- `config_install.sh`: Modify dotfiles repository URL and installation process.

## 📚 Post-Installation

After the installation is complete, the system will automatically reboot. Upon restart:

1. Log in using your user credentials.
2. The system should start with DWM as the window manager.
3. Check if all installed software is working correctly.
4. Customize further as needed.

## 🤝 Contributing

Feel free to fork this repository and submit pull requests with improvements or additional features.

## ⚖️ License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Void Linux community
- DWM developers
- All open-source software contributors included in this setup

---

🌟 Happy Void Linux customizing! 🌟
