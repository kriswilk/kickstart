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

# EFI, Linux swap, Linux filesystem
sgdisk $1 \
       -Z \
       -n 1:0:1G  -t 1:ef00 \
       -n 2:0:32G -t 2:8200 \
       -N 3       -t 3:8300

## ENCRYPTION ##
## FORMATTING ##

# WIP...
