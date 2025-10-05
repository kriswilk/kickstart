#!/bin/bash

## HELPERS ##
function fail() { echo "$1"; exit 1; }

## VARIABLES ##
disk=$1
disk_path="/dev/${disk}"
crypt="archlinux"
crypt_map="/dev/mapper/${crypt}"

## PRE-FLIGHT ##
if [ ! -e $disk_path ]; then
  fail "ERROR: The specified disk does not exist. USAGE: ./archlinux.sh <disk> (eg. sda, nvme0n1, ...)"
elif ! cat /sys/firmware/efi/fw_platform_size | grep "64" &> /dev/null; then
  fail "ERROR: Not a UEFI system."
elif ! ping -c 1 ping.archlinux.org &> /dev/null; then
  fail "ERROR: No network connectivity."
elif ! timedatectl show | grep "NTPSynchronized=yes" &> /dev/null; then
  fail "ERROR: Clock requires synchronization."  
fi

## CONFIRM ##
read -p "WARNING: Disk $disk_path will be completely erased. Proceed? (y/N): " confirm && [[ $confirm == [yY] ]] || exit 1

## PARTITION ##
# 1 GB EFI, remainder Linux filesystem
sgdisk $disk_path -Z -n 1:0:1G -t 1:ef00 -N 2 -t 2:8300

if [[ -e "${disk_path}1" && -e "${disk_path}2" ]]; then
  part_efi="${disk_path}1"
  part_btrfs="${disk_path}2"
elif [[ -e "${disk_path}p1" && -e "${disk_path}p2" ]]; then
  part_efi="${disk_path}p1"
  part_btrfs="${disk_path}p2"
else
  fail "ERROR: Disk partition(s) missing."
fi

## ENCRYPTION ##
cryptsetup luksFormat $part_btrfs
cryptsetup luksOpen $part_btrfs $crypt

# EFI
mkfs.fat -F 32 $part_efi
# BTRFS (encrypted)
mkfs.btrfs $crypt_map

mount $crypt_map /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@swap
btrfs subvolume create /mnt/@var_cache
btrfs subvolume create /mnt/@var_log
btrfs subvolume create /mnt/@var_tmp
umount /mnt

# MOUNT
mkdir -p /mnt/efi
mount $part_efi /mnt/efi

mkdir -p /mnt/home
mkdir -p /mnt/.snapshots
mkdir -p /mnt/swap
mkdir -p /mnt/var/cache
mkdir -p /mnt/var/log
mkdir -p /mnt/var/tmp

mount -o compress=zstd:1,subvol=@ $crypt_map /mnt

mount -o compress=zstd:1,subvol=@home $crypt_map /mnt/home

mount -o compress=zstd:1,subvol=@snapshots $crypt_map /mnt/.snapshots

mount -o compress=zstd:1,subvol=@swap $crypt_map /mnt/swap
btrfs filesystem mkswapfile --size 16g --uuid clear /mnt/swap/swapfile

mount -o compress=zstd:1,subvol=@var_cache $crypt_map /mnt/var/cache

mount -o compress=zstd:1,subvol=@var_log $crypt_map /mnt/var/log

mount -o compress=zstd:1,subvol=@var_tmp $crypt_map /mnt/var/tmp








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
