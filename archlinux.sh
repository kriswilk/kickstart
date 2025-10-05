#!/bin/bash

## HELPERS ##

function fail() {
  echo "$1"
  exit 1
}

## INPUT ARGUMENTS ##

target_disk=$1

## PRE-FLIGHT CHECKS ##

if [ ! $target_disk ]; then
  fail "USAGE: ./archlinux.sh /dev/<disk>"
elif ! ls $target_disk &> /dev/null; then
  fail "ERROR: The specified disk does not exist."
elif ! cat /sys/firmware/efi/fw_platform_size | grep "64" &> /dev/null; then
  fail "ERROR: Not a UEFI system."
elif ! ping -c 1 ping.archlinux.org &> /dev/null; then
  fail "ERROR: No network connectivity."
elif ! timedatectl show | grep "NTPSynchronized=yes" &> /dev/null; then
  fail "ERROR: Clock requires synchronization."  
fi

## CONFIRMATION ##

read -p "WARNING: Disk $target_disk will be completely erased. Proceed? (y/N): " confirm && [[ $confirm == [yY] ]] || exit 1

## PARTITIONING ##

# 1 GB for EFI and the remainder for BTRFS
sgdisk $target_disk -Z -n 1:0:1G -t 1:ef00 -N 2 -t 2:8300

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
