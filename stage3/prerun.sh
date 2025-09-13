#!/bin/bash -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/../pi-gen-64bit/scripts/common"

if [ ! -d "${ROOTFS_DIR}" ]; then
	copy_previous
fi
