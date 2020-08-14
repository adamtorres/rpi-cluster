#! /usr/bin/env bash

echo "Adding a proxy for apt."
cat << EOF | sudo tee -a /etc/apt/apt.conf.d/01proxy
Acquire::http::Proxy "http://192.168.1.33:3142/";
Acquire::https::Proxy "http://192.168.1.33:3142/";
EOF

echo "Disable serial console.  This removes 'console=serial0,115200' from '/boot/cmdline.txt'."
raspi-config nonint do_serial 1
echo "Change video memory to 16MB.  Don't need much as this is a headless setup."
raspi-config nonint do_memory_split 16
echo "Explicitly set plain HDMI mode.  This will use HDMI if it is available on boot and switch to tvout otherwise."
raspi-config nonint do_pi4video V3
echo "Boot to text console and require login.  Other options are to automatically log in and use a graphical interface."
raspi-config nonint do_boot_behaviour B1
echo "Disable the camera interface.  Enabling it will force gpu memory to at least 128MB."
raspi-config nonint do_camera 1
echo "Setting localization options.  Keyboard layout."
sed -i /etc/default/keyboard -e "s/^XKBMODEL.*/XKBMODEL=\"pc104\"/"
raspi-config nonint do_configure_keyboard us
echo "Setting localization options.  en_US.UTF-8."
raspi-config nonint do_change_locale en_US.UTF-8
echo "Setting localization options.  timezone."
raspi-config nonint do_change_timezone US/Mountain
echo "Setting localization options.  wifi Country."
raspi-config nonint do_wifi_country US
echo "Setting network options.  enabling ssh"
raspi-config nonint do_ssh 0
echo "Setting network options.  disabling vnc"
raspi-config nonint do_vnc 1
echo "Setting network options.  waiting for network on boot"
raspi-config nonint do_boot_wait 0
echo "Setting network options.  predictable device names."
raspi-config nonint do_net_names 0
echo "Might turn these on later if we want to do things like temperature monitoring or such."
echo "disable SPI"
raspi-config nonint do_spi 1
echo "disable I2C"
raspi-config nonint do_i2c 1
echo "disable OneWire"
raspi-config nonint do_onewire 1
echo "disable remote GPIO pins"
raspi-config nonint do_rgpio 1
echo "disable bluetooth as we do not need it at the moment."
grep -qxe '.*dtoverlay=disable-bt' /boot/config.txt || echo 'dtoverlay=disable-bt' >> /boot/config.txt
sed /boot/config.txt -i -e "s/^#.*dtoverlay=disable-bt/dtoverlay=disable-bt/"
echo "Setting network options.  hostname"
raspi-config nonint do_hostname pi-sd-card

# Create or append to the alias file.
cat << EOF >> ~/.bash_aliases
alias ll="ls -laph"
alias mounted="mount | grep -Ee '/dev/(sd|mm)\w*'"
EOF

echo "Creating folders for mounting the ssd partitions."
mkdir /mnt/{ssd_boot,ssd_root}
