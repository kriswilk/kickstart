#!/bin/bash

## PREREQUISITES ##
# Boot mode
if [[ $(cat /sys/firmware/efi/fw_platform_size) != 64 ]]; then
  echo "ERROR: UEFI test failed."
  exit 1
fi
# Network connectivity
if ! ping -c 1 1.1.1.1 >/dev/null 2>&1; then
  echo "ERROR: Network connectivity test failed."
  exit 1
fi
# System clock
# WIP...
# check output of timedatectl

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
