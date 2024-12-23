# Disk selection function
select_disks() {
    print_section "💽 Disk Selection"
    
    echo -e "\n${BLUE}${BOLD}Available disks:${NC}"
    lsblk -d -e 7,11 -o NAME,SIZE,MODEL
    echo

    # Select root disk
    while true; do
        read -p "$(echo -e "${BOLD}${BLUE}$ARROW${NC} Enter disk for root system (@) (e.g., sda): ")" ROOT_DISK
        ROOT_DISK="/dev/${ROOT_DISK}"
        
        if [ ! -b "$ROOT_DISK" ]; then
            warn "Invalid disk: $ROOT_DISK"
            continue
        fi
        
        if ! check_disk_size "$ROOT_DISK"; then
            continue
        fi
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
                while true; do
                    read -p "$(echo -e "${BOLD}${BLUE}$ARROW${NC} Enter disk for home (@home) (e.g., sdb): ")" HOME_DISK_INPUT
                    HOME_DISK="/dev/${HOME_DISK_INPUT}"
                    
                    if [ ! -b "$HOME_DISK" ]; then
                        warn "Invalid disk: $HOME_DISK"
                        continue
                    fi
                    
                    if ! check_disk_size "$HOME_DISK"; then
                        continue
                    fi
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

    # Show selected configuration
    echo -e "\n${BOLD}Selected configuration:${NC}"
    echo -e "Root disk (@): ${BOLD}${ROOT_DISK}${NC}"
    if [ "$HOME_DISK" = "$ROOT_DISK" ]; then
        echo -e "Home (@home): ${BOLD}Same as root disk${NC}"
    else
        echo -e "Home (@home): ${BOLD}${HOME_DISK}${NC}"
    fi
    echo -e "Boot on root: ${BOLD}${BOOT_CHOICE}${NC}"
    echo
}
