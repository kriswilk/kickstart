#!/bin/bash

## HELPERS ##
function fail() { echo -e "\e[0;31m$1\e[0m"; exit 1; }
function notify() { echo -e "\n\e[1;33m$1\e[0m"; sleep 1; }
function confirm_y() { read -p "$1 [Y/n]: " ans && [[ $ans == [nN] ]] && exit 1; }
function confirm_n() { read -p "$1 [y/N]: " ans && [[ $ans == [yY] ]] || exit 1; }

notify "HOSTNAME..."
read -p "Enter the new hostname: " hostname
if [[ ! $hostname ]]; then
  fail "ERROR: Hostname invalid."
fi

notify "TARGET DISK..."
lsblk
read -p "Enter the target disk: " disk
disk="/dev/${disk}"
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

notify "CONFIRMATION..."
confirm_n "Disk $disk will be completely erased. Proceed?"

notify "PARTITIONING..."
sgdisk $disk -Z -n 1:0:1G -t 1:ef00 -N 2 -t 2:8309
if [[ -e "${disk}1" && -e "${disk}2" ]]; then
  efi="${disk}1"
  luks="${disk}2"
elif [[ -e "${disk}p1" && -e "${disk}p2" ]]; then
  efi="${disk}p1"
  luks="${disk}p2"
else
  fail "ERROR: Disk partition(s) missing."
fi

notify "ENCRYPTION..."
cryptsetup luksFormat $luks
cryptsetup open --type luks $luks archlinux
btrfs="/dev/mapper/archlinux"

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
reflector --country CA --delay 1 --fastest 10 --sort rate --save /etc/pacman.d/mirrorlist --verbose

## WIP: update packages first?
notify "INSTALLING PACKAGES..."
packages=(
  # CORE PACKAGES, DRIVERS
  # minimal
  base
  base-devel
  linux
  linux-firmware
  linux-headers
  # microcode
  amd-ucode
  intel-ucode
  # bootloader
  grub
  grub-btrfs
  efibootmgr
  os-prober
  # filesystem tools
  btrfs-progs
  dosfstools
  exfatprogs
  e2fsprogs
  ntfs-3g
  udftools
  ##### mtools gparted gptfdisk ???????????????????????
  # network
  networkmanager
  iwd
  ufw
  tailscale
  wireshark-cli
  wireshark-gui
  qbittorrent
  
  # sound
  sof-firmware # ??????
  alsa-firmware # ??????
  pipewire # ??????
  pipewire-alsa # ??????
  pipewire-pulse # ??????
  pipewire-jack # ??????
  wireplumber # ??????
  easyeffects # ??????
  alsa-utils # ??????

  
  # basic tools
  git rsync rclone htop reflector tmux fastfetch
  
  # fonts
  ttf-hack-nerd
  
  # 
  firefox # browser
  nano vim # editor
  rust uv # programming
  docker # virtualization
  
  # MULTIMEDIA
  # audio
  audacity
  # photo / illustration
  gimp
  inkscape
  krita
  darktable
  flameshot
  # video
  vlc
  mkvtoolnix-cli
  mkvtoolnix-gui
  # 3d / cad
  blender
  freecad
  kicad
  prusa-slicer
  # office
  libreoffice
  
  # ENTERTAINMENT
  # gaming
  steam
  prismlauncher
  jre8-openjdk
  jre17-openjdk
  jre21-openjdk

  # shell
  # gui
  # terminal
  
# AUR LIST
stremio
naps2
bcompare
bcompare-kde6 ?????????
visual-studio-code-bin
imhex
hexcurse
ipscan
rustdesk
pandoc-bin

# openssh man 
# bash-completion
    # fonts
    # onedrive, gdrive
    # fineprint
    # renamer
    # flatpak?
    # segger j-link
    # jdownloader2
    # rufus

    
    nvidia nvidia-settings
    deluge meld speedcrunch okteta
    wine winetricks wine-mono wine-gecko
    
    gvim mousepad # For when neovim doesn't like me.
    python tk python-pyperclip
    wl-clipboard
    
    gvfs

    # Install KDE.
    plasma
    xorg
    kdialog
    konsole # Terminal.
    kate # Text editor i never use. NOTE: This also installs kwrite.
    dolphin dolphin-plugins kio-admin
    ark p7zip unrar # Archive management tools.
    kcharselect # Character selector.
    kcalc # Calculator.
    gwenview # Image viewer.
    kcolorchooser # Color picker.
    filelight # Disk space usage.
    spectacle # Screenshot capture.
    okular # PDF and comic viewer.
    gparted # Gnomes "GParted" is better (included with manjaro kde btw) than "KDE Partition Manager": partitionmanager
    gnome-disk-utility # Gnomes other partition manager, that has a handy "Restore Disk Image..." feature that i use to burn iso's to usb instead of using $ dd command.
    ksystemlog # System log viewer.
    gsmartcontrol # Harddisk health inspector.
    plasma-systemmonitor # Task Manager.
    plasma-desktop plasma-nm

    kwallet kwalletmanager # Needed by KDE to encrypt credentials so they aren't plain text.
    kwallet-pam # Allows for auto-unlock once configured.
    libsecret # Allows GTK applications (like Chrome) to interface with KDE Wallet.

    # gnome-keyring # Only needed if you use GNOME apps that rely on the GNOME keyring.
    # seahorse # GUI for GNOME keyring.

    # kaccounts-integration # For online account management (Google, Nextcloud, OwnCloud, etc.) in KDE.

    egl-wayland plasma-wayland-protocols # Wayland.

    sddm # Display manager.
)
pacstrap -K /mnt "${packages[@]}"
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
sed -i "s/block filesystems/block encrypt filesystems/" /mnt/etc/mkinitcpio.conf
arch-chroot /mnt mkinitcpio -P

notify "CONFIGURE USERS..."
arch-chroot /mnt passwd
# WIP create other users

notify "INSTALL BOOTLOADER..."
## WIP: this is systemd-boot...change to grub for snapshots?
#arch-chroot /mnt bootctl install

notify "ENABLE SERVICES..."
## WIP.....

notify "REBOOT..."
confirm_y "Ready to reboot. Proceed?"
umount -R /mnt
cryptsetup close $luks
reboot
