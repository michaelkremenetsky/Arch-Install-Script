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

pacstrap /mnt base linux linux-firmware networkmanager $extraPackages

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

# Start Network Manager Service
arch-chroot /mnt systemctl enable NetworkManager

# Add User
arch-chroot /mnt useradd -mG wheel michael

# set password for user
arch-chroot /mnt passwd michael

# Change wheel config
cat > /etc/sudoers <<EOF
## sudoers file.
##
## This file MUST be edited with the 'visudo' command as root.
## Failure to use 'visudo' may result in syntax or file permission errors
## that prevent sudo from running.
##
## See the sudoers man page for the details on how to write a sudoers file.
##
##
## Host alias specification
##
## Groups of machines. These may include host names (optionally with wildcards),
## IP addresses, network numbers or netgroups.
# Host_Alias	WEBSERVERS = www1, www2, www3
##
## User alias specification
##
## Groups of users.  These may consist of user names, uids, Unix groups,
## or netgroups.
# User_Alias	ADMINS = millert, dowdy, mikef
##
## Cmnd alias specification
##
## Groups of commands.  Often used to group related commands together.
# Cmnd_Alias	PROCESSES = /usr/bin/nice, /bin/kill, /usr/bin/renice, \
# 			    /usr/bin/pkill, /usr/bin/top
##
## Defaults specification
##
## You may wish to keep some of the following environment variables
## when running commands via sudo.
##
## Locale settings
# Defaults env_keep += "LANG LANGUAGE LINGUAS LC_* _XKB_CHARSET"
##
## Run X applications through sudo; HOME is used to find the
## .Xauthority file.  Note that other programs use HOME to find   
## configuration files and this may lead to privilege escalation!
# Defaults env_keep += "HOME"
##
## X11 resource path settings
# Defaults env_keep += "XAPPLRESDIR XFILESEARCHPATH XUSERFILESEARCHPATH"
##
## Desktop path settings
# Defaults env_keep += "QTDIR KDEDIR"
##
## Allow sudo-run commands to inherit the callers' ConsoleKit session
# Defaults env_keep += "XDG_SESSION_COOKIE"
##
## Uncomment to enable special input methods.  Care should be taken as
## this may allow users to subvert the command being run via sudo.
# Defaults env_keep += "XMODIFIERS GTK_IM_MODULE QT_IM_MODULE QT_IM_SWITCHER"
##
## Uncomment to enable logging of a command's output, except for
## sudoreplay and reboot.  Use sudoreplay to play back logged sessions.
# Defaults log_output
# Defaults!/usr/bin/sudoreplay !log_output
# Defaults!/usr/local/bin/sudoreplay !log_output
# Defaults!/sbin/reboot !log_output
##
## Runas alias specification
##
##
## User privilege specification
##
root ALL=(ALL) ALL
## Uncomment to allow members of group wheel to execute any command
%wheel ALL=(ALL) ALL
## Same thing without a password
# %wheel ALL=(ALL) NOPASSWD: ALL
## Uncomment to allow members of group sudo to execute any command
# %sudo ALL=(ALL) ALL
## Uncomment to allow any user to run sudo if they know the password
## of the user they are running the command as (root by default).
# Defaults targetpw  # Ask for the password of the target user
# ALL ALL=(ALL) ALL  # WARNING: only use this together with 'Defaults targetpw'
%rfkill ALL=(ALL) NOPASSWD: /usr/sbin/rfkill
%network ALL=(ALL) NOPASSWD: /usr/bin/netcfg, /usr/bin/wifi-menu
## Read drop-in files from /etc/sudoers.d
## (the '#' here does not indicate a comment)
#includedir /etc/sudoers.d
EOF

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

# Clone Post Install Script
arch-chroot /mnt git clone https://github.com/michaelkremenetsky/Personal-Arch-Script
