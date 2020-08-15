#!/bin/sh

check_commands () {
  if ! command -v whiptail > /dev/null; then
      echo "whiptail not found"
      sleep 5
      return 1
  fi
  for COMMAND in grep cut sed parted fdisk findmnt; do
    if ! command -v $COMMAND > /dev/null; then
      FAIL_REASON="$COMMAND not found"
      return 1
    fi
  done
  return 0
}

get_variables () {
  # /dev/sda2
  ROOT_PART_DEV=$(findmnt /mnt/ssd_root -o source -n)
  # sda2
  ROOT_PART_NAME=$(echo "$ROOT_PART_DEV" | cut -d "/" -f 3)
  # sda
  ROOT_DEV_NAME=$(echo /sys/block/*/"${ROOT_PART_NAME}" | cut -d "/" -f 4)
  # /dev/sda
  ROOT_DEV="/dev/${ROOT_DEV_NAME}"
  # 2
  ROOT_PART_NUM=$(cat "/sys/block/${ROOT_DEV_NAME}/${ROOT_PART_NAME}/partition")
  
  # /dev/sda1
  BOOT_PART_DEV=$(findmnt /mnt/ssd_boot -o source -n)
  # sda1
  BOOT_PART_NAME=$(echo "$BOOT_PART_DEV" | cut -d "/" -f 3)
  # sda
  BOOT_DEV_NAME=$(echo /sys/block/*/"${BOOT_PART_NAME}" | cut -d "/" -f 4)
  # 1
  BOOT_PART_NUM=$(cat "/sys/block/${BOOT_DEV_NAME}/${BOOT_PART_NAME}/partition")
  
  # 2fed7fee
  OLD_DISKID=$(fdisk -l "$ROOT_DEV" | sed -n 's/Disk identifier: 0x\([^ ]*\)/\1/p')
  
  SWAP_PART_SIZE_GB=8
  # 16777216
  SWAP_PART_SIZE_SECT=$((SWAP_PART_SIZE_GB * 1024 * 1024 * 1024 / 512))
  # 3
  SWAP_PART_NUM=$((ROOT_PART_NUM + 1))
  # /dev/sda3
  SWAP_PART_DEV="${ROOT_DEV}${SWAP_PART_NUM}"
  
  # 976773168
  ROOT_DEV_SIZE=$(cat "/sys/block/${ROOT_DEV_NAME}/size")
  # 959995951
  TARGET_END=$((ROOT_DEV_SIZE - SWAP_PART_SIZE_SECT - 1))
  
  # BYT;
  # /dev/da:976773168:ci:512:512:mdo:Samung SSD 860 EVO 500G:;
  # 1:8192:532479:524288:fat32::lba;
  # 2:532480:3620863:3088384:ext4::;
  PARTITION_TABLE=$(parted -m "$ROOT_DEV" unit s print | tr -d 's')
  
  # 2
  LAST_PART_NUM=$(echo "$PARTITION_TABLE" | tail -n 1 | cut -d ":" -f 1)
  
  # 2:532480:3620863:3088384:ext4::;
  ROOT_PART_LINE=$(echo "$PARTITION_TABLE" | grep -e "^${ROOT_PART_NUM}:")
  # 532480
  ROOT_PART_START=$(echo "$ROOT_PART_LINE" | cut -d ":" -f 2)
  # 3620863
  ROOT_PART_END=$(echo "$ROOT_PART_LINE" | cut -d ":" -f 3)
  echo "ROOT_PART_DEV = <$ROOT_PART_DEV>"
  echo "ROOT_PART_NAME = <$ROOT_PART_NAME>"
  echo "ROOT_DEV_NAME = <$ROOT_DEV_NAME>"
  echo "ROOT_DEV = <$ROOT_DEV>"
  echo "ROOT_PART_NUM = <$ROOT_PART_NUM>"
  echo "BOOT_PART_DEV = <$BOOT_PART_DEV>"
  echo "BOOT_PART_NAME = <$BOOT_PART_NAME>"
  echo "BOOT_DEV_NAME = <$BOOT_DEV_NAME>"
  echo "BOOT_PART_NUM = <$BOOT_PART_NUM>"
  echo "OLD_DISKID = <$OLD_DISKID>"
  echo "SWAP_PART_SIZE_GB = <$SWAP_PART_SIZE_GB>"
  echo "SWAP_PART_SIZE_SECT = <$SWAP_PART_SIZE_SECT>"
  echo "SWAP_PART_NUM = <$SWAP_PART_NUM>"
  echo "SWAP_PART_DEV = <$SWAP_PART_DEV>"
  echo "ROOT_DEV_SIZE = <$ROOT_DEV_SIZE>"
  echo "TARGET_END = <$TARGET_END>"
  echo "PARTITION_TABLE = <$PARTITION_TABLE>"
  echo "LAST_PART_NUM = <$LAST_PART_NUM>"
  echo "ROOT_PART_LINE = <$ROOT_PART_LINE>"
  echo "ROOT_PART_START = <$ROOT_PART_START>"
  echo "ROOT_PART_END = <$ROOT_PART_END>"
}

is_ssd_mounted() {
  findmnt /mnt/ssd_boot -n > /dev/null
  if [ "$?" -eq 1 ]; then
    return 1
  fi
  findmnt /mnt/ssd_root -n > /dev/null
  if [ "$?" -eq 1 ]; then
    return 1
  fi
  return 0
}

mount_parts() {
  mount $BOOT_PART_DEV /mnt/ssd_boot
  mount $ROOT_PART_DEV /mnt/ssd_root
}

unmount_parts() {
  umount $BOOT_PART_DEV
  umount $ROOT_PART_DEV
}

add_swap_part() {
  # The blank lines are important as they are accepting the defaults for the start and end sectors.
  fdisk "$ROOT_DEV" > /dev/null <<EOF
n
p
$SWAP_PART_NUM


t
$SWAP_PART_NUM
82
w
EOF
  if [ "$?" -eq 0 ]; then
    unmount_parts
    sync
    mount_parts
    # no label, UUID=0e21acb7-ba1d-438a-a201-615155e11c96
    MKSWAP_UUID_LINE=$(mkswap "$SWAP_PART_DEV" | grep "UUID")
    # 0e21acb7-ba1d-438a-a201-615155e11c96
    SWAP_UUID=$(echo "$MKSWAP_UUID_LINE" | cut -d "=" -f 2)
    FSTAB_LINE="UUID=$SWAP_UUID none            swap    sw              0       0"
    echo "Adding the swap line to fstab."
    echo "$FSTAB_LINE"
    echo "$FSTAB_LINE" >> /mnt/ssd_root/etc/fstab
  fi
}

fix_partuuid() {
  DISKID="$(tr -dc 'a-f0-9' < /dev/hwrng | dd bs=1 count=8 2>/dev/null)"
  fdisk "$ROOT_DEV" > /dev/null <<EOF
x
i
0x$DISKID
r
w
EOF
  if [ "$?" -eq 0 ]; then
    sync
    mount_parts
    echo "Fixing fstab and cmdline.txt to used new diskid '$DISKID' instead of '$OLD_DISKID'."
    sed -i "s/${OLD_DISKID}/${DISKID}/g" /mnt/ssd_root/etc/fstab
    sed -i "s/${OLD_DISKID}/${DISKID}/" /mnt/ssd_boot/cmdline.txt
  fi
}

check_variables () {
  if [ "$BOOT_DEV_NAME" != "$ROOT_DEV_NAME" ]; then
      FAIL_REASON="Boot and root partitions are on different devices"
      return 1
  fi
  
  if [ "$ROOT_PART_NUM" -ne "$LAST_PART_NUM" ]; then
    FAIL_REASON="Root partition should be last partition"
    return 1
  fi
  
  if [ "$ROOT_PART_END" -gt "$TARGET_END" ]; then
    FAIL_REASON="Root partition runs past the end of device"
    return 1
  fi
  
  if [ ! -b "$ROOT_DEV" ] || [ ! -b "$ROOT_PART_DEV" ] || [ ! -b "$BOOT_PART_DEV" ] ; then
    FAIL_REASON="Could not determine partitions"
    return 1
  fi
}

check_kernel () {
  MAJOR="$(uname -r | cut -f1 -d.)"
  MINOR="$(uname -r | cut -f2 -d.)"
  if [ "$MAJOR" -eq "4" ] && [ "$MINOR" -lt "9" ]; then
    return 0
  fi
  if [ "$MAJOR" -lt "4" ]; then
    return 0
  fi
  NEW_KERNEL=1
}

main () {
  get_variables
  
  if ! check_variables; then
    return 1
  fi
  
  check_kernel
  
  if [ "$ROOT_PART_END" -eq "$TARGET_END" ]; then
    # root seems to already be resized.
    return 0
  fi
  
  unmount_parts
  
  if ! parted -m "$ROOT_DEV" u s resizepart "$ROOT_PART_NUM" "$TARGET_END"; then
    FAIL_REASON="Root partition resize failed"
    return 1
  fi
  # parted wasn't resizing the filesystem.  Odd.  Thought it was.
  e2fsck -y -f "$ROOT_PART_DEV"
  resize2fs "$ROOT_PART_DEV"
  
  fix_partuuid
  
  add_swap_part
  
  return 0
}

if ! is_ssd_mounted; then
  echo "ssd boot and root partitions need to be mounted to /mnt/ssd_boot and /mnt/ssd_root."
  echo "This script determines which device to operate on based on the partitions mounted to those locations."
  exit 1
fi

if ! check_commands; then
  exit 1
fi

if main; then
  echo "Resized root filesystem.  Probably should reboot."
  echo "Looking at the drives:"
  lsblk -f "$ROOT_DEV"
  blkid "${ROOT_DEV}"?
  echo "Looking at cmdline.txt and fstab:"
  cat /mnt/ssd_boot/cmdline.txt
  cat /mnt/ssd_root/etc/fstab
  echo "Verify the PARTUUID in the files match the drive."
else
  echo "Could not expand filesystem.\n${FAIL_REASON}"
fi
