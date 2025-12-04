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
# DESKTOP ENVIRONMENT SELECTION
# ============================================================================
print_header "Desktop Environment Selection"

DESKTOP_ENV=$(dialog --clear --title "Desktop Environment" \
    --menu "Choose your desktop environment:" 18 70 10 \
    "xfce" "XFCE4 - Lightweight, traditional desktop" \
    "gnome" "GNOME - Modern, full-featured desktop" \
    "kde" "KDE Plasma - Feature-rich, customizable" \
    "cinnamon" "Cinnamon - Traditional, Windows-like" \
    "mate" "MATE - Classic GNOME 2 fork" \
    "lxqt" "LXQt - Lightweight Qt desktop" \
    "budgie" "Budgie - Modern, elegant desktop" \
    "i3" "i3 - Tiling window manager" \
    "sway" "Sway - i3-compatible Wayland compositor" \
    "none" "No desktop - CLI only" 2>&1 >/dev/tty)

clear
print_msg "Selected desktop: ${BOLD}${DESKTOP_ENV}${NC}"

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

# Confirm disk selection
dialog --clear --title "WARNING" \
    --yesno "This will ERASE ALL DATA on ${DISK}\n\nAre you sure you want to continue?" 8 50
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
echo -e "  ${BOLD}Filesystem:${NC}  $FS_TYPE"
echo -e "  ${BOLD}Boot Mode:${NC}   $BOOT_MODE"
echo -e "  ${BOLD}Hostname:${NC}    $HOSTNAME"
echo -e "  ${BOLD}Timezone:${NC}    $TIMEZONE"
echo -e "  ${BOLD}Locale:${NC}      ${LOCALE}.UTF-8"
echo -e "  ${BOLD}Keymap:${NC}      $KEYMAP"
echo -e "  ${BOLD}Username:${NC}    $USERNAME"
echo -e "  ${BOLD}Shell:${NC}       $SHELL_CHOICE"
echo -e "  ${BOLD}Desktop:${NC}     $DESKTOP_ENV"
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

# Wipe existing partition table
wipefs -af "$DISK" &>/dev/null
print_msg "Wiped existing partition table"

# Determine partition naming
if [[ "$DISK" == *"nvme"* ]] || [[ "$DISK" == *"mmcblk"* ]]; then
    PART_PREFIX="${DISK}p"
else
    PART_PREFIX="${DISK}"
fi

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

# Wait for partitions to appear
sleep 2
partprobe "$DISK" 2>/dev/null || true
sleep 1

# Format partitions
print_step "Formatting partitions..."

if [[ "$BOOT_MODE" == "UEFI" ]]; then
    mkfs.fat -F32 "$EFI_PART" &>/dev/null
    print_msg "Formatted EFI partition (FAT32)"
fi

if [[ "$FS_TYPE" == "btrfs" ]]; then
    mkfs.btrfs -f "$ROOT_PART" &>/dev/null
    print_msg "Formatted root partition (btrfs)"
    
    # Mount and create subvolumes
    print_step "Creating btrfs subvolumes..."
    mount "$ROOT_PART" /mnt
    
    btrfs subvolume create /mnt/@ &>/dev/null
    btrfs subvolume create /mnt/@home &>/dev/null
    btrfs subvolume create /mnt/@snapshots &>/dev/null
    btrfs subvolume create /mnt/@var_log &>/dev/null
    
    print_msg "Created subvolumes: @, @home, @snapshots, @var_log"
    
    umount /mnt
    
    # Mount subvolumes with optimal options
    BTRFS_OPTS="noatime,compress=zstd,space_cache=v2,discard=async"
    
    mount -o subvol=@,${BTRFS_OPTS} "$ROOT_PART" /mnt
    mkdir -p /mnt/{home,.snapshots,var/log,boot}
    mount -o subvol=@home,${BTRFS_OPTS} "$ROOT_PART" /mnt/home
    mount -o subvol=@snapshots,${BTRFS_OPTS} "$ROOT_PART" /mnt/.snapshots
    mount -o subvol=@var_log,${BTRFS_OPTS} "$ROOT_PART" /mnt/var/log
    
    print_msg "Mounted btrfs subvolumes with compression"
else
    mkfs.ext4 -F "$ROOT_PART" &>/dev/null
    print_msg "Formatted root partition (ext4)"
    mount "$ROOT_PART" /mnt
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
PACKAGES="base base-devel linux linux-firmware networkmanager grub sudo nano vim"
PACKAGES="$PACKAGES reflector"

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
    esac
    
    pacstrap /mnt $DESKTOP_PACKAGES
    print_msg "${DESKTOP_ENV} desktop installed"
    
    # Install audio
    print_step "Installing PipeWire audio stack..."
    AUDIO_PACKAGES="pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber"
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
echo ""
if [[ "$DESKTOP_ENV" == "i3" ]] && [[ -z "$DISPLAY_MANAGER" ]]; then
    echo -e "${BOLD}To start i3:${NC}"
    echo -e "  Login and run: ${CYAN}startx${NC}"
    echo ""
elif [[ "$DESKTOP_ENV" == "sway" ]]; then
    echo -e "${BOLD}To start Sway:${NC}"
    echo -e "  Login and run: ${CYAN}sway${NC}"
    echo ""
fi
prompt "Press Enter to reboot (or Ctrl+C to stay)..."
read
reboot
