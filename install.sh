 #!/bin/bash

bootloader="systemd-boot" # systemd-boot or GRUB

# Load Keymap
loadkeys us

# Set System Clock
timedatectl set-ntp true
timedatectl status


# Setup Partitions
# See on Arch Wiki: https:#wiki.archlinux.org/title/Parted
# The -s makes it so it doesn't prompt for user intervention

# Make GPT Partition Table
parted -s /dev/sda mklabel gpt

# Creates EFI partition
# "EFI system partition" doesn't seem to work so I am using EFI instead
parted -s /dev/sda mkpart EFI fat32 1MiB 261MiB set 1 esp on

# Create the rest of the partition
parted -s /dev/sda mkpart "main" ext4 261MiB 100%

# Creating filesystem for EFI partition
mkfs.fat -F32 /dev/sda1

# Create filesystem for main partition
mkfs.ext4 /dev/sda2

# Mount main partition
mount /dev/sda2 /mnt

# Create /mnt/boot folder
mkdir /mnt/boot
# Mount EFI partition
mount /dev/sda1 /mnt/boot

# Run pacstrap
# TODO - add ucode soon
extraPackages="neovim"

pacstrap /mnt base linux linux-firmware $extraPackages

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# I have to add arch-chroot /mnt onto every command from here on

# Set Timezone
arch-chroot /mnt ln -sf /usr/share/zoneinfo/America/Los_Angeles /etc/localtime
arch-chroot /mnt hwclock --systohc

# Setup locale
arch-chroot /mnt locale-gen
cat <<EOT > "/mnt/etc/locale.conf"
LANG=en_US.UTF-8
EOT

# Setup hostname and hosts
cat <<EOT > "/mnt/etc/hostname"
michael
EOT
arch-chroot /mnt touch /etc/hosts
arch-chroot /mnt echo michael > /etc/hosts
cat <<EOT > "/mnt/etc/hosts"
127.0.0.1	localhost
::1		localhost
127.0.1.1	michael
EOT

# set password
arch-chroot /mnt passwd

if [ $bootloader == "systemd-boot" ]
then
  # Install bootloader
  arch-chroot /mnt bootctl install


  # Configure the loader.conf
  arch-chroot /mnt touch /boot/loader/loader.conf
  cat <<EOT > "/boot/loader/loader.conf"
timeout 4
default arch.conf
EOT
  # setup /loader/entries/arch.conf
  # TODO - Add the ucode 
  # add "initrd  /intel-ucode.img" soon
  # the rw means read and write
  arch-chroot /mnt touch /boot/loader/entries/arch.conf
  cat <<EOT > "/boot/loader/entries/arch.conf"
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=/dev/sda2 rw
EOT
fi

if [ $bootloader == "GRUB" ]
then
  arch-chroot /mnt pacman -S efibootmgr grub
  arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
  arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
fi
