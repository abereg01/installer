#!/usr/bin/env bash

# Script version
VERSION="1.0.0"

# Colors and styling
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
ITALIC='\033[3m'
NC='\033[0m'

# Unicode symbols
CHECK_MARK="\033[0;32m✓\033[0m"
CROSS_MARK="\033[0;31m✗\033[0m"
ARROW="→"
GEAR="⚙"
WARNING="⚠"

# Get terminal width
TERM_WIDTH=$(tput cols)

# Function to print centered text
print_centered() {
    local text="$1"
    local width=$((($TERM_WIDTH - ${#text}) / 2))
    printf "%${width}s%s%${width}s\n" "" "$text" ""
}

# Function to print header
print_header() {
    clear
    echo
    echo -e "${BOLD}${BLUE}"
    print_centered "╔══════════════════════════════════════════════╗"
    print_centered "║        Arch Linux BTRFS Setup Script         ║"
    print_centered "║                v${VERSION}                        ║"
    print_centered "╚══════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo
}

# Function to print section header
print_section() {
    echo
    echo -e "${CYAN}${BOLD}$1${NC}"
    echo -e "${DIM}$(printf '%.s─' $(seq 1 $TERM_WIDTH))${NC}"
}

# Progress and status functions
progress() {
    echo -ne "${ITALIC}${DIM}$1...${NC}"
}

success() {
    echo -e "\r${CHECK_MARK} $1"
}

error() {
    echo -e "\r${CROSS_MARK} ${RED}ERROR:${NC} $1"
    if [ "$2" != "no_exit" ]; then
        exit 1
    fi
}

warn() {
    echo -e "\r${WARNING} ${YELLOW}WARNING:${NC} $1"
}

# Function to check if script is run as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "Please run as root"
    fi
}

# Function to check disk size using lsblk
check_disk_size() {
    local disk=$1
    local min_size=30 # 30GB

    # Get size in GB using lsblk
    local size=$(lsblk -b -dn -o SIZE "$disk" | awk '{ print int($1/1024/1024/1024) }')
    
    if [ "$size" -lt "$min_size" ]; then
        error "Disk $disk is smaller than 30GB (size: ${size}GB)" "no_exit"
        return 1
    fi
    return 0
}

# Disk selection function
select_disks() {
    print_section "💽 Disk Selection"
    
    # Get available disks and store in array
    echo -e "\n${BLUE}${BOLD}Available disks:${NC}"
    declare -a DISKS
    while IFS= read -r line; do
        DISKS+=("$line")
    done < <(lsblk -d -e 7,11 -o NAME,SIZE,MODEL | tail -n +2)

    # Print available disks with numbers
    for i in "${!DISKS[@]}"; do
        echo -e "$((i+1))) ${DISKS[$i]}"
    done
    echo

    # Select root disk
    while true; do
        read -p "$(echo -e "${BOLD}${BLUE}$ARROW${NC} Choose disk number for root system (@): ")" ROOT_CHOICE
        if ! [[ "$ROOT_CHOICE" =~ ^[0-9]+$ ]] || [ "$ROOT_CHOICE" -lt 1 ] || [ "$ROOT_CHOICE" -gt "${#DISKS[@]}" ]; then
            warn "Please enter a valid number between 1 and ${#DISKS[@]}"
            continue
        fi
        ROOT_DISK="/dev/$(echo "${DISKS[$ROOT_CHOICE-1]}" | awk '{print $1}')"
        
        if ! check_disk_size "$ROOT_DISK"; then
            continue
        fi
        echo -e "Selected root disk: ${BOLD}${ROOT_DISK}${NC} (${DISKS[$ROOT_CHOICE-1]})"
        break
    done

    # Ask about home location
    while true; do
        read -p "$(echo -e "${BOLD}${BLUE}$ARROW${NC} Do you want @home on the same disk? [Y/n]: ")" SAME_DISK
        case "${SAME_DISK,,}" in
            ""|y|yes)
                HOME_DISK="$ROOT_DISK"
                break
                ;;
            n|no)
                # Print available disks again, excluding root disk
                echo -e "\n${BLUE}${BOLD}Available disks for home:${NC}"
                local disk_counter=0
                declare -a AVAILABLE_HOME_DISKS
                for i in "${!DISKS[@]}"; do
                    if [ "/dev/$(echo "${DISKS[$i]}" | awk '{print $1}')" != "$ROOT_DISK" ]; then
                        disk_counter=$((disk_counter + 1))
                        echo -e "$disk_counter)) ${DISKS[$i]}"
                        AVAILABLE_HOME_DISKS+=("${DISKS[$i]}")
                    fi
                done

                if [ $disk_counter -eq 0 ]; then
                    warn "No other disks available. Using same disk for home."
                    HOME_DISK="$ROOT_DISK"
                    break
                fi
                
                echo
                while true; do
                    read -p "$(echo -e "${BOLD}${BLUE}$ARROW${NC} Choose disk number for home (@home): ")" HOME_CHOICE
                    if ! [[ "$HOME_CHOICE" =~ ^[0-9]+$ ]] || [ "$HOME_CHOICE" -lt 1 ] || [ "$HOME_CHOICE" -gt "$disk_counter" ]; then
                        warn "Please enter a valid number between 1 and $disk_counter"
                        continue
                    fi
                    HOME_DISK="/dev/$(echo "${AVAILABLE_HOME_DISKS[$HOME_CHOICE-1]}" | awk '{print $1}')"
                    
                    if ! check_disk_size "$HOME_DISK"; then
                        continue
                    fi
                    echo -e "Selected home disk: ${BOLD}${HOME_DISK}${NC} (${AVAILABLE_HOME_DISKS[$HOME_CHOICE-1]})"
                    break
                done
                break
                ;;
            *)
                warn "Invalid choice. Please enter Y or N"
                continue
                ;;
        esac
    done

    # Ask about boot partition
    while true; do
        read -p "$(echo -e "${BOLD}${BLUE}$ARROW${NC} Should boot partition be on the root disk? [Y/n]: ")" BOOT_CHOICE
        case "${BOOT_CHOICE,,}" in
            ""|y|yes) 
                BOOT_CHOICE="yes"
                break
                ;;
            n|no)
                BOOT_CHOICE="no"
                break
                ;;
            *)
                warn "Invalid choice. Please enter Y or N"
                ;;
        esac
    done

    # Show final configuration
    echo
    print_section "Selected Configuration"
    echo -e "Root disk (@):     ${BOLD}${ROOT_DISK}${NC}"
    if [ "$HOME_DISK" = "$ROOT_DISK" ]; then
        echo -e "Home (@home):      ${BOLD}Same as root disk${NC}"
    else
        echo -e "Home (@home):      ${BOLD}${HOME_DISK}${NC}"
    fi
    echo -e "Boot on root:      ${BOLD}${BOOT_CHOICE}${NC}"
    echo
}

# Helper function for partition device names
get_partition_device() {
    local disk=$1
    local num=$2
    
    if [[ "$disk" == *"nvme"* ]]; then
        echo "${disk}p${num}"
    else
        echo "${disk}${num}"
    fi
}

# Partition and format disks
prepare_disks() {
    print_section "💽 Preparing Disks"
    
    # Show current configuration
    echo -e "\n${BOLD}Selected configuration:${NC}"
    echo -e "Root disk (@): ${BOLD}${ROOT_DISK}${NC}"
    if [ "$HOME_DISK" = "$ROOT_DISK" ]; then
        echo -e "Home (@home): ${BOLD}Same as root disk${NC}"
    else
        echo -e "Home (@home): ${BOLD}${HOME_DISK}${NC}"
    fi
    echo -e "Boot on root: ${BOLD}${BOOT_CHOICE}${NC}"
    echo

    # Get root size
    while true; do
        read -p "$(echo -e "${BOLD}${BLUE}$ARROW${NC} Enter size for ROOT in GB (e.g., 50): ")" ROOT_SIZE
        if ! [[ "$ROOT_SIZE" =~ ^[0-9]+$ ]]; then
            warn "Please enter a valid number"
            continue
        fi
        # Verify size against disk capacity
        local disk_size=$(lsblk -b -dn -o SIZE "$ROOT_DISK" | awk '{ printf "%.0f", $1/1024/1024/1024 }')
        if [ "$ROOT_SIZE" -gt "$disk_size" ]; then
            warn "Size exceeds disk capacity ($disk_size GB)"
            continue
        fi
        break
    done

    # Get home size preference if on same disk
    if [ "$HOME_DISK" = "$ROOT_DISK" ]; then
        echo -e "\n${BOLD}HOME partition options:${NC}"
        echo "1) Use remaining disk space (recommended)"
        echo "2) Specify size in GB"
        while true; do
            read -p "$(echo -e "${BOLD}${BLUE}$ARROW${NC} Choose option [1-2]: ")" HOME_OPTION
            case "$HOME_OPTION" in
                1)
                    HOME_PARAM="0"  # Use 0 to indicate "use rest of disk"
                    break
                    ;;
                2)
                    while true; do
                        read -p "$(echo -e "${BOLD}${BLUE}$ARROW${NC} Enter size for HOME in GB: ")" HOME_SIZE
                        if ! [[ "$HOME_SIZE" =~ ^[0-9]+$ ]]; then
                            warn "Please enter a valid number"
                            continue
                        fi
                        # Check if total size doesn't exceed disk
                        local total_size=$((ROOT_SIZE + HOME_SIZE))
                        if [ "$BOOT_CHOICE" = "yes" ]; then
                            total_size=$((total_size + 1)) # Add 1GB for EFI
                        fi
                        if [ "$total_size" -gt "$disk_size" ]; then
                            warn "Combined size exceeds disk capacity ($disk_size GB)"
                            continue
                        fi
                        HOME_PARAM="+${HOME_SIZE}G"
                        break
                    done
                    break
                    ;;
                *)
                    warn "Invalid option. Please enter 1 or 2"
                    ;;
            esac
        done
    fi

    # Confirm before proceeding
    echo -e "\n${BOLD}Partition layout to be created:${NC}"
    if [[ "$BOOT_CHOICE" == "yes" ]]; then
        echo "EFI:  1GB"
    fi
    echo "ROOT: ${ROOT_SIZE}GB"
    if [ "$HOME_DISK" = "$ROOT_DISK" ]; then
        if [ "$HOME_PARAM" = "0" ]; then
            echo "HOME: Remaining space"
        else
            echo "HOME: ${HOME_SIZE}GB"
        fi
    else
        echo "HOME: Entire separate disk"
    fi
    echo
    read -p "$(echo -e "${BOLD}${RED}$WARNING${NC} This will DESTROY ALL DATA on selected disks. Continue? [y/N]: ")" confirm
    if [[ ! "${confirm,,}" =~ ^(y|yes)$ ]]; then
        error "Operation cancelled by user"
    fi

    # Start partitioning
    progress "Clearing disk signatures"
    wipefs -af "$ROOT_DISK" >/dev/null 2>&1
    if [ "$HOME_DISK" != "$ROOT_DISK" ]; then
        wipefs -af "$HOME_DISK" >/dev/null 2>&1
    fi
    success "Cleared disk signatures"

    progress "Partitioning root disk"
    if [[ "$BOOT_CHOICE" == "yes" ]]; then
        # Create GPT partition table
        sgdisk -Z "$ROOT_DISK" >/dev/null 2>&1

        if [ "$HOME_DISK" = "$ROOT_DISK" ]; then
            # Three partitions: EFI, ROOT, HOME
            sgdisk -n 1:0:+1G -t 1:ef00 -c 1:"EFI" "$ROOT_DISK" >/dev/null 2>&1
            sgdisk -n 2:0:+${ROOT_SIZE}G -t 2:8300 -c 2:"ROOT" "$ROOT_DISK" >/dev/null 2>&1
            sgdisk -n 3:0:${HOME_PARAM} -t 3:8300 -c 3:"HOME" "$ROOT_DISK" >/dev/null 2>&1
            BOOT_PART=$(get_partition_device "$ROOT_DISK" "1")
            ROOT_PART=$(get_partition_device "$ROOT_DISK" "2")
            HOME_PART=$(get_partition_device "$ROOT_DISK" "3")
        else
            # Two partitions: EFI and ROOT
            sgdisk -n 1:0:+1G -t 1:ef00 -c 1:"EFI" "$ROOT_DISK" >/dev/null 2>&1
            sgdisk -n 2:0:+${ROOT_SIZE}G -t 2:8300 -c 2:"ROOT" "$ROOT_DISK" >/dev/null 2>&1
            BOOT_PART=$(get_partition_device "$ROOT_DISK" "1")
            ROOT_PART=$(get_partition_device "$ROOT_DISK" "2")
        fi
    else
        # No boot partition needed
        sgdisk -Z "$ROOT_DISK" >/dev/null 2>&1
        if [ "$HOME_DISK" = "$ROOT_DISK" ]; then
            # Two partitions: ROOT and HOME
            sgdisk -n 1:0:+${ROOT_SIZE}G -t 1:8300 -c 1:"ROOT" "$ROOT_DISK" >/dev/null 2>&1
            sgdisk -n 2:0:${HOME_PARAM} -t 2:8300 -c 2:"HOME" "$ROOT_DISK" >/dev/null 2>&1
            ROOT_PART=$(get_partition_device "$ROOT_DISK" "1")
            HOME_PART=$(get_partition_device "$ROOT_DISK" "2")
        else
            # Single ROOT partition
            sgdisk -n 1:0:+${ROOT_SIZE}G -t 1:8300 -c 1:"ROOT" "$ROOT_DISK" >/dev/null 2>&1
            ROOT_PART=$(get_partition_device "$ROOT_DISK" "1")
        fi
    fi
    success "Partitioned root disk"

    # Only partition home disk if it's different from root
    if [ "$HOME_DISK" != "$ROOT_DISK" ]; then
        progress "Partitioning home disk"
        sgdisk -Z "$HOME_DISK" >/dev/null 2>&1
        sgdisk -n 1:0:0 -t 1:8300 -c 1:"HOME" "$HOME_DISK" >/dev/null 2>&1
        HOME_PART=$(get_partition_device "$HOME_DISK" "1")
        success "Partitioned home disk"
    fi

    # Wait for devices to settle
    progress "Waiting for partitions to settle"
    sleep 3
    partprobe "$ROOT_DISK"
    if [ "$HOME_DISK" != "$ROOT_DISK" ]; then
        partprobe "$HOME_DISK"
    fi
    success "Partitions updated"

    progress "Formatting partitions"
    if [[ "$BOOT_CHOICE" == "yes" ]]; then
        mkfs.fat -F32 "$BOOT_PART" >/dev/null 2>&1
    fi
    mkfs.btrfs -f -L ROOT "$ROOT_PART" >/dev/null 2>&1
    mkfs.btrfs -f -L HOME "$HOME_PART" >/dev/null 2>&1
    success "Formatted partitions"

    # Additional wait after formatting
    sleep 2
}

# Create and mount BTRFS subvolumes
setup_btrfs() {
    print_section "🌲 Setting up BTRFS"
    
    progress "Creating BTRFS subvolumes"
    mount "$ROOT_PART" /mnt
    
    btrfs subvolume create /mnt/@ >/dev/null
    btrfs subvolume create /mnt/@snapshots >/dev/null
    btrfs subvolume create /mnt/@log >/dev/null
    btrfs subvolume create /mnt/@cache >/dev/null
    
    umount /mnt
    success "Created BTRFS subvolumes"
    
    progress "Mounting subvolumes"
    mount -o compress=zstd,space_cache=v2,noatime,commit=120,ssd,discard=async,subvol=@ "$ROOT_PART" /mnt
    
    mkdir -p /mnt/{boot,home,.snapshots,var/log,var/cache}
    
    mount -o compress=zstd,space_cache=v2,noatime,subvol=@snapshots "$ROOT_PART" /mnt/.snapshots
    mount -o compress=zstd,space_cache=v2,noatime,subvol=@log "$ROOT_PART" /mnt/var/log
    mount -o compress=zstd,space_cache=v2,noatime,subvol=@cache "$ROOT_PART" /mnt/var/cache
    
    if [[ "$BOOT_CHOICE" == "yes" ]]; then
        mount "$BOOT_PART" /mnt/boot
    fi
    
    mount -o compress=zstd,space_cache=v2,noatime,ssd,discard=async "$HOME_PART" /mnt/home
    success "Mounted all subvolumes"
    
    progress "Verifying mount points"
    if ! findmnt /mnt >/dev/null || \
       ! findmnt /mnt/.snapshots >/dev/null || \
       ! findmnt /mnt/var/log >/dev/null || \
       ! findmnt /mnt/var/cache >/dev/null || \
       ! findmnt /mnt/home >/dev/null; then
        error "Failed to verify mount points"
    fi
    success "Verified all mount points"
}

# Function to generate fstab entries
generate_fstab_template() {
    print_section "📝 Generating fstab Template"
    
    progress "Creating fstab template"
    mkdir -p /mnt/etc
    genfstab -U /mnt > /mnt/etc/fstab.template
    success "Generated fstab template"
}

# Function to create post-install configuration
create_post_install_config() {
    print_section "⚙️ Creating Post-install Configuration"
    
    mkdir -p /mnt/etc/pacman.d/hooks
    
    # Create snapshot hook
    cat > /mnt/etc/pacman.d/hooks/95-snapshot.hook << EOF
[Trigger]
Operation = Upgrade
Operation = Install
Operation = Remove
Type = Package
Target = *

[Action]
Description = Creating snapshot before pacman transactions...
When = PreTransaction
Exec = /usr/bin/timeshift --create --comments "Pacman transaction" --quiet
EOF
    
    # Create GRUB BTRFS config
    mkdir -p /mnt/etc/default/grub.d
    cat > /mnt/etc/default/grub.d/btrfs.cfg << EOF
GRUB_BTRFS_SHOW_TOTAL_SNAPSHOTS="true"
GRUB_BTRFS_SHOW_SNAPSHOTS_FOUND="true"
GRUB_BTRFS_SUBMIT_BUTTON="true"
GRUB_BTRFS_LIMIT="30"
EOF
    
    success "Created post-install configuration"
}

# Function to save disk configuration
save_disk_config() {
    print_section "💾 Saving Disk Configuration"
    
    progress "Saving disk configuration"
    
    # Save configuration for the installed system
    mkdir -p /mnt/root
    cat > /mnt/root/disk_config.txt << EOF
ROOT_DISK=$ROOT_DISK
HOME_DISK=$HOME_DISK
BOOT_CHOICE=$BOOT_CHOICE
ROOT_PART=$ROOT_PART
HOME_PART=$HOME_PART
BOOT_PART=$BOOT_PART
EOF

    # Also save configuration for the installation process
    cat > /root/disk_config.txt << EOF
ROOT_DISK=$ROOT_DISK
HOME_DISK=$HOME_DISK
BOOT_CHOICE=$BOOT_CHOICE
ROOT_PART=$ROOT_PART
HOME_PART=$HOME_PART
BOOT_PART=$BOOT_PART
EOF

    # Set proper permissions
    chmod 600 /root/disk_config.txt
    chmod 600 /mnt/root/disk_config.txt
    
    # Verify the configuration was saved
    if [ ! -f "/root/disk_config.txt" ]; then
        error "Failed to save disk configuration to /root"
    fi
    if [ ! -f "/mnt/root/disk_config.txt" ]; then
        error "Failed to save disk configuration to /mnt/root"
    fi

    success "Saved disk configuration to both locations"
    
    # Display the configuration for verification
    echo -e "\n${CYAN}Disk Configuration:${NC}"
    cat "/root/disk_config.txt"
    echo
}

# Function to print next steps
# Function to print next steps
print_next_steps() {
    print_section "📋 Next Steps"
    echo -e "${BOLD}1.${NC} Run archinstall with the following settings:"
    echo "   - Select 'Manual partitioning'"
    echo "   - Choose BTRFS as filesystem"
    echo "   - DO NOT format the partitions"
    echo "   - Use these mount points:"
    echo "     /         → $ROOT_PART (subvol=@)"
    echo "     /home     → $HOME_PART"
    if [[ "$BOOT_CHOICE" == "yes" ]]; then
        echo "     /boot     → $BOOT_PART"
    fi
    echo "     /.snapshots → $ROOT_PART (subvol=@snapshots)"
    echo "     /var/log   → $ROOT_PART (subvol=@log)"
    echo "     /var/cache → $ROOT_PART (subvol=@cache)"
    echo
    echo -e "${BOLD}2.${NC} Select GRUB as bootloader"
    echo -e "${BOLD}3.${NC} Complete the archinstall process"
    echo -e "${BOLD}4.${NC} After installation but before reboot:"
    echo "   - Install timeshift and related tools"
    echo "   - Enable scrub timer"
    echo "   - Create rescue snapshot"
    echo
    echo -e "${YELLOW}NOTE:${NC} Configuration has been saved to /root/disk_config.txt"
    echo "      Mount points template saved to /etc/fstab.template"
    echo
}

# Function to create rescue point
create_rescue_point() {
    print_section "💾 Creating Rescue Point"
    
    progress "Installing timeshift"
    arch-chroot /mnt pacman -S --noconfirm timeshift timeshift-autosnap grub-btrfs btrbk >/dev/null 2>&1 || {
        error "Failed to install timeshift" "no_exit"
        return 1
    }
    success "Installed timeshift and related tools"

    progress "Enabling scrub timer"
    arch-chroot /mnt systemctl enable btrfs-scrub@-.timer >/dev/null 2>&1
    arch-chroot /mnt systemctl enable btrfs-scrub@home.timer >/dev/null 2>&1
    success "Enabled scrub timers"

    progress "Creating rescue snapshot"
    arch-chroot /mnt timeshift --create --comments "Base system rescue point" --quiet >/dev/null 2>&1 || {
        error "Failed to create rescue snapshot" "no_exit"
        return 1
    }
    success "Created rescue snapshot"
}

# Main execution
main() {
    # Print header
    print_header
    
    # Initial checks
    check_root
    
    # Get disk configuration
    select_disks
    
    # Prepare and setup filesystems
    prepare_disks
    setup_btrfs
    
    # Generate configurations
    generate_fstab_template
    create_post_install_config
    save_disk_config
    
    # Print next steps
    print_next_steps
    
    # Ask to create rescue point
    echo
    read -p "$(echo -e "${BOLD}${BLUE}$ARROW${NC} Would you like to install timeshift and create a rescue point now? [y/N]: ")" rescue_choice
    if [[ "${rescue_choice,,}" =~ ^(y|yes|)$ ]]; then
        create_rescue_point
    fi
    
    echo
    echo -e "${GREEN}${BOLD}Setup complete!${NC}"
    echo "You can now proceed with archinstall"
    echo
}

# Run the script with error handling
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    trap 'error "An error occurred. Check the output above for details."' ERR
    main "$@"
fi
