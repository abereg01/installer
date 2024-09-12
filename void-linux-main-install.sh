#!/bin/bash

set -e

# Source utility functions
source ./utils.sh

# Main installation function
main_installation() {
    print_message "Starting Void Linux Installation"
    
    # Run individual installation scripts
    bash ./base_install.sh
    bash ./software_install.sh
    bash ./config_install.sh

    # Change default shell to fish
    chsh -s "$(which fish)"

    print_message "Installation Complete!"
    echo "The system will reboot in 5 seconds..."
    sleep 5
    sudo reboot
}

# Run the main installation
main_installation
