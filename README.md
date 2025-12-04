# Mathisen's Arch Install Script for VMs

A simple, interactive script to auto-install Arch Linux inside QEMU/KVM virtual machines.

## Features

- Auto-detects UEFI or BIOS boot mode
- Partitions entire disk automatically (EFI + swap + root)
- Installs base system with essential packages
- NetworkManager enabled at boot
- Sets up root user with password
- Creates regular user with sudo access
- Installs and configures GRUB bootloader

## Usage

Boot your QEMU VM from the Arch Linux live ISO, then run:

```bash
bash <(curl -sL https://raw.githubusercontent.com/mathisen99/arch-install-vm/main/arch-install.sh)
```

Or download and run manually:

```bash
curl -sLO https://raw.githubusercontent.com/mathisen99/arch-install-vm/main/arch-install.sh
chmod +x arch-install.sh
./arch-install.sh
```

## What You'll Be Asked

1. **Disk** - Which disk to install to (e.g., `sda`, `vda`)
2. **Hostname** - Name for your machine
3. **Timezone** - Your timezone (e.g., `Europe/Oslo`, `America/New_York`)
4. **Root password** - Password for root account
5. **Username** - Name for your regular user
6. **User password** - Password for your regular user

## Installed Packages

- `base` - Core system
- `linux` - Linux kernel
- `linux-firmware` - Firmware files
- `networkmanager` - Network management
- `grub` - Bootloader
- `sudo` - Privilege escalation
- `nano` - Text editor

## Requirements

- QEMU/KVM virtual machine
- Arch Linux live ISO
- Internet connection
- At least 8GB disk space recommended

## After Installation

The system will reboot automatically. Log in with your created user and you're ready to go.

NetworkManager starts automatically - use `nmtui` or `nmcli` to manage network connections.

## License

Do whatever you want with it.
# arch-install-vm
