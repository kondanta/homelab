#!/bin/bash

# My current network is not smart enough for me to setup PXE booting. So I'm going to use a USB stick to boot the Talos installer.

# Check if the ISO file already exists
if [ -f "talos.iso" ]; then
    echo "ISO file already exists. Skipping download."
else
    echo "ISO file not found. Downloading..."
    curl -L https://factory.talos.dev/image/636aa4f93757babc9f57e2611552df92506ad9701629d1fee5b2c52de791abd2/v1.10.2/metal-amd64.iso -o talos.iso

fi

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
            - siderolabs/btrfs
            - siderolabs/i915
            - siderolabs/intel-ice-firmware
            - siderolabs/intel-ucode
            - siderolabs/mei
            - siderolabs/nut-client
            - siderolabs/tailscale
            - siderolabs/util-linux-tools
EOF

echo -n "SCHEMATIC_ID=\"636aa4f93757babc9f57e2611552df92506ad9701629d1fee5b2c52de791abd2\"" > ./data/usb-stick-boot.env

# Check if the USB stick is mounted
if [[ -L /dev/disk/by-id/usb-Innostor_Innostor_000000000000001222-0\:0 ]]; then
    sudo dd bs=4M if=talos.iso of=/dev/disk/by-id/usb-Innostor_Innostor_000000000000001222-0\:0 conv=fsync oflag=direct status=progress
else
    echo "USB stick not found"
fi
