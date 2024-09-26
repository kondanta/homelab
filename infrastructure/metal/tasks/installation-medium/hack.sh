#!/bin/bash

# My current network is not smart enough for me to setup PXE booting. So I'm going to use a USB stick to boot the Talos installer.

# Fetch the iso
curl -L https://factory.talos.dev/image/97d3538093bb06a33cc2647552a0f88475a592e44bfd8326cd44b656b13f8bbc/v1.7.6/metal-amd64.iso -o talos.iso

cat <<EOF > ./data/usb-stick-boot.cusomisation
customization:
    extraKernelArgs:
        - talos.platform=metal
        - init_on_alloc=1
        - init_on_free=1
        - pti=on
        - slab_nomerge
        - talos.shutdown=poweroff
    systemExtensions:
        officialExtensions:
            - siderolabs/i915-ucode
            - siderolabs/intel-ice-firmware
            - siderolabs/intel-ucode
            - siderolabs/tailscale
            - siderolabs/util-linux-tools
            - siderolabs/zfs
EOF

echo -n "SCHEMATIC_ID=\"97d3538093bb06a33cc2647552a0f88475a592e44bfd8326cd44b656b13f8bbc\"" > ./data/usb-stick-boot.env

# Check if the USB stick is mounted
if [[ -L /dev/disk/by-id/usb-Sandisk_USB_Ultra_VC0494150622135591000513-0\:0 ]]; then
    sudo dd bs=4M if=talos176.iso of=/dev/disk/by-id/usb-Sandisk_USB_Ultra_VC0494150622135591000513-0\:0 conv=fsync oflag=direct status=progress
else
    echo "USB stick not found"
fi
