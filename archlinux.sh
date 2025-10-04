#!/bin/bash

## PREREQUISITES ##

if ! cat /sys/firmware/efi/fw_platform_size | grep "64" &> /dev/null; then
  echo "ERROR: Not a UEFI system."
  exit 1
fi

if ! ping -c 1 ping.archlinux.org &> /dev/null; then
  echo "ERROR: No network connectivity."
  exit 1
fi

if ! timedatectl show | grep "NTPSynchronized=yes" &> /dev/null; then
  echo "ERROR: Clock requires synchronization."
  exit 1
fi

## PARTITIONING ##

# 1 GB EFI partition, remainder as Linux filesystem
sgdisk $1 -Z -n 1:0:1G -t 1:ef00 -N 2 -t 2:8300

## FORMAT / ENCRYPT ##

# EFI
mkfs.fat -F 32 /dev/sda1
# BTRFS (encrypted)
cryptsetup luksFormat /dev/sda2
cryptsetup luksOpen /dev/sda2 archlinux
mkfs.btrfs /dev/mapper/archlinux

mount /dev/mapper/archlinux /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@swap
btrfs subvolume create /mnt/@var_cache
btrfs subvolume create /mnt/@var_log
btrfs subvolume create /mnt/@var_tmp
umount /mnt

# MOUNT
mount -o compress=zstd:1,subvol=@ /dev/mapper/archlinux /mnt

mkdir -p /mnt/home
mount -o compress=zstd:1,subvol=@home /dev/mapper/archlinux /mnt/home

mkdir -p /mnt/.snapshots
mount -o compress=zstd:1,subvol=@snapshots /dev/mapper/archlinux /mnt/.snapshots

mkdir -p /mnt/swap
mount -o compress=zstd:1,subvol=@swap /dev/mapper/archlinux /mnt/swap
btrfs filesystem mkswapfile --size 16g --uuid clear /mnt/swap/swapfile

mkdir -p /mnt/var/cache
mount -o compress=zstd:1,subvol=@var_cache /dev/mapper/archlinux /mnt/var/cache

mkdir -p /mnt/var/log
mount -o compress=zstd:1,subvol=@var_log /dev/mapper/archlinux /mnt/var/log

mkdir -p /mnt/var/tmp
mount -o compress=zstd:1,subvol=@var_tmp /dev/mapper/archlinux /mnt/var/tmp

mkdir -p /mnt/efi
mount /dev/sda1 /mnt/efi


btrfs subvolume create /root/swap # create the subvolume
mkdir /swap                       # create the mountpoint directory
mount /swap                       # mount the subvolume on /swap, reads settings from /etc/fstab
chmod 0700 /swap                  # tighten up permissions to -rwx------
touch /swap/file                  # create an empty file
chmod 0600 /swap/file             # tighten up permissions to -rw-------
chattr +C /swap/file              # mark the file as ineligible for copy-on-write
dd if=/dev/zero of=/swap/file bs=4096 count=16777216 # write out 64GB of zeroed pages
mkswap /swap/file                 # write swap signature to the file
swapon -a                         # turn it on!
free                              # display available memory and swap
