#! /usr/bin/env bash

echo "======= starting firmware update"
if [ ! -d "~/firmware" ]; then
  mkdir ~/firmware
fi
pushd ~/firmware
echo "Copying firmware bin..."
MOST_RECENT_FIRMWARE=`ls -1t /lib/firmware/raspberrypi/bootloader/stable/pieeprom-2020-0* | head -n1`
echo "Most recent firmware found: $MOST_RECENT_FIRMWARE"
cp "$MOST_RECENT_FIRMWARE" pieeprom.bin

echo "Extracting config file from firmware bin..."
rpi-eeprom-config pieeprom.bin > bootconf.txt

echo "Changing boot order in config file..."
sed -i -e 's/^BOOT_ORDER=.*/BOOT_ORDER=0xf124/' bootconf.txt
sed -i -e 's/^ENABLE_SELF_UPDATE=.*/ENABLE_SELF_UPDATE=0/' bootconf.txt

echo "Building new firmware bin..."
rpi-eeprom-config --out pieeprom-new.bin --config bootconf.txt input-eeprom.bin

read -p "Press any key to apply new firmware" -n1 -s
echo "Applying the new firmware..."
sudo rpi-eeprom-update -f pieeprom-new.bin
popd
echo "======= done firmware update"

