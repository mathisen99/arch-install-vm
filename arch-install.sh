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
    echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} ${BOLD}$1${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
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

# List available disks
print_header "Available Disks"
echo -e "${CYAN}"
lsblk -d -o NAME,SIZE,MODEL | grep -v "loop\|sr"
echo -e "${NC}"

# Get disk selection
prompt "Enter the disk to install to (e.g., sda, vda):"
read DISK
DISK="/dev/${DISK}"

if [[ ! -b "$DISK" ]]; then
    print_error "Disk $DISK does not exist!"
    exit 1
fi

# Confirm disk selection
echo ""
print_warn "WARNING: This will ${RED}ERASE ALL DATA${NC}${YELLOW} on ${BOLD}$DISK${NC}"
prompt "Type 'yes' to continue:"
read CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
    print_info "Installation cancelled."
    exit 0
fi

# Get hostname
print_header "System Configuration"
prompt "Enter hostname for this machine [archlinux]:"
read HOSTNAME
HOSTNAME=${HOSTNAME:-archlinux}

# Validate hostname
if [[ ! "$HOSTNAME" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$ ]]; then
    print_warn "Invalid hostname, using 'archlinux'"
    HOSTNAME="archlinux"
fi

# Get timezone
echo ""
print_info "Example timezones: Europe/Oslo, America/New_York, Asia/Tokyo, UTC"
prompt "Enter your timezone [UTC]:"
read TIMEZONE
TIMEZONE=${TIMEZONE:-UTC}

# Verify timezone exists
if [[ ! -f "/usr/share/zoneinfo/$TIMEZONE" ]]; then
    print_warn "Timezone '$TIMEZONE' not found, using UTC"
    TIMEZONE="UTC"
fi

# Get locale
echo ""
print_info "Example locales: en_US, en_GB, de_DE, nb_NO"
prompt "Enter your locale [en_US]:"
read LOCALE
LOCALE=${LOCALE:-en_US}

# Get keymap
echo ""
print_info "Example keymaps: us, uk, de, no"
prompt "Enter console keymap [us]:"
read KEYMAP
KEYMAP=${KEYMAP:-us}

# Get root password
print_header "Root Password Setup"
while true; do
    prompt "Enter root password:"
    read -s ROOT_PASSWORD
    echo ""
    prompt "Confirm root password:"
    read -s ROOT_PASSWORD_CONFIRM
    echo ""
    if [[ "$ROOT_PASSWORD" == "$ROOT_PASSWORD_CONFIRM" ]]; then
        if [[ -z "$ROOT_PASSWORD" ]]; then
            print_warn "Password cannot be empty!"
        else
            print_msg "Root password set"
            break
        fi
    else
        print_warn "Passwords do not match, try again."
    fi
done

# Get username
print_header "User Account Setup"
prompt "Enter username for regular user [user]:"
read USERNAME
USERNAME=${USERNAME:-user}

# Validate username
if [[ ! "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
    print_warn "Invalid username, using 'user'"
    USERNAME="user"
fi

# Get user password
while true; do
    prompt "Enter password for $USERNAME:"
    read -s USER_PASSWORD
    echo ""
    prompt "Confirm password for $USERNAME:"
    read -s USER_PASSWORD_CONFIRM
    echo ""
    if [[ "$USER_PASSWORD" == "$USER_PASSWORD_CONFIRM" ]]; then
        if [[ -z "$USER_PASSWORD" ]]; then
            print_warn "Password cannot be empty!"
        else
            print_msg "User password set"
            break
        fi
    else
        print_warn "Passwords do not match, try again."
    fi
done

# Summary
print_header "Installation Summary"
echo -e "  ${BOLD}Disk:${NC}       $DISK"
echo -e "  ${BOLD}Boot Mode:${NC}  $BOOT_MODE"
echo -e "  ${BOLD}Hostname:${NC}   $HOSTNAME"
echo -e "  ${BOLD}Timezone:${NC}   $TIMEZONE"
echo -e "  ${BOLD}Locale:${NC}     ${LOCALE}.UTF-8"
echo -e "  ${BOLD}Keymap:${NC}     $KEYMAP"
echo -e "  ${BOLD}Username:${NC}   $USERNAME"
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

if [[ "$BOOT_MODE" == "UEFI" ]]; then
    # UEFI partitioning with GPT
    parted -s "$DISK" mklabel gpt
    parted -s "$DISK" mkpart "EFI" fat32 1MiB 513MiB
    parted -s "$DISK" set 1 esp on
    parted -s "$DISK" mkpart "swap" linux-swap 513MiB 4609MiB
    parted -s "$DISK" mkpart "root" ext4 4609MiB 100%
    
    # Determine partition naming
    if [[ "$DISK" == *"nvme"* ]] || [[ "$DISK" == *"mmcblk"* ]]; then
        PART_PREFIX="${DISK}p"
    else
        PART_PREFIX="${DISK}"
    fi
    
    EFI_PART="${PART_PREFIX}1"
    SWAP_PART="${PART_PREFIX}2"
    ROOT_PART="${PART_PREFIX}3"
    
    print_msg "Created GPT partition table"
    print_info "  EFI:  ${EFI_PART} (512MB)"
    print_info "  Swap: ${SWAP_PART} (4GB)"
    print_info "  Root: ${ROOT_PART} (remaining)"
    
    # Wait for partitions to appear
    sleep 2
    partprobe "$DISK" 2>/dev/null || true
    sleep 1
    
    # Format partitions
    print_step "Formatting partitions..."
    mkfs.fat -F32 "$EFI_PART" &>/dev/null
    print_msg "Formatted EFI partition (FAT32)"
    mkswap "$SWAP_PART" &>/dev/null
    print_msg "Formatted swap partition"
    mkfs.ext4 -F "$ROOT_PART" &>/dev/null
    print_msg "Formatted root partition (ext4)"
    
    # Mount partitions
    print_step "Mounting partitions..."
    mount "$ROOT_PART" /mnt
    mkdir -p /mnt/boot
    mount "$EFI_PART" /mnt/boot
    swapon "$SWAP_PART"
    print_msg "All partitions mounted"
    
else
    # BIOS partitioning with MBR
    parted -s "$DISK" mklabel msdos
    parted -s "$DISK" mkpart primary linux-swap 1MiB 4097MiB
    parted -s "$DISK" mkpart primary ext4 4097MiB 100%
    parted -s "$DISK" set 2 boot on
    
    # Determine partition naming
    if [[ "$DISK" == *"nvme"* ]] || [[ "$DISK" == *"mmcblk"* ]]; then
        PART_PREFIX="${DISK}p"
    else
        PART_PREFIX="${DISK}"
    fi
    
    SWAP_PART="${PART_PREFIX}1"
    ROOT_PART="${PART_PREFIX}2"
    
    print_msg "Created MBR partition table"
    print_info "  Swap: ${SWAP_PART} (4GB)"
    print_info "  Root: ${ROOT_PART} (remaining)"
    
    # Wait for partitions to appear
    sleep 2
    partprobe "$DISK" 2>/dev/null || true
    sleep 1
    
    # Format partitions
    print_step "Formatting partitions..."
    mkswap "$SWAP_PART" &>/dev/null
    print_msg "Formatted swap partition"
    mkfs.ext4 -F "$ROOT_PART" &>/dev/null
    print_msg "Formatted root partition (ext4)"
    
    # Mount partitions
    print_step "Mounting partitions..."
    mount "$ROOT_PART" /mnt
    swapon "$SWAP_PART"
    print_msg "All partitions mounted"
fi

# Install base system
print_step "Installing base system (this may take a while)..."
PACKAGES="base base-devel linux linux-firmware networkmanager grub sudo nano vim"

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

# Generate fstab
print_step "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab
print_msg "fstab generated"

# Create chroot script
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

# Enable NetworkManager
systemctl enable NetworkManager

# Set root password
echo "root:${ROOT_PASSWORD}" | chpasswd

# Create user with proper groups
useradd -m -G wheel,audio,video,storage,optical -s /bin/bash ${USERNAME}
echo "${USERNAME}:${USER_PASSWORD}" | chpasswd

# Configure sudo - uncomment wheel group line
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

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

# Unmount and finish
print_step "Unmounting partitions..."
umount -R /mnt
swapoff -a
print_msg "Partitions unmounted"

print_header "Installation Complete!"
echo ""
echo -e "${GREEN}Your Arch Linux system is ready!${NC}"
echo ""
echo -e "${BOLD}Login credentials:${NC}"
echo -e "  Root user:    ${CYAN}root${NC}"
echo -e "  Regular user: ${CYAN}${USERNAME}${NC} (has sudo access)"
echo ""
echo -e "${BOLD}After reboot:${NC}"
echo -e "  • NetworkManager will start automatically"
echo -e "  • Use ${CYAN}nmtui${NC} or ${CYAN}nmcli${NC} to manage connections"
echo ""
prompt "Press Enter to reboot (or Ctrl+C to stay)..."
read
reboot
