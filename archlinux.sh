#!/bin/bash

## HELPERS ##
function fail() { echo "$1"; exit 1; }
function confirm_y() { read -p "$1 [Y/n]: " confirm && [[ $confirm == [nN] ]] && exit 1; }
function confirm_n() { read -p "$1 [y/N]: " confirm && [[ $confirm == [yY] ]] || exit 1; }

## TARGETS ##
hostname=$1
disk=$2
disk_path="/dev/${disk}"

## PRE-FLIGHT ##
echo "PRE-FLIGHT CHECKS..."
if [ ! -e $disk_path ]; then
  fail "ERROR: Disk $disk_path does not exist. USAGE: ./archlinux.sh <hostname> <disk>"
elif ! cat /sys/firmware/efi/fw_platform_size | grep "64" &> /dev/null; then
  fail "ERROR: Not a UEFI system."
elif ! ping -c 1 ping.archlinux.org &> /dev/null; then
  fail "ERROR: No network connectivity."
elif ! timedatectl show | grep "NTPSynchronized=yes" &> /dev/null; then
  fail "ERROR: Clock requires synchronization."  
fi

## CONFIRM ##
confirm_n "WARNING: Disk $disk_path will be completely erased. Proceed?"

## PARTITION ##
echo "PARTITIONING..."
# 1 GB EFI, remainder Linux filesystem
sgdisk $disk_path -Z -n 1:0:1G -t 1:ef00 -N 2 -t 2:8300

if [[ -e "${disk_path}1" && -e "${disk_path}2" ]]; then
  part_efi="${disk_path}1"
  part_btrfs="${disk_path}2"
  crypt="${disk}2_crypt"
elif [[ -e "${disk_path}p1" && -e "${disk_path}p2" ]]; then
  part_efi="${disk_path}p1"
  part_btrfs="${disk_path}p2"
  crypt="${disk}p2_crypt"
else
  fail "ERROR: Disk partition(s) missing."
fi

## ENCRYPT ##
echo "ENCRYPTION..."
cryptsetup luksFormat $part_btrfs
cryptsetup luksOpen $part_btrfs $crypt
crypt_path="/dev/mapper/${crypt}"

## FORMAT ##
echo "FORMATTING..."
mkfs.fat -F 32 $part_efi
mkfs.btrfs $crypt_path

## CREATE SUBVOLUMES ##
echo "CREATING SUBVOLUMES..."
mount $crypt_path /mnt
btrfs subvolume create /mnt/{@,@home,@snapshots,@swap,@var_cache,@var_log,@var_tmp}
umount /mnt

## MOUNT ##
echo "MOUNTING PARTITIONS / SUBVOLUMES"
# mount root subvolume
mount -o noatime,compress=zstd:1,subvol=@ $crypt_path /mnt
# create mount points
mkdir -p /mnt/{efi,home,.snapshots,swap,var/cache,var/log,var/tmp}
# mount partitions / subvolumes
mount $part_efi /mnt/efi
mount -o noatime,compress=zstd:1,subvol=@home $crypt_path /mnt/home
mount -o noatime,compress=zstd:1,subvol=@snapshots $crypt_path /mnt/.snapshots
mount -o noatime,compress=zstd:1,subvol=@swap $crypt_path /mnt/swap
mount -o noatime,compress=zstd:1,subvol=@var_cache $crypt_path /mnt/var/cache
mount -o noatime,compress=zstd:1,subvol=@var_log $crypt_path /mnt/var/log
mount -o noatime,compress=zstd:1,subvol=@var_tmp $crypt_path /mnt/var/tmp

## SWAP FILE ##
echo "CREATING SWAP FILE..."
btrfs filesystem mkswapfile --size 16g --uuid clear /mnt/swap/swapfile
swapon /mnt/swap/swapfile

## MIRRORS ##
echo "CONFIGURING MIRRORS..."
reflector --country CA --delay 1 --fastest 10 --sort rate --save /etc/pacman.d/mirrorlist --verbose

## INSTALL ESSENTIAL PACKAGES ##
## WIP: update packages first?
pacstrap -K /mnt base linux \
                 intel-ucode amd-ucode \                 
                 # userspace utils for filesystems:
                 # raid/lvm:
                 # firmware: linux-firmware linux-firmware-marvell \
                 
                 # other packages: vim nano
## WIP: will amd/intel microcode coexist??

## FSTAB ##
genfstab -U /mnt >> /mnt/etc/fstab
## WIP: need to remove subvolid from fstab?? or is it not put in there anymore?

## CHROOT ##
arch-chroot /mnt

## TIME ##
arch-chroot /mnt ln -sf /usr/share/zoneinfo/America/Toronto /etc/localtime
arch-chroot /mnt hwclock --systohc

## LOCALE ##
arch-chroot /mnt echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
arch-chroot /mnt locale-gen
arch-chroot /mnt echo "LANG=en_US.UTF-8" > /etc/locale.conf

## HOSTNAME ##
arch-chroot /mnt echo $hostname > /etc/hostname

## NETWORK CONFIG ##
## WIP

## Initramfs

## ROOT PASSWORD ##
arch-chroot /mnt passwd

## BOOT LOADER ##
## WIP: this is systemd-boot...change to grub for snapshots?
arch-chroot /mnt bootctl install

## REBOOT ##
umount -R /mnt
cryptsetup luksClose $crypt
confirm_y "Ready to reboot. Proceed?"
reboot
