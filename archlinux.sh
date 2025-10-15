#!/bin/bash

## HELPERS ##
function fail() { echo -e "\e[0;31m$1\e[0m"; exit 1; }
function notify() { echo -e "\n\e[1;33m$1\e[0m"; sleep 1; }
function confirm_y() { read -p "$1 [Y/n]: " ans && [[ $ans == [nN] ]] && exit 1; }
function confirm_n() { read -p "$1 [y/N]: " ans && [[ $ans == [yY] ]] || exit 1; }

notify "HOSTNAME..."
read -p "Enter the new hostname: " host
if [[ ! $host ]]; then
  fail "ERROR: Hostname invalid."
fi

notify "TARGET DISK..."
lsblk
read -p "Enter the target disk: " disk
disk="/dev/$disk"
if [[ $disk == "/dev/" || ! -e $disk ]]; then
  fail "ERROR: Target disk not found."
fi

notify "PRE-FLIGHT CHECKS..."
if ! cat /sys/firmware/efi/fw_platform_size | grep "64" &> /dev/null; then
  fail "ERROR: Not a UEFI system."
elif ! ping -c 1 ping.archlinux.org &> /dev/null; then
  fail "ERROR: No network connectivity."
elif ! timedatectl show | grep "NTPSynchronized=yes" &> /dev/null; then
  fail "ERROR: Clock requires synchronization." 
fi

notify "WIPING DISK..."
confirm_n "Filesystem signatures on $disk will be wiped. Proceed?"
wipefs -a $disk

notify "PARTITIONING..."
sgdisk $disk --new 1:0:1G    --typecode 1:ef00 --change-name 1:efi \
             --largest-new 2 --typecode 2:8309 --change-name 2:luks_system
efi="/dev/disk/by-partlabel/efi"
luks="/dev/disk/by-partlabel/luks_system"

notify "ENCRYPTION..."
cryptsetup luksFormat --pbkdf=pbkdf2 $luks
cryptsetup open $luks system
btrfs="/dev/mapper/system"

notify "FORMATTING..."
mkfs.fat -F 32 $efi
mkfs.btrfs $btrfs

notify "CREATING SUBVOLUMES..."
mount $btrfs /mnt
btrfs subvolume create /mnt/{@,@home,@snapshots,@swap,@var_cache,@var_log,@var_tmp}
umount /mnt

notify "MOUNTING PARTITIONS / SUBVOLUMES..."
# mount root subvolume
mount -o noatime,compress=zstd:1,subvol=@ $btrfs /mnt
# create mount points
mkdir -p /mnt/{efi,home,.snapshots,swap,var/cache,var/log,var/tmp}
# mount partitions / subvolumes
mount $efi /mnt/efi
mount -o noatime,compress=zstd:1,subvol=@home $btrfs /mnt/home
mount -o noatime,compress=zstd:1,subvol=@snapshots $btrfs /mnt/.snapshots
mount -o noatime,compress=zstd:1,subvol=@swap $btrfs /mnt/swap
mount -o noatime,compress=zstd:1,subvol=@var_cache $btrfs /mnt/var/cache
mount -o noatime,compress=zstd:1,subvol=@var_log $btrfs /mnt/var/log
mount -o noatime,compress=zstd:1,subvol=@var_tmp $btrfs /mnt/var/tmp

notify "CREATING SWAP FILE..."
btrfs filesystem mkswapfile --size 16g --uuid clear /mnt/swap/swapfile
swapon /mnt/swap/swapfile

notify "GENERATING MIRRORLIST..."
reflector --country CA \
          --delay 1 \
          --fastest 10 \
          --sort rate \
          --save /etc/pacman.d/mirrorlist \
          --verbose

## WIP: update packages first?
notify "INSTALLING ESSENTIAL PACKAGES..."
pacstrap -K /mnt base linux linux-firmware \
                 amd-ucode intel-ucode \
                 btrfs-progs dosfstools \
                 networkmanager iwd openssh \
                 grub efibootmgr

notify "GENERATING FSTAB..."
genfstab -U /mnt > /mnt/etc/fstab

notify "SETTING TIME ZONE..."
arch-chroot /mnt ln -sf /usr/share/zoneinfo/America/Toronto /etc/localtime
arch-chroot /mnt hwclock --systohc

notify "SETTING LOCALE..."
echo "en_US.UTF-8 UTF-8" > /mnt/etc/locale.gen
arch-chroot /mnt locale-gen
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf

notify "SETTING HOSTNAME..."
echo $host > /mnt/etc/hostname

notify "CONFIGURE & REBUILD INITRAMFS..."
sed -i "s/block filesystems/block encrypt filesystems/" /mnt/etc/mkinitcpio.conf
arch-chroot /mnt mkinitcpio -P

notify "INSTALL BOOTLOADER..."
sed -i "/GRUB_CMDLINE_LINUX=/c\GRUB_CMDLINE_LINUX=\"cryptdevice=${luks}:luks_system\"" /mnt/etc/default/grub
sed -i "/GRUB_ENABLE_CRYPTODISK=/c\GRUB_ENABLE_CRYPTODISK=y" /mnt/etc/default/grub
arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

notify "CONFIGURE USERS..."
arch-chroot /mnt passwd
# WIP create regular users

notify "CONFIGURE NETWORKING..."
cat > /mnt/etc/NetworkManager/conf.d/wifi_backend.conf << EOF
[device]
wifi.backend=iwd
EOF

notify "ENABLE SERVICES..."
arch-chroot /mnt systemctl enable NetworkManager
arch-chroot /mnt systemctl enable sshd
## WIP.....

notify "REBOOT..."
confirm_y "Ready to reboot. Proceed?"
swapoff -a
umount -R /mnt
cryptsetup close system
reboot
