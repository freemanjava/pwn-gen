#!/bin/bash -e

echo "Installing Nexmon firmware for WiFi monitor mode..."

# Get current kernel version
KERNEL_VERSION=$(uname -r)
echo "Current kernel version: $KERNEL_VERSION"

# Clone Nexmon repository if it doesn't exist
if [ ! -d "/usr/local/src/nexmon" ]; then
    echo "Cloning Nexmon repository..."
    git clone https://github.com/seemoo-lab/nexmon.git /usr/local/src/nexmon
fi

cd /usr/local/src/nexmon

# Build firmware patches
echo "Building Nexmon firmware patches..."

# Check if we have patches for this kernel version
KERNEL_MAJOR=$(echo $KERNEL_VERSION | cut -d'.' -f1)
KERNEL_MINOR=$(echo $KERNEL_VERSION | cut -d'.' -f2)
KERNEL_SHORT="${KERNEL_MAJOR}.${KERNEL_MINOR}"

# Try to find compatible patches
PATCH_DIR=""
for dir in patches/bcm43430a1/7_45_41_46/nexmon patches/bcm43455c0/7_45_154/nexmon; do
    if [ -d "$dir" ]; then
        PATCH_DIR="$dir"
        break
    fi
done

if [ -z "$PATCH_DIR" ]; then
    echo "Warning: No compatible Nexmon patches found for this hardware"
    echo "Skipping Nexmon installation - WiFi will work in normal mode"
    exit 0
fi

# Setup environment
source setup_env.sh

# Build the patches
cd "$PATCH_DIR"
if make; then
    echo "Nexmon patches built successfully"

    # Install firmware
    if [ -f "brcmfmac43430-sdio.bin" ]; then
        cp brcmfmac43430-sdio.bin /lib/firmware/brcm/
        echo "Installed brcmfmac43430-sdio.bin firmware"
    fi

    if [ -f "brcmfmac43436-sdio.bin" ]; then
        cp brcmfmac43436-sdio.bin /lib/firmware/brcm/
        echo "Installed brcmfmac43436-sdio.bin firmware"
    fi

    # Check for kernel driver
    DRIVER_PATH="/usr/local/src/nexmon/patches/driver/brcmfmac_${KERNEL_SHORT}.y-nexmon/brcmfmac.ko"
    if [ -f "$DRIVER_PATH" ]; then
        echo "Installing Nexmon kernel driver..."
        MODULES_DIR="/lib/modules/$KERNEL_VERSION/kernel/drivers/net/wireless/broadcom/brcm80211/brcmfmac"
        mkdir -p "$MODULES_DIR"
        cp "$DRIVER_PATH" "$MODULES_DIR/brcmfmac.ko.NEXMON"
        echo "Nexmon kernel driver installed successfully"
    else
        echo "Warning: Nexmon kernel driver not available for kernel $KERNEL_VERSION"
        echo "WiFi monitor mode may not be fully functional"
    fi

else
    echo "Warning: Nexmon patch build failed"
    echo "Continuing without Nexmon - WiFi will work in normal mode"
fi

echo "Nexmon installation completed (with warnings if applicable)"
