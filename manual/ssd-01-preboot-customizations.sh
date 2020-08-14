#! /usr/bin/env bash

echo "Remove the boot command line option that resizes the root partition."
sed -i.bak -e "s|init=/usr/lib/raspi-config/init_resize.sh||" /mnt/ssd_boot/cmdline.txt

echo "Add usb quirk option to cmdline.txt if it isn't there already."
sed -i /mnt/ssd_boot/cmdline.txt -e "s/usb-storage.quirks=174c:55aa:u //"
sed -i /mnt/ssd_boot/cmdline.txt -e "s/root=/usb-storage.quirks=174c:55aa:u root=/"

echo "Copy the current wpa_supplicant.conf to the new boot folder."
cp /etc/wpa_supplicant/wpa_supplicant.conf /mnt/ssd_boot/wpa_supplicant.conf

echo "Copy elf and dat files to the ssd's boot partition."
cp /home/pi/boot_files/stable/* /mnt/ssd_boot/

echo "Remove the startup script that resizes the filesystem within the larger partition."
rm /mnt/ssd_root/etc/rc3.d/S01resize2fs_once
rm /mnt/ssd_root/etc/init.d/resize2fs_once

# Is this needed if we are going to use a similar provision script as on the SD card?
echo "Create the ssh file to tell pi ssh should be enabled."
touch /mnt/ssd_boot/ssh
