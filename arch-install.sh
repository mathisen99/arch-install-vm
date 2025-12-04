#!/bin/bash
#
# Mathisen's Arch Install Script for VMs
# https://github.com/mathisen99/arch-install-vm
#
# Run with: bash <(curl -sL https://raw.githubusercontent.com/mathisen99/arch-install-vm/main/arch-install.sh)
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

print_msg() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_info() {
    echo -e "${CYAN}[i]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_header() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} ${BOLD}$1${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo -e "${BOLD}${CYAN}>>>${NC} $1"
}

# Colored prompt
prompt() {
    echo -ne "${YELLOW}:: ${NC}${BOLD}$1${NC} "
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run as root"
    exit 1
fi

# Check if running from Arch ISO
if [[ ! -f /etc/arch-release ]]; then
    print_error "This script must be run from an Arch Linux live environment"
    exit 1
fi

# Check internet connection
print_info "Checking internet connection..."
if ! ping -c 1 archlinux.org &>/dev/null; then
    print_error "No internet connection! Please connect to the internet first."
    print_info "For Wi-Fi, use: iwctl"
    exit 1
fi
print_msg "Internet connection OK"

# Install dialog for ncurses menus
print_info "Installing dialog for interactive menus..."
pacman -Sy --noconfirm dialog &>/dev/null
print_msg "Dialog installed"

# ============================================================================
# WELCOME SCREEN
# ============================================================================
clear
echo -e "${CYAN}"
cat << 'EOF'
   _____                .__      ___________                                                                           
  /  _  \_______   ____ |  |__   \_   _____/____    _________.__.                                                      
 /  /_\  \_  __ \_/ ___\|  |  \   |    __)_\__  \  /  ___<   |  |                                                      
/    |    \  | \/\  \___|   Y  \  |        \/ __ \_\___ \ \___  |                                                      
\____|__  /__|    \___  >___|  / /_______  (____  /____  >/ ____|                                                      
        \/            \/     \/          \/     \/     \/ \/                                                           
__________         .____    .__                               .__            __     ____ ___                           
\______   \___.__. |    |   |__| ____  __ _____  ___     ____ |  |__ _____ _/  |_  |    |   \______ ___________  ______
 |    |  _<   |  | |    |   |  |/    \|  |  \  \/  /   _/ ___\|  |  \\__  \\   __\ |    |   /  ___// __ \_  __ \/  ___/
 |    |   \\___  | |    |___|  |   |  \  |  />    <    \  \___|   Y  \/ __ \|  |   |    |  /\___ \\  ___/|  | \/\___ \ 
 |______  // ____| |_______ \__|___|  /____//__/\_ \ /\ \___  >___|  (____  /__|   |______//____  >\___  >__|  /____  >
        \/ \/              \/       \/            \/ \/     \/     \/     \/                    \/     \/           \/       
EOF
echo -e "${NC}"
echo ""
echo -e "${BOLD}Welcome to Mathisen's Arch Linux Install Script for VMs${NC}"
echo ""
echo -e "This script will guide you through installing Arch Linux with:"
echo -e "  ${GREEN}•${NC} Automatic partitioning (ext4 or btrfs with subvolumes)"
echo -e "  ${GREEN}•${NC} Optional LUKS disk encryption"
echo -e "  ${GREEN}•${NC} Choice of desktop environments (XFCE, GNOME, KDE, Hyprland, etc.)"
echo -e "  ${GREEN}•${NC} PipeWire audio, NetworkManager, and more"
echo -e "  ${GREEN}•${NC} zswap and tmpfs for better performance"
echo -e "  ${GREEN}•${NC} Optional Zsh with Oh-My-Zsh"
echo ""
echo -e "${YELLOW}WARNING: This will ERASE the selected disk!${NC}"
echo ""
prompt "Press Enter to continue..."
read

clear
print_header "Mathisen's Arch Install Script for VMs"

# Detect boot mode
if [[ -d /sys/firmware/efi/efivars ]]; then
    BOOT_MODE="UEFI"
else
    BOOT_MODE="BIOS"
fi
print_msg "Detected boot mode: ${BOLD}${BOOT_MODE}${NC}"

# Detect CPU vendor for microcode
CPU_VENDOR=$(grep -m1 vendor_id /proc/cpuinfo | awk '{print $3}')
if [[ "$CPU_VENDOR" == "GenuineIntel" ]]; then
    MICROCODE="intel-ucode"
    print_msg "Detected CPU: ${BOLD}Intel${NC} (will install intel-ucode)"
elif [[ "$CPU_VENDOR" == "AuthenticAMD" ]]; then
    MICROCODE="amd-ucode"
    print_msg "Detected CPU: ${BOLD}AMD${NC} (will install amd-ucode)"
else
    MICROCODE=""
    print_info "CPU vendor not detected, skipping microcode"
fi

# Detect RAM for tmpfs sizing
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_RAM_MB=$((TOTAL_RAM_KB / 1024))
TOTAL_RAM_GB=$((TOTAL_RAM_MB / 1024))
print_msg "Detected RAM: ${BOLD}${TOTAL_RAM_GB}GB${NC}"

# ============================================================================
# MIRROR SELECTION WITH REFLECTOR
# ============================================================================
print_header "Mirror Selection"

# Install reflector
print_info "Installing reflector..."
pacman -S --noconfirm reflector &>/dev/null

# Build country list for dialog
COUNTRIES=(
    "AU" "Australia"
    "AT" "Austria"
    "BE" "Belgium"
    "BR" "Brazil"
    "CA" "Canada"
    "CL" "Chile"
    "CN" "China"
    "CZ" "Czechia"
    "DK" "Denmark"
    "FI" "Finland"
    "FR" "France"
    "DE" "Germany"
    "GR" "Greece"
    "HK" "Hong Kong"
    "HU" "Hungary"
    "IN" "India"
    "ID" "Indonesia"
    "IE" "Ireland"
    "IL" "Israel"
    "IT" "Italy"
    "JP" "Japan"
    "KR" "South Korea"
    "LV" "Latvia"
    "LT" "Lithuania"
    "MY" "Malaysia"
    "MX" "Mexico"
    "NL" "Netherlands"
    "NZ" "New Zealand"
    "NO" "Norway"
    "PL" "Poland"
    "PT" "Portugal"
    "RO" "Romania"
    "RU" "Russia"
    "RS" "Serbia"
    "SG" "Singapore"
    "SK" "Slovakia"
    "SI" "Slovenia"
    "ZA" "South Africa"
    "ES" "Spain"
    "SE" "Sweden"
    "CH" "Switzerland"
    "TW" "Taiwan"
    "TH" "Thailand"
    "TR" "Turkey"
    "UA" "Ukraine"
    "GB" "United Kingdom"
    "US" "United States"
)

COUNTRY=$(dialog --clear --title "Mirror Selection" \
    --menu "Select your country for fastest mirrors:" 20 50 15 \
    "${COUNTRIES[@]}" 2>&1 >/dev/tty)

clear
print_msg "Selected country: ${BOLD}${COUNTRY}${NC}"
print_step "Finding fastest mirrors (this may take a moment)..."
reflector --country "$COUNTRY" --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist --latest 10
print_msg "Mirrors updated"

# ============================================================================
# FILESYSTEM SELECTION
# ============================================================================
print_header "Filesystem Selection"

FS_TYPE=$(dialog --clear --title "Filesystem Selection" \
    --menu "Choose your filesystem:" 12 60 3 \
    "ext4" "Traditional, stable, fast (recommended)" \
    "btrfs" "Modern, snapshots, compression, subvolumes" 2>&1 >/dev/tty)

clear
print_msg "Selected filesystem: ${BOLD}${FS_TYPE}${NC}"

# ============================================================================
# ENCRYPTION SELECTION
# ============================================================================
print_header "Disk Encryption"

if dialog --clear --title "LUKS Encryption" \
    --yesno "Do you want to encrypt your disk with LUKS?\n\nThis provides full disk encryption for security.\nYou will need to enter a password at every boot." 10 60 2>&1 >/dev/tty; then
    USE_LUKS="yes"
    clear
    print_msg "LUKS encryption: ${BOLD}Enabled${NC}"
    
    # Get LUKS password
    while true; do
        LUKS_PASSWORD=$(dialog --clear --title "LUKS Encryption Password" \
            --insecure --passwordbox "Enter encryption password:" 8 50 2>&1 >/dev/tty)
        LUKS_PASSWORD_CONFIRM=$(dialog --clear --title "LUKS Encryption Password" \
            --insecure --passwordbox "Confirm encryption password:" 8 50 2>&1 >/dev/tty)
        
        if [[ "$LUKS_PASSWORD" == "$LUKS_PASSWORD_CONFIRM" ]] && [[ -n "$LUKS_PASSWORD" ]]; then
            break
        fi
        dialog --clear --title "Error" --msgbox "Passwords don't match or are empty. Try again." 6 50
    done
    clear
    print_msg "LUKS password set"
else
    USE_LUKS="no"
    clear
    print_msg "LUKS encryption: ${BOLD}Disabled${NC}"
fi

# ============================================================================
# DESKTOP ENVIRONMENT SELECTION
# ============================================================================
print_header "Desktop Environment Selection"

DESKTOP_ENV=$(dialog --clear --title "Desktop Environment" \
    --menu "Choose your desktop environment:" 20 70 12 \
    "xfce" "XFCE4 - Lightweight, traditional desktop" \
    "gnome" "GNOME - Modern, full-featured desktop" \
    "kde" "KDE Plasma - Feature-rich, customizable" \
    "cinnamon" "Cinnamon - Traditional, Windows-like" \
    "mate" "MATE - Classic GNOME 2 fork" \
    "lxqt" "LXQt - Lightweight Qt desktop" \
    "budgie" "Budgie - Modern, elegant desktop" \
    "i3" "i3 - Tiling window manager" \
    "sway" "Sway - i3-compatible Wayland compositor" \
    "hyprland" "Hyprland - Dynamic tiling Wayland compositor" \
    "none" "No desktop - CLI only" 2>&1 >/dev/tty)

clear
print_msg "Selected desktop: ${BOLD}${DESKTOP_ENV}${NC}"

# NVIDIA GPU detection for Hyprland/Sway
HAS_NVIDIA="no"
if [[ "$DESKTOP_ENV" == "hyprland" ]] || [[ "$DESKTOP_ENV" == "sway" ]]; then
    # Check for NVIDIA GPU
    if lspci | grep -i nvidia &>/dev/null; then
        dialog --clear --title "NVIDIA GPU Detected" \
            --yesno "An NVIDIA GPU was detected.\n\nDo you want to install NVIDIA proprietary drivers?\n\nThis is recommended for Hyprland/Sway on NVIDIA.\nThe script will configure nvidia_drm modeset=1." 12 60 2>&1 >/dev/tty
        if [[ $? -eq 0 ]]; then
            HAS_NVIDIA="yes"
            clear
            print_msg "NVIDIA drivers: ${BOLD}Will be installed${NC}"
        else
            clear
            print_info "NVIDIA drivers: ${BOLD}Skipped${NC} (using nouveau)"
        fi
    fi
fi

# ============================================================================
# SHELL SELECTION
# ============================================================================
print_header "Shell Selection"

SHELL_CHOICE=$(dialog --clear --title "Shell Selection" \
    --menu "Choose your default shell:" 12 60 3 \
    "bash" "Bash - Standard shell (default)" \
    "zsh" "Zsh - Powerful shell" \
    "zsh-ohmyzsh" "Zsh + Oh-My-Zsh - Zsh with plugins & themes" 2>&1 >/dev/tty)

clear
print_msg "Selected shell: ${BOLD}${SHELL_CHOICE}${NC}"

# ============================================================================
# DISK SELECTION
# ============================================================================
print_header "Disk Selection"

# Build disk list for dialog
DISK_LIST=()
while IFS= read -r line; do
    NAME=$(echo "$line" | awk '{print $1}')
    SIZE=$(echo "$line" | awk '{print $2}')
    DISK_LIST+=("/dev/$NAME" "$SIZE")
done < <(lsblk -d -n -o NAME,SIZE | grep -v "loop\|sr")

DISK=$(dialog --clear --title "Disk Selection" \
    --menu "Select the disk to install Arch Linux:" 15 50 5 \
    "${DISK_LIST[@]}" 2>&1 >/dev/tty)

clear
print_msg "Selected disk: ${BOLD}${DISK}${NC}"

# ============================================================================
# WINDOWS DETECTION & DUAL BOOT
# ============================================================================
DUAL_BOOT="no"
WINDOWS_EFI_PART=""

# Check for Windows installation on selected disk
print_info "Checking for existing Windows installation..."

# Look for Windows EFI boot manager or NTFS partitions with Windows
if [[ "$BOOT_MODE" == "UEFI" ]]; then
    # Check for EFI System Partition with Windows Boot Manager
    for part in ${DISK}*[0-9]; do
        if [[ -b "$part" ]]; then
            PART_TYPE=$(blkid -s TYPE -o value "$part" 2>/dev/null)
            if [[ "$PART_TYPE" == "vfat" ]]; then
                # Mount and check for Windows boot files
                mkdir -p /tmp/efi_check
                if mount -o ro "$part" /tmp/efi_check 2>/dev/null; then
                    if [[ -d "/tmp/efi_check/EFI/Microsoft/Boot" ]]; then
                        WINDOWS_EFI_PART="$part"
                        print_msg "Windows Boot Manager found on ${BOLD}$part${NC}"
                    fi
                    umount /tmp/efi_check
                fi
                rmdir /tmp/efi_check 2>/dev/null
            fi
        fi
    done
fi

# Also check for NTFS partitions (Windows system drive)
WINDOWS_NTFS_FOUND="no"
for part in ${DISK}*[0-9]; do
    if [[ -b "$part" ]]; then
        PART_TYPE=$(blkid -s TYPE -o value "$part" 2>/dev/null)
        if [[ "$PART_TYPE" == "ntfs" ]]; then
            WINDOWS_NTFS_FOUND="yes"
            break
        fi
    fi
done

# If Windows detected, ask about dual boot
if [[ -n "$WINDOWS_EFI_PART" ]] || [[ "$WINDOWS_NTFS_FOUND" == "yes" ]]; then
    print_warn "Windows installation detected on this disk!"
    
    dialog --clear --title "Windows Detected" \
        --yesno "A Windows installation was detected on ${DISK}.\n\nDo you want to set up dual-boot?\n\n• YES = Install alongside Windows (requires free space)\n• NO = Erase entire disk (destroys Windows)" 12 65 2>&1 >/dev/tty
    
    if [[ $? -eq 0 ]]; then
        DUAL_BOOT="yes"
        clear
        print_msg "Dual-boot mode: ${BOLD}Enabled${NC}"
        
        # Check for unallocated space or ask user to specify partition
        print_header "Dual-Boot Setup"
        
        echo -e "${YELLOW}For dual-boot, you need free unallocated space on the disk.${NC}"
        echo ""
        echo -e "Current partition layout of ${BOLD}${DISK}${NC}:"
        echo ""
        lsblk -o NAME,SIZE,FSTYPE,LABEL "$DISK"
        echo ""
        
        # LUKS not supported with dual-boot (too complex)
        if [[ "$USE_LUKS" == "yes" ]]; then
            print_warn "LUKS encryption is not supported with dual-boot. Disabling encryption."
            USE_LUKS="no"
        fi
        
        echo -e "${CYAN}You need to have created free space in Windows Disk Management first.${NC}"
        echo -e "${CYAN}If you haven't done this, press Ctrl+C to cancel and shrink your${NC}"
        echo -e "${CYAN}Windows partition from within Windows first.${NC}"
        echo ""
        prompt "Press Enter if you have free space ready, or Ctrl+C to cancel..."
        read
        clear
    else
        DUAL_BOOT="no"
        clear
        print_msg "Dual-boot: ${BOLD}Disabled${NC} (will erase disk)"
    fi
else
    print_info "No Windows installation detected"
fi

# Confirm disk selection (different message for dual-boot)
if [[ "$DUAL_BOOT" == "yes" ]]; then
    dialog --clear --title "Dual-Boot Confirmation" \
        --yesno "Arch Linux will be installed in the free space on ${DISK}.\n\nWindows partitions will be preserved.\n\nContinue?" 10 55 2>&1 >/dev/tty
else
    dialog --clear --title "WARNING" \
        --yesno "This will ERASE ALL DATA on ${DISK}\n\nAre you sure you want to continue?" 8 50 2>&1 >/dev/tty
fi
clear

# ============================================================================
# SYSTEM CONFIGURATION
# ============================================================================
print_header "System Configuration"

# Hostname
HOSTNAME=$(dialog --clear --title "Hostname" \
    --inputbox "Enter hostname for this machine:" 8 50 "archlinux" 2>&1 >/dev/tty)
clear

# Validate hostname
if [[ ! "$HOSTNAME" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$ ]]; then
    HOSTNAME="archlinux"
fi
print_msg "Hostname: ${BOLD}${HOSTNAME}${NC}"

# Timezone selection using dialog
REGIONS=($(ls /usr/share/zoneinfo | grep -v -E "posix|right|leap|iso3166|zone|Factory|UTC|GMT" | sort))
REGION_MENU=()
for r in "${REGIONS[@]}"; do
    REGION_MENU+=("$r" "")
done

REGION=$(dialog --clear --title "Timezone - Region" \
    --menu "Select your region:" 20 40 15 \
    "${REGION_MENU[@]}" 2>&1 >/dev/tty)

if [[ -d "/usr/share/zoneinfo/$REGION" ]]; then
    CITIES=($(ls "/usr/share/zoneinfo/$REGION" | sort))
    CITY_MENU=()
    for c in "${CITIES[@]}"; do
        CITY_MENU+=("$c" "")
    done
    
    CITY=$(dialog --clear --title "Timezone - City" \
        --menu "Select your city:" 20 40 15 \
        "${CITY_MENU[@]}" 2>&1 >/dev/tty)
    TIMEZONE="$REGION/$CITY"
else
    TIMEZONE="$REGION"
fi
clear
print_msg "Timezone: ${BOLD}${TIMEZONE}${NC}"

# Locale
LOCALE=$(dialog --clear --title "Locale" \
    --inputbox "Enter your locale (e.g., en_US, en_GB, de_DE, nb_NO):" 8 50 "en_US" 2>&1 >/dev/tty)
clear
print_msg "Locale: ${BOLD}${LOCALE}.UTF-8${NC}"

# Keymap
KEYMAP=$(dialog --clear --title "Console Keymap" \
    --inputbox "Enter console keymap (e.g., us, uk, de, no):" 8 50 "us" 2>&1 >/dev/tty)
clear
print_msg "Keymap: ${BOLD}${KEYMAP}${NC}"

# ============================================================================
# PASSWORD SETUP
# ============================================================================
print_header "Password Setup"

# Root password
while true; do
    ROOT_PASSWORD=$(dialog --clear --title "Root Password" \
        --insecure --passwordbox "Enter root password:" 8 50 2>&1 >/dev/tty)
    ROOT_PASSWORD_CONFIRM=$(dialog --clear --title "Root Password" \
        --insecure --passwordbox "Confirm root password:" 8 50 2>&1 >/dev/tty)
    
    if [[ "$ROOT_PASSWORD" == "$ROOT_PASSWORD_CONFIRM" ]] && [[ -n "$ROOT_PASSWORD" ]]; then
        break
    fi
    dialog --clear --title "Error" --msgbox "Passwords don't match or are empty. Try again." 6 50
done
clear
print_msg "Root password set"

# Username
USERNAME=$(dialog --clear --title "User Account" \
    --inputbox "Enter username for regular user:" 8 50 "user" 2>&1 >/dev/tty)
clear

# Validate username
if [[ ! "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
    USERNAME="user"
fi
print_msg "Username: ${BOLD}${USERNAME}${NC}"

# User password
while true; do
    USER_PASSWORD=$(dialog --clear --title "User Password" \
        --insecure --passwordbox "Enter password for ${USERNAME}:" 8 50 2>&1 >/dev/tty)
    USER_PASSWORD_CONFIRM=$(dialog --clear --title "User Password" \
        --insecure --passwordbox "Confirm password for ${USERNAME}:" 8 50 2>&1 >/dev/tty)
    
    if [[ "$USER_PASSWORD" == "$USER_PASSWORD_CONFIRM" ]] && [[ -n "$USER_PASSWORD" ]]; then
        break
    fi
    dialog --clear --title "Error" --msgbox "Passwords don't match or are empty. Try again." 6 50
done
clear
print_msg "User password set"

# ============================================================================
# INSTALLATION SUMMARY
# ============================================================================
print_header "Installation Summary"
echo -e "  ${BOLD}Disk:${NC}        $DISK"
echo -e "  ${BOLD}Install:${NC}     $(if [[ "$DUAL_BOOT" == "yes" ]]; then echo "Dual-boot with Windows"; else echo "Clean install"; fi)"
echo -e "  ${BOLD}Encryption:${NC}  $(if [[ "$USE_LUKS" == "yes" ]]; then echo "LUKS"; else echo "None"; fi)"
echo -e "  ${BOLD}Filesystem:${NC}  $FS_TYPE"
echo -e "  ${BOLD}Boot Mode:${NC}   $BOOT_MODE"
echo -e "  ${BOLD}Hostname:${NC}    $HOSTNAME"
echo -e "  ${BOLD}Timezone:${NC}    $TIMEZONE"
echo -e "  ${BOLD}Locale:${NC}      ${LOCALE}.UTF-8"
echo -e "  ${BOLD}Keymap:${NC}      $KEYMAP"
echo -e "  ${BOLD}Username:${NC}    $USERNAME"
echo -e "  ${BOLD}Shell:${NC}       $SHELL_CHOICE"
echo -e "  ${BOLD}Desktop:${NC}     $DESKTOP_ENV"
if [[ "$HAS_NVIDIA" == "yes" ]]; then
    echo -e "  ${BOLD}GPU Driver:${NC}  NVIDIA (proprietary)"
fi
echo -e "  ${BOLD}Audio:${NC}       PipeWire"
echo -e "  ${BOLD}Features:${NC}    zswap, tmpfs /tmp"
if [[ "$FS_TYPE" == "btrfs" ]]; then
    echo -e "  ${BOLD}Subvolumes:${NC}  @, @home, @snapshots, @var_log"
fi
if [[ -n "$MICROCODE" ]]; then
    echo -e "  ${BOLD}Microcode:${NC}  $MICROCODE"
fi
echo ""
prompt "Proceed with installation? (yes/no):"
read FINAL_CONFIRM
if [[ "$FINAL_CONFIRM" != "yes" ]]; then
    print_info "Installation cancelled."
    exit 0
fi

# ============================================================================
# START INSTALLATION
# ============================================================================
print_header "Starting Installation"

# Update system clock
print_step "Syncing system clock..."
timedatectl set-ntp true
print_msg "System clock synced"

# Partitioning
print_step "Partitioning disk $DISK..."

# Determine partition naming
if [[ "$DISK" == *"nvme"* ]] || [[ "$DISK" == *"mmcblk"* ]]; then
    PART_PREFIX="${DISK}p"
else
    PART_PREFIX="${DISK}"
fi

if [[ "$DUAL_BOOT" == "yes" ]]; then
    # DUAL-BOOT: Don't wipe disk, create partition in free space
    print_info "Dual-boot mode: preserving existing partitions"
    
    # Use existing Windows EFI partition
    EFI_PART="$WINDOWS_EFI_PART"
    print_msg "Using existing EFI partition: ${EFI_PART}"
    
    # Find the next available partition number
    LAST_PART_NUM=$(lsblk -n -o NAME "$DISK" | grep -E "^${DISK##*/}[0-9]+" | sed "s/${DISK##*/}//" | sort -n | tail -1)
    NEXT_PART_NUM=$((LAST_PART_NUM + 1))
    
    # Create root partition in free space
    # First, find free space using parted
    print_step "Creating Arch Linux partition in free space..."
    
    # Get the end of the last partition and disk size
    FREE_SPACE_START=$(parted -s "$DISK" unit MiB print free | grep "Free Space" | tail -1 | awk '{print $1}' | sed 's/MiB//')
    FREE_SPACE_END=$(parted -s "$DISK" unit MiB print free | grep "Free Space" | tail -1 | awk '{print $2}' | sed 's/MiB//')
    
    if [[ -z "$FREE_SPACE_START" ]] || [[ -z "$FREE_SPACE_END" ]]; then
        print_error "No free space found on disk! Please shrink Windows partition first."
        exit 1
    fi
    
    FREE_SPACE_SIZE=$((FREE_SPACE_END - FREE_SPACE_START))
    if [[ $FREE_SPACE_SIZE -lt 20000 ]]; then
        print_error "Not enough free space! Need at least 20GB, found ${FREE_SPACE_SIZE}MB"
        exit 1
    fi
    
    print_info "Found ${FREE_SPACE_SIZE}MB of free space"
    
    # Create the root partition
    parted -s "$DISK" mkpart primary ${FS_TYPE} ${FREE_SPACE_START}MiB ${FREE_SPACE_END}MiB
    
    ROOT_PART="${PART_PREFIX}${NEXT_PART_NUM}"
    
    print_msg "Created Arch Linux partition"
    print_info "  EFI (shared):  ${EFI_PART}"
    print_info "  Root:          ${ROOT_PART} (${FREE_SPACE_SIZE}MB) - ${FS_TYPE}"

else
    # CLEAN INSTALL: Wipe and create new partition table
    wipefs -af "$DISK" &>/dev/null
    print_msg "Wiped existing partition table"

    if [[ "$BOOT_MODE" == "UEFI" ]]; then
        # UEFI partitioning with GPT (no swap partition - using zswap)
        parted -s "$DISK" mklabel gpt
        parted -s "$DISK" mkpart "EFI" fat32 1MiB 513MiB
        parted -s "$DISK" set 1 esp on
        parted -s "$DISK" mkpart "root" ${FS_TYPE} 513MiB 100%
        
        EFI_PART="${PART_PREFIX}1"
        ROOT_PART="${PART_PREFIX}2"
        
        print_msg "Created GPT partition table"
        print_info "  EFI:  ${EFI_PART} (512MB)"
        print_info "  Root: ${ROOT_PART} (remaining) - ${FS_TYPE}"
    else
        # BIOS partitioning with MBR (no swap partition - using zswap)
        parted -s "$DISK" mklabel msdos
        parted -s "$DISK" mkpart primary ${FS_TYPE} 1MiB 100%
        parted -s "$DISK" set 1 boot on
        
        ROOT_PART="${PART_PREFIX}1"
        
        print_msg "Created MBR partition table"
        print_info "  Root: ${ROOT_PART} (full disk) - ${FS_TYPE}"
    fi
fi

# Wait for partitions to appear
sleep 2
partprobe "$DISK" 2>/dev/null || true
sleep 1

# Format partitions
print_step "Formatting partitions..."

if [[ "$BOOT_MODE" == "UEFI" ]] && [[ "$DUAL_BOOT" != "yes" ]]; then
    # Only format EFI partition on clean install, not dual-boot
    mkfs.fat -F32 "$EFI_PART" &>/dev/null
    print_msg "Formatted EFI partition (FAT32)"
elif [[ "$DUAL_BOOT" == "yes" ]]; then
    print_info "Using existing EFI partition (not formatting)"
fi

# Handle LUKS encryption
if [[ "$USE_LUKS" == "yes" ]]; then
    print_step "Setting up LUKS encryption..."
    
    # Create LUKS container
    echo -n "$LUKS_PASSWORD" | cryptsetup luksFormat --type luks2 "$ROOT_PART" -
    print_msg "LUKS container created"
    
    # Open LUKS container
    echo -n "$LUKS_PASSWORD" | cryptsetup open "$ROOT_PART" cryptroot -
    print_msg "LUKS container opened"
    
    # The actual device to format is now /dev/mapper/cryptroot
    CRYPT_ROOT="/dev/mapper/cryptroot"
    
    # Get UUID of the LUKS partition (needed for GRUB)
    LUKS_UUID=$(blkid -s UUID -o value "$ROOT_PART")
else
    CRYPT_ROOT="$ROOT_PART"
fi

if [[ "$FS_TYPE" == "btrfs" ]]; then
    mkfs.btrfs -f "$CRYPT_ROOT" &>/dev/null
    print_msg "Formatted root partition (btrfs)"
    
    # Mount and create subvolumes
    print_step "Creating btrfs subvolumes..."
    mount "$CRYPT_ROOT" /mnt
    
    btrfs subvolume create /mnt/@ &>/dev/null
    btrfs subvolume create /mnt/@home &>/dev/null
    btrfs subvolume create /mnt/@snapshots &>/dev/null
    btrfs subvolume create /mnt/@var_log &>/dev/null
    
    print_msg "Created subvolumes: @, @home, @snapshots, @var_log"
    
    umount /mnt
    
    # Mount subvolumes with optimal options
    BTRFS_OPTS="noatime,compress=zstd,space_cache=v2,discard=async"
    
    mount -o subvol=@,${BTRFS_OPTS} "$CRYPT_ROOT" /mnt
    mkdir -p /mnt/{home,.snapshots,var/log,boot}
    mount -o subvol=@home,${BTRFS_OPTS} "$CRYPT_ROOT" /mnt/home
    mount -o subvol=@snapshots,${BTRFS_OPTS} "$CRYPT_ROOT" /mnt/.snapshots
    mount -o subvol=@var_log,${BTRFS_OPTS} "$CRYPT_ROOT" /mnt/var/log
    
    print_msg "Mounted btrfs subvolumes with compression"
else
    mkfs.ext4 -F "$CRYPT_ROOT" &>/dev/null
    print_msg "Formatted root partition (ext4)"
    mount "$CRYPT_ROOT" /mnt
fi

if [[ "$BOOT_MODE" == "UEFI" ]]; then
    mkdir -p /mnt/boot
    mount "$EFI_PART" /mnt/boot
fi

print_msg "All partitions mounted"

# ============================================================================
# INSTALL PACKAGES
# ============================================================================

# Install base system
print_step "Installing base system (this may take a while)..."

# Base packages
PACKAGES="base base-devel linux linux-firmware networkmanager grub sudo nano vim btop terminator tmux kitty"
PACKAGES="$PACKAGES reflector os-prober ntfs-3g"

# Add btrfs-progs if using btrfs
if [[ "$FS_TYPE" == "btrfs" ]]; then
    PACKAGES="$PACKAGES btrfs-progs"
fi

# Add microcode if detected
if [[ -n "$MICROCODE" ]]; then
    PACKAGES="$PACKAGES $MICROCODE"
fi

# Add efibootmgr for UEFI
if [[ "$BOOT_MODE" == "UEFI" ]]; then
    PACKAGES="$PACKAGES efibootmgr"
fi

pacstrap -K /mnt $PACKAGES
print_msg "Base system installed"

# Install shell
if [[ "$SHELL_CHOICE" == "zsh" ]] || [[ "$SHELL_CHOICE" == "zsh-ohmyzsh" ]]; then
    print_step "Installing Zsh..."
    pacstrap /mnt zsh zsh-completions
    print_msg "Zsh installed"
fi

# Install desktop environment
if [[ "$DESKTOP_ENV" != "none" ]]; then
    print_step "Installing ${DESKTOP_ENV} desktop environment..."
    
    # Base X packages for all desktop environments (except Wayland-only)
    if [[ "$DESKTOP_ENV" != "sway" ]]; then
        DESKTOP_PACKAGES="xorg xorg-server xorg-xinit"
    else
        DESKTOP_PACKAGES=""
    fi
    
    # Display manager
    case "$DESKTOP_ENV" in
        gnome|budgie)
            DESKTOP_PACKAGES="$DESKTOP_PACKAGES gdm"
            DISPLAY_MANAGER="gdm"
            ;;
        kde)
            DESKTOP_PACKAGES="$DESKTOP_PACKAGES sddm"
            DISPLAY_MANAGER="sddm"
            ;;
        sway|i3)
            # No display manager for tiling WMs by default
            DISPLAY_MANAGER=""
            ;;
        hyprland)
            DESKTOP_PACKAGES="$DESKTOP_PACKAGES sddm"
            DISPLAY_MANAGER="sddm"
            ;;
        *)
            DESKTOP_PACKAGES="$DESKTOP_PACKAGES lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings"
            DISPLAY_MANAGER="lightdm"
            ;;
    esac
    
    # Desktop-specific packages
    case "$DESKTOP_ENV" in
        xfce)
            DESKTOP_PACKAGES="$DESKTOP_PACKAGES xfce4 xfce4-goodies"
            DESKTOP_PACKAGES="$DESKTOP_PACKAGES xfce4-pulseaudio-plugin xfce4-notifyd"
            DESKTOP_PACKAGES="$DESKTOP_PACKAGES thunar-volman thunar-archive-plugin"
            ;;
        gnome)
            DESKTOP_PACKAGES="$DESKTOP_PACKAGES gnome gnome-tweaks gnome-shell-extensions"
            ;;
        kde)
            DESKTOP_PACKAGES="$DESKTOP_PACKAGES plasma-meta kde-applications-meta"
            DESKTOP_PACKAGES="$DESKTOP_PACKAGES packagekit-qt6"
            ;;
        cinnamon)
            DESKTOP_PACKAGES="$DESKTOP_PACKAGES cinnamon nemo-fileroller gnome-terminal"
            ;;
        mate)
            DESKTOP_PACKAGES="$DESKTOP_PACKAGES mate mate-extra"
            ;;
        lxqt)
            DESKTOP_PACKAGES="$DESKTOP_PACKAGES lxqt breeze-icons"
            ;;
        budgie)
            DESKTOP_PACKAGES="$DESKTOP_PACKAGES budgie-desktop budgie-desktop-view budgie-screensaver"
            DESKTOP_PACKAGES="$DESKTOP_PACKAGES gnome-terminal nautilus"
            ;;
        i3)
            DESKTOP_PACKAGES="$DESKTOP_PACKAGES i3-wm i3status i3lock dmenu"
            DESKTOP_PACKAGES="$DESKTOP_PACKAGES xterm feh picom dunst"
            DESKTOP_PACKAGES="$DESKTOP_PACKAGES thunar thunar-volman"
            ;;
        sway)
            DESKTOP_PACKAGES="$DESKTOP_PACKAGES sway swaylock swayidle swaybg"
            DESKTOP_PACKAGES="$DESKTOP_PACKAGES waybar wofi foot mako"
            DESKTOP_PACKAGES="$DESKTOP_PACKAGES xorg-xwayland thunar grim slurp"
            ;;
        hyprland)
            DESKTOP_PACKAGES="$DESKTOP_PACKAGES hyprland"
            DESKTOP_PACKAGES="$DESKTOP_PACKAGES xdg-desktop-portal-hyprland xdg-desktop-portal-gtk"
            DESKTOP_PACKAGES="$DESKTOP_PACKAGES hyprpaper hypridle hyprlock hyprpolkitagent"
            DESKTOP_PACKAGES="$DESKTOP_PACKAGES waybar wofi foot mako"
            DESKTOP_PACKAGES="$DESKTOP_PACKAGES xorg-xwayland thunar grim slurp wl-clipboard cliphist"
            DESKTOP_PACKAGES="$DESKTOP_PACKAGES brightnessctl playerctl pamixer"
            DESKTOP_PACKAGES="$DESKTOP_PACKAGES qt5-wayland qt6-wayland"
            ;;
    esac
    
    # Install NVIDIA drivers if selected
    if [[ "$HAS_NVIDIA" == "yes" ]]; then
        print_step "Installing NVIDIA drivers..."
        pacstrap /mnt nvidia nvidia-utils nvidia-settings
        print_msg "NVIDIA drivers installed"
    fi
    
    pacstrap /mnt $DESKTOP_PACKAGES
    print_msg "${DESKTOP_ENV} desktop installed"
    
    # Install audio
    print_step "Installing PipeWire audio stack..."
    AUDIO_PACKAGES="pipewire pipewire-alsa pipewire-pulse wireplumber"
    AUDIO_PACKAGES="$AUDIO_PACKAGES pavucontrol alsa-utils"
    pacstrap /mnt $AUDIO_PACKAGES
    print_msg "PipeWire audio installed"
    
    # Install common extras
    print_step "Installing extra packages..."
    EXTRA_PACKAGES="network-manager-applet nm-connection-editor"
    EXTRA_PACKAGES="$EXTRA_PACKAGES gvfs gvfs-mtp gvfs-smb"
    EXTRA_PACKAGES="$EXTRA_PACKAGES file-roller unzip p7zip"
    EXTRA_PACKAGES="$EXTRA_PACKAGES firefox"
    EXTRA_PACKAGES="$EXTRA_PACKAGES ttf-dejavu ttf-liberation noto-fonts"
    EXTRA_PACKAGES="$EXTRA_PACKAGES xdg-user-dirs xdg-utils"
    pacstrap /mnt $EXTRA_PACKAGES
    print_msg "Extra packages installed"
else
    print_info "Skipping desktop environment (CLI only)"
    DISPLAY_MANAGER=""
fi

# ============================================================================
# GENERATE FSTAB
# ============================================================================
print_step "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# Add tmpfs for /tmp (RAM disk)
echo "" >> /mnt/etc/fstab
echo "# tmpfs for /tmp - RAM disk" >> /mnt/etc/fstab
echo "tmpfs   /tmp    tmpfs   defaults,noatime,mode=1777,size=50%   0 0" >> /mnt/etc/fstab

print_msg "fstab generated with tmpfs /tmp"

# ============================================================================
# CHROOT CONFIGURATION
# ============================================================================
print_step "Configuring system..."

cat > /mnt/install-chroot.sh << CHROOT_EOF
#!/bin/bash
set -e

# Set timezone
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
hwclock --systohc

# Set locale
sed -i "s/^#${LOCALE}.UTF-8/${LOCALE}.UTF-8/" /etc/locale.gen
locale-gen
echo "LANG=${LOCALE}.UTF-8" > /etc/locale.conf

# Set console keymap
echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf

# Set hostname
echo "${HOSTNAME}" > /etc/hostname
cat > /etc/hosts << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
EOF

# Enable zswap in kernel parameters
mkdir -p /etc/modprobe.d
cat > /etc/modprobe.d/zswap.conf << EOF
# Enable zswap
options zswap enabled=1 compressor=zstd max_pool_percent=25
EOF

# Enable zswap via kernel command line
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& zswap.enabled=1 zswap.compressor=zstd zswap.max_pool_percent=25/' /etc/default/grub

# Configure LUKS if enabled
if [[ "${USE_LUKS}" == "yes" ]]; then
    # Add encrypt hook to mkinitcpio
    sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block encrypt filesystems fsck)/' /etc/mkinitcpio.conf
    
    # Configure GRUB for LUKS
    sed -i "s|GRUB_CMDLINE_LINUX=\"\"|GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=${LUKS_UUID}:cryptroot root=/dev/mapper/cryptroot\"|" /etc/default/grub
    
    # Enable GRUB cryptodisk for BIOS systems
    echo "GRUB_ENABLE_CRYPTODISK=y" >> /etc/default/grub
fi

# Enable services
systemctl enable NetworkManager
systemctl enable reflector.timer

# Enable display manager if set
if [[ -n "${DISPLAY_MANAGER}" ]]; then
    systemctl enable ${DISPLAY_MANAGER}
fi

# Set root password
echo "root:${ROOT_PASSWORD}" | chpasswd

# Determine user shell
if [[ "${SHELL_CHOICE}" == "zsh" ]] || [[ "${SHELL_CHOICE}" == "zsh-ohmyzsh" ]]; then
    USER_SHELL="/bin/zsh"
else
    USER_SHELL="/bin/bash"
fi

# Create user with proper groups
useradd -m -G wheel,audio,video,storage,optical -s \${USER_SHELL} ${USERNAME}
echo "${USERNAME}:${USER_PASSWORD}" | chpasswd

# Install Oh-My-Zsh if selected
if [[ "${SHELL_CHOICE}" == "zsh-ohmyzsh" ]]; then
    # Install git if not present
    pacman -S --noconfirm git curl
    
    # Install Oh-My-Zsh for user (non-interactive)
    su - ${USERNAME} -c 'sh -c "\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended'
    
    # Set a nice default theme
    su - ${USERNAME} -c 'sed -i "s/ZSH_THEME=\"robbyrussell\"/ZSH_THEME=\"agnoster\"/" ~/.zshrc'
    
    # Add some useful plugins
    su - ${USERNAME} -c 'sed -i "s/plugins=(git)/plugins=(git sudo history archlinux)/" ~/.zshrc'
fi

# Create xinitrc for i3 if no display manager
if [[ "${DESKTOP_ENV}" == "i3" ]] && [[ -z "${DISPLAY_MANAGER}" ]]; then
    cat > /home/${USERNAME}/.xinitrc << XINITRC
#!/bin/sh
exec i3
XINITRC
    chown ${USERNAME}:${USERNAME} /home/${USERNAME}/.xinitrc
fi

# Configure NVIDIA for Hyprland/Sway if needed
if [[ "${HAS_NVIDIA}" == "yes" ]]; then
    # Create nvidia modprobe config
    cat > /etc/modprobe.d/nvidia.conf << NVIDIACONF
options nvidia_drm modeset=1
options nvidia_drm fbdev=1
NVIDIACONF
    
    # Add nvidia modules to initramfs
    sed -i 's/^MODULES=.*/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
    
    # Create pacman hook to rebuild initramfs on nvidia updates
    mkdir -p /etc/pacman.d/hooks
    cat > /etc/pacman.d/hooks/nvidia.hook << NVIDIAHOOK
[Trigger]
Operation=Install
Operation=Upgrade
Operation=Remove
Type=Package
Target=nvidia
Target=linux

[Action]
Description=Update NVIDIA module in initcpio
Depends=mkinitcpio
When=PostTransaction
NeedsTargets
Exec=/bin/sh -c 'while read -r trg; do case \\\$trg in linux*) exit 0; esac; done; /usr/bin/mkinitcpio -P'
NVIDIAHOOK
    
    # Set environment variables for Hyprland with NVIDIA
    if [[ "${DESKTOP_ENV}" == "hyprland" ]]; then
        mkdir -p /home/${USERNAME}/.config/hypr
        cat > /home/${USERNAME}/.config/hypr/env.conf << HYPRENV
# NVIDIA environment variables
env = LIBVA_DRIVER_NAME,nvidia
env = XDG_SESSION_TYPE,wayland
env = GBM_BACKEND,nvidia-drm
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = NVD_BACKEND,direct
HYPRENV
        chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.config
    fi
fi

# Configure sudo
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Configure reflector
mkdir -p /etc/xdg/reflector
cat > /etc/xdg/reflector/reflector.conf << EOF
--save /etc/pacman.d/mirrorlist
--country ${COUNTRY}
--protocol https
--latest 10
--sort rate
--age 12
EOF

# Regenerate initramfs
mkinitcpio -P

# Enable os-prober for dual-boot detection
if [[ "${DUAL_BOOT}" == "yes" ]]; then
    echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub
fi

# Install bootloader
if [[ "${BOOT_MODE}" == "UEFI" ]]; then
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=ARCH
else
    grub-install --target=i386-pc ${DISK}
fi
grub-mkconfig -o /boot/grub/grub.cfg

CHROOT_EOF

chmod +x /mnt/install-chroot.sh
arch-chroot /mnt /install-chroot.sh
rm /mnt/install-chroot.sh

print_msg "System configured"
print_msg "Bootloader installed"
print_msg "zswap enabled"

# ============================================================================
# FINISH
# ============================================================================
print_step "Unmounting partitions..."
umount -R /mnt

# Close LUKS container if used
if [[ "$USE_LUKS" == "yes" ]]; then
    cryptsetup close cryptroot
    print_msg "LUKS container closed"
fi

print_msg "Partitions unmounted"

print_header "Installation Complete!"
echo ""
echo -e "${GREEN}Your Arch Linux system is ready!${NC}"
echo ""
echo -e "${BOLD}Login credentials:${NC}"
echo -e "  Root user:    ${CYAN}root${NC}"
echo -e "  Regular user: ${CYAN}${USERNAME}${NC} (has sudo access)"
echo ""
echo -e "${BOLD}Features enabled:${NC}"
if [[ "$DESKTOP_ENV" != "none" ]]; then
    if [[ -n "$DISPLAY_MANAGER" ]]; then
        echo -e "  • ${MAGENTA}${DISPLAY_MANAGER}${NC} display manager with ${MAGENTA}${DESKTOP_ENV}${NC} desktop"
    else
        echo -e "  • ${MAGENTA}${DESKTOP_ENV}${NC} (start with: startx or sway)"
    fi
    echo -e "  • ${MAGENTA}PipeWire${NC} audio (pavucontrol for volume)"
    echo -e "  • ${MAGENTA}NetworkManager${NC} with system tray applet"
else
    echo -e "  • ${MAGENTA}CLI only${NC} - no desktop environment"
    echo -e "  • ${MAGENTA}NetworkManager${NC} (use nmtui or nmcli)"
fi
if [[ "$SHELL_CHOICE" == "zsh-ohmyzsh" ]]; then
    echo -e "  • ${MAGENTA}Zsh${NC} with ${MAGENTA}Oh-My-Zsh${NC} (agnoster theme)"
elif [[ "$SHELL_CHOICE" == "zsh" ]]; then
    echo -e "  • ${MAGENTA}Zsh${NC} shell"
fi
echo -e "  • ${MAGENTA}zswap${NC} for compressed swap in RAM"
echo -e "  • ${MAGENTA}tmpfs${NC} /tmp as RAM disk"
echo -e "  • ${MAGENTA}Reflector${NC} timer for automatic mirror updates"
if [[ "$FS_TYPE" == "btrfs" ]]; then
    echo -e "  • ${MAGENTA}Btrfs${NC} with subvolumes and zstd compression"
fi
if [[ "$USE_LUKS" == "yes" ]]; then
    echo -e "  • ${MAGENTA}LUKS${NC} full disk encryption"
fi
if [[ "$DUAL_BOOT" == "yes" ]]; then
    echo -e "  • ${MAGENTA}Dual-boot${NC} with Windows (os-prober enabled)"
fi
echo ""
if [[ "$USE_LUKS" == "yes" ]]; then
    echo -e "${BOLD}${YELLOW}Note:${NC} You will be prompted for your encryption password at boot."
    echo ""
fi
if [[ "$DESKTOP_ENV" == "i3" ]] && [[ -z "$DISPLAY_MANAGER" ]]; then
    echo -e "${BOLD}To start i3:${NC}"
    echo -e "  Login and run: ${CYAN}startx${NC}"
    echo ""
elif [[ "$DESKTOP_ENV" == "sway" ]]; then
    echo -e "${BOLD}To start Sway:${NC}"
    echo -e "  Login and run: ${CYAN}sway${NC}"
    echo ""
elif [[ "$DESKTOP_ENV" == "hyprland" ]]; then
    if [[ "$HAS_NVIDIA" == "yes" ]]; then
        echo -e "${BOLD}Hyprland with NVIDIA:${NC}"
        echo -e "  ${YELLOW}NVIDIA configured with modeset=1${NC}"
        echo ""
    fi
fi
prompt "Press Enter to reboot (or Ctrl+C to stay)..."
read
reboot
