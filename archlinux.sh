#!/bin/bash

## HELPERS ##
function fail() { echo "$1"; exit 1; }

## TARGETS ##
hostname=$1
disk=$2
disk_path="/dev/${disk}"
crypt="archlinux"
crypt_path="/dev/mapper/${crypt}"

## PRE-FLIGHT ##
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

## ENCRYPT ##
cryptsetup luksFormat $part_btrfs
cryptsetup luksOpen $part_btrfs $crypt

## FORMAT ##
mkfs.fat -F 32 $part_efi
mkfs.btrfs $crypt_path

## CREATE SUBVOLUMES ##
cd /mnt
mount $crypt_path /mnt
btrfs subvolume create @ @home @snapshots @swap @var_cache @var_log @var_tmp
umount /mnt

## MOUNT ##
cd /mnt
mkdir -p efi home .snapshots swap var/cache var/log var/tmp
mount $part_efi /mnt/efi
mount -o compress=zstd:1,subvol=@ $crypt_path /mnt
mount -o compress=zstd:1,subvol=@home $crypt_path /mnt/home
mount -o compress=zstd:1,subvol=@snapshots $crypt_path /mnt/.snapshots
mount -o compress=zstd:1,subvol=@swap $crypt_path /mnt/swap
mount -o compress=zstd:1,subvol=@var_cache $crypt_path /mnt/var/cache
mount -o compress=zstd:1,subvol=@var_log $crypt_path /mnt/var/log
mount -o compress=zstd:1,subvol=@var_tmp $crypt_path /mnt/var/tmp

## SWAP FILE ##
btrfs filesystem mkswapfile --size 16g --uuid clear /mnt/swap/swapfile






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


## MIRRORS ##

## INSTALL ESSENTIAL PACKAGES ##

## FSTAB ##
genfstab -U /mnt >> /mnt/etc/fstab

## CHROOT ##
arch-chroot /mnt

## TIME ##
ln -sf /usr/share/zoneinfo/America/Toronto /etc/localtime
hwclock --systohc

## LOCALE ##
## WIP: edit /etc/locale.gen and uncomment relevant locales, then run "locale-gen"
locale-gen
echo "LANG=en_US.UTF-8" >> /etc/locale.conf

## HOSTNAME ##
## WIP: prompt for hostname
echo $hostname >> /etc/hostname

## NETWORK CONFIG ##
## WIP

## Initramfs

## ROOT PASSWORD ##
passwd

## BOOT LOADER ##

## REBOOT ##
exit
umount -R /mnt
read -p "Ready to reboot. Proceed? (y/N): " confirm && [[ $confirm == [yY] ]] || exit 1
reboot
