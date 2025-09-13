#!/bin/bash -e

echo -e "\e[32m### Creating Pwnagotchi folders ###\e[0m"
install -v -d "${ROOTFS_DIR}/etc/pwnagotchi"
install -v -d "${ROOTFS_DIR}/etc/pwnagotchi/log"
install -v -d "${ROOTFS_DIR}/etc/pwnagotchi/conf.d/"
install -v -d "${ROOTFS_DIR}/usr/local/share/pwnagotchi"
install -v -d "${ROOTFS_DIR}/usr/local/share/pwnagotchi/custom-plugins/"

# Copy pwnagotchi source code from the local workspace to the image
# This avoids the GitHub authentication issue

echo "Copying pwnagotchi source code from local workspace..."

# Create the pwnagotchi directory in the target system
install -d "${ROOTFS_DIR}/home/pi/pwnagotchi"

# Based on the actual workspace structure:
# Build script is at: pwn-gen/stage3/05-install-pwnagotchi/00-run.sh
# Pwnagotchi source is at: pwnagotchi/ (at the workspace root)
# From pwn-gen/stage3/05-install-pwnagotchi/ to the root: ../../../
# Then to pwnagotchi/: ../../../pwnagotchi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Try multiple possible locations for the pwnagotchi source
POSSIBLE_PATHS=(
    "${SCRIPT_DIR}/../../../pwnagotchi"                                                    # Standard relative path
    "/mnt/c/Users/dmitry.bidenko/IdeaProjects/My/pwnagotchi_touch/pwnagotchi"            # Absolute WSL path
    "${SCRIPT_DIR}/../../../../pwnagotchi"                                                # Alternative relative path
)

echo "Current script directory: ${SCRIPT_DIR}"

PWNAGOTCHI_SOURCE=""
for path in "${POSSIBLE_PATHS[@]}"; do
    echo "Checking path: ${path}"
    if [ -d "${path}" ]; then
        # Verify it's actually a pwnagotchi directory by checking for key files
        if [ -f "${path}/setup.py" ] || [ -f "${path}/pyproject.toml" ] || [ -f "${path}/__init__.py" ]; then
            echo "Found valid pwnagotchi source at: ${path}"
            PWNAGOTCHI_SOURCE="${path}"
            break
        else
            echo "Directory exists but doesn't appear to be pwnagotchi source (missing setup.py, pyproject.toml, or __init__.py)"
        fi
    else
        echo "Path does not exist: ${path}"
    fi
done

if [ -n "${PWNAGOTCHI_SOURCE}" ]; then
    echo "Using pwnagotchi source at: ${PWNAGOTCHI_SOURCE}"

    # List contents to verify it's the right directory
    echo "Pwnagotchi source contents:"
    ls -la "${PWNAGOTCHI_SOURCE}/" | head -10

    # Copy all pwnagotchi source files
    echo "Copying pwnagotchi files..."
    cp -r "${PWNAGOTCHI_SOURCE}"/* "${ROOTFS_DIR}/home/pi/pwnagotchi/"

    # Set proper ownership (will be adjusted in chroot script)
    chown -R 1000:1000 "${ROOTFS_DIR}/home/pi/pwnagotchi"

    echo "Successfully copied pwnagotchi source code"
    echo "Files copied to target:"
    ls -la "${ROOTFS_DIR}/home/pi/pwnagotchi/" | head -10

    # Verify key files were copied
    if [ -f "${ROOTFS_DIR}/home/pi/pwnagotchi/setup.py" ] || [ -f "${ROOTFS_DIR}/home/pi/pwnagotchi/pyproject.toml" ]; then
        echo "Verification successful: Key pwnagotchi files found in target directory"
    else
        echo "Warning: Key pwnagotchi files not found in target directory"
        echo "Target directory contents:"
        ls -la "${ROOTFS_DIR}/home/pi/pwnagotchi/"
    fi
else
    echo "Error: Could not find pwnagotchi source code in any expected location"
    echo "Current working directory: $(pwd)"
    echo "Script directory: ${SCRIPT_DIR}"

    # Debug information
    echo "Workspace structure around script directory:"
    find "${SCRIPT_DIR}/../../../" -maxdepth 2 -type d 2>/dev/null | head -20

    echo "Looking for any pwnagotchi directories:"
    find / -maxdepth 4 -name "pwnagotchi" -type d 2>/dev/null | head -10

    exit 1
fi
