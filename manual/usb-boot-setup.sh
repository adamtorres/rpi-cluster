#! /usr/bin/env bash

# Sets up the SSD to boot a raspberry pi.
echo "======== starting setting up usb boot partitions"
PARTUUIDA=$(sudo blkid -p /dev/sda1 | grep -o "PART_ENTRY_UUID=[^ ]*" | sed -e 's/PART_ENTRY_UUID="//' -e 's/"//')
PARTUUIDB=$(sudo blkid -p /dev/sda2 | grep -o "PART_ENTRY_UUID=[^ ]*" | sed -e 's/PART_ENTRY_UUID="//' -e 's/"//')
echo "PARTUUID for boot partition is $PARTUUIDA"
echo "PARTUUID for root partition is $PARTUUIDB"
if [ ! -d "/mnt/ssd1" ]; then
  sudo mkdir /mnt/ssd1
fi
if [ ! -d "/mnt/ssd2" ]; then
  sudo mkdir /mnt/ssd2
fi
sudo mount /dev/sda1 /mnt/ssd1
sudo mount /dev/sda2 /mnt/ssd2

sudo sed -i.bak -e "s|PARTUUID=[^\s]*\s/boot|PARTUUID=$PARTUUIDA /boot|" -e "s|PARTUUID=[^\s]*\s/ |PARTUUID=$PARTUUIDB / |" /mnt/ssd2/etc/fstab
echo "-------- new fstab should have boot=$PARTUUIDA and root=$PARTUUIDB"
cat /mnt/ssd2/etc/fstab

sudo sed -i.bak -e "s/PARTUUID=[^ ]*/PARTUUID=$PARTUUIDB/" /mnt/ssd1/cmdline.txt
echo "-------- new cmdline.txt should have root=$PARTUUIDB"
cat /mnt/ssd1/cmdline.txt

echo "-------- unmounting partitions and resizing root"
sudo umount /dev/sda1
sudo umount /dev/sda2
sudo e2fsck -f /dev/sda2
sudo resize2fs /dev/sda2

echo "======== done setting up usb boot partitions"
