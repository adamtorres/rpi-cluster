#! /usr/bin/env bash

set -e

help() {
  echo "Example usage:"
  echo "$0 sda some-image-file.img"
}
DEST_DEVICE=$1
IMG_FILE=$2

# Make sure the selected device is not mounted anywhere.
if mount | grep -q "/dev/$DEST_DEVICE" ; then
  echo "device is mounted.  Unmount to run this."
  help
  exit 1
fi

# Disk /dev/sda: 465.8 GiB, 500107862016 bytes, 976773168 sectors
DEST_SIZE=$(fdisk -l "/dev/$DEST_DEVICE" | grep "Disk /dev/$DEST_DEVICE" | cut -d" " -f5)
# TODO: if DEST_SIZE is nothing, assume fdisk was unable to get info from the device.

if [ ! -f "$IMG_FILE" ]; then
  echo "Image file does not exist."
  help
  exit 1
fi

echo "writing $IMG_FILE to $DEST_DEVICE..."
echo "dest size = $DEST_SIZE"
dd bs=4M if="$IMG_FILE" of="/dev/$DEST_DEVICE" status=progress conv=fsync
