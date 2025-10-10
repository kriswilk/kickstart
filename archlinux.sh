#!/bin/bash

## HELPERS ##
function fail() { echo -e "\e[0;31m$1\e[0m"; exit 1; }
function notify() { echo -e "\n\e[1;33m$1\e[0m"; sleep 1; }
function confirm_y() { read -p "$1 [Y/n]: " ans && [[ $ans == [nN] ]] && exit 1; }
function confirm_n() { read -p "$1 [y/N]: " ans && [[ $ans == [yY] ]] || exit 1; }

hostname=$1
disk="/dev/$2"

notify "PRE-FLIGHT CHECKS..."
if [[ $# != 2 ]]; then
  fail "ERROR: Missing input. Expected arguments are <hostname> <disk> (eg. ./script.sh thinkpad nvme0n1)"
elif [[ ! -e $disk ]]; then
  fail "ERROR: Disk $disk does not exist."
elif ! cat /sys/firmware/efi/fw_platform_size | grep "64" &> /dev/null; then
  fail "ERROR: Not a UEFI system."
elif ! ping -c 1 ping.archlinux.org &> /dev/null; then
  fail "ERROR: No network connectivity."
elif ! timedatectl show | grep "NTPSynchronized=yes" &> /dev/null; then
  fail "ERROR: Clock requires synchronization."  
fi

notify "CONFIRMATION..."
confirm_n "WARNING: Disk $disk will be completely erased. Proceed?"

notify "PARTITIONING..."
sgdisk $disk -Z -n 1:0:1G -t 1:ef00 -N 2 -t 2:8309
if [[ -e "${disk}1" && -e "${disk}2" ]]; then
  efi="${disk}1"
  btrfs="${disk}2"
elif [[ -e "${disk}p1" && -e "${disk}p2" ]]; then
  efi="${disk}p1"
  btrfs="${disk}p2"
else
  fail "ERROR: Disk partition(s) missing."
fi

notify "ENCRYPTION..."
cryptsetup luksFormat $btrfs
cryptsetup open --type luks $btrfs archlinux
crypt="/dev/mapper/archlinux"

notify "FORMATTING..."
mkfs.fat -F 32 $efi
mkfs.btrfs $crypt

notify "CREATING SUBVOLUMES..."
mount $crypt /mnt
btrfs subvolume create /mnt/{@,@home,@snapshots,@swap,@var_cache,@var_log,@var_tmp}
umount /mnt

notify "MOUNTING PARTITIONS / SUBVOLUMES..."
# mount root subvolume
mount -o noatime,compress=zstd:1,subvol=@ $crypt /mnt
# create mount points
mkdir -p /mnt/{efi,home,.snapshots,swap,var/cache,var/log,var/tmp}
# mount partitions / subvolumes
mount $efi /mnt/efi
mount -o noatime,compress=zstd:1,subvol=@home $crypt /mnt/home
mount -o noatime,compress=zstd:1,subvol=@snapshots $crypt /mnt/.snapshots
mount -o noatime,compress=zstd:1,subvol=@swap $crypt /mnt/swap
mount -o noatime,compress=zstd:1,subvol=@var_cache $crypt /mnt/var/cache
mount -o noatime,compress=zstd:1,subvol=@var_log $crypt /mnt/var/log
mount -o noatime,compress=zstd:1,subvol=@var_tmp $crypt /mnt/var/tmp

notify "CREATING SWAP FILE..."
btrfs filesystem mkswapfile --size 16g --uuid clear /mnt/swap/swapfile
swapon /mnt/swap/swapfile

notify "GENERATING MIRRORLIST..."
reflector --country CA --delay 1 --fastest 10 --sort rate --save /etc/pacman.d/mirrorlist --verbose

## WIP: update packages first?
notify "INSTALLING PACKAGES..."
pacstrap -K /mnt base linux \
                 intel-ucode amd-ucode \
                 vim nano
                 # userspace utils for filesystems:
                 # raid/lvm:
                 # firmware: linux-firmware linux-firmware-marvell \
                 
                 # other packages: vim nano
## WIP: will amd/intel microcode coexist??

notify "GENERATING FSTAB..."
genfstab -U /mnt > /mnt/etc/fstab
## WIP: need to remove subvolid from fstab?? or is it not put in there anymore?

notify "SETTING TIME ZONE..."
arch-chroot /mnt ln -sf /usr/share/zoneinfo/America/Toronto /etc/localtime
arch-chroot /mnt hwclock --systohc

notify "SETTING LOCALE..."
echo "en_US.UTF-8 UTF-8" >> /mnt/etc/locale.gen
arch-chroot /mnt locale-gen
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf

notify "SETTING HOSTNAME..."
echo $hostname > /mnt/etc/hostname

notify "RECREATING THE INITRAMFS IMAGE..."
## WIP add "encrypt" to hooks (between "block" and "filesystems") 
arch-chroot /mnt nano /etc/mkinitcpio.conf
arch-chroot /mnt mkinitcpio -P

notify "SET ROOT PASSWORD..."
arch-chroot /mnt passwd

notify "INSTALL BOOTLOADER..."
## WIP: this is systemd-boot...change to grub for snapshots?
#arch-chroot /mnt bootctl install

notify "ENABLE SERVICES..."
## WIP.....

notify "REBOOT..."
confirm_y "Ready to reboot. Proceed?"
umount -R /mnt
cryptsetup close $crypt
reboot
