#! /usr/bin/env bash
# Should this use "set -e"?

echo "Updating apt and doing a full upgrade.  This gets the latest version of raspi-config."
apt-get update && apt-get full-upgrade -y

if grep -Eq "do_boot_rom\s*\(" /usr/bin/raspi-config; then
    echo "The file, '/etc/default/rpi-eeprom-update', controls which branch of firmware is used."
    echo "If this is a fresh install, it likely has 'critical'.  If not 'stable', it needs to be changed."
    echo "Also updates the version, if possible."
    raspi-config nonint do_boot_rom E1 0
else
    echo "!!! raspi-config missing do_boot_rom function.  It should've been updated by the full-upgrade."
fi
if grep -Eq "do_boot_order\s*\(" /usr/bin/raspi-config; then
    echo "The boot order needs to include USB devices.  The 'B1' option will set the boot order to USB, SD, then retry."
    raspi-config nonint do_boot_order B1
else
    echo "!!! raspi-config missing do_boot_order function.  It should've been updated by the full-upgrade."
fi
