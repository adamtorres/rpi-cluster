TODO: Add this doc to repo and add the scripts.

# RPI-Node provisioning

Starting with a Raspberry Pi 4 from fresh install on an SD card, set it up to provision multiple SSDs and Pis so they can be part of a cluster.

# Assumptions

I'm writing this mostly for myself so these assumptions are based on my environment.

* Non-Pi system is OSX - this will be used to write the initial SD card
* SSDs are all 500GB Samsung EVO - plenty of space
* Pis are all model 4B w/ at least 4GiB RAM

## Set up the SD card to provision the SSDs

The end goal of this SD card is not to run a Pi for longer than it takes to set up the SSD.  Then move to another Pi to set up another SSD.  And another.

Write the 2020-05-27 Raspberry OS Buster Lite image to an SD card using the Raspberry Imager on OSX.  The imager app ejects the card after writing so you have to remove and reinsert it to get the boot partition to mount.

Create a 'provision' folder in the boot partition.  Since it is a FAT32 partition, no special permissions seem needed.

    adam@Adams-MacBook-Air: mkdir /Volumes/boot/provision
    adam@Adams-MacBook-Air: cd /Volumes/boot/provision

Clone the rpi-cluster repo.  This gets a pile of scripts which will be used eventually.  These are put onto the SD card because some steps will be done before ssh is available to the pi.  TODO: Get ansible to do all this mess such that placing 'ssh.txt' on SD card is all the setup needed.
Note the trailing ".".  That tells git to clone the repo in the current folder instead of creating a subfolder for the repo.

    adam@Adams-MacBook-Air: git clone https://github.com/adamtorres/rpi-cluster .

Eject the SD card.

## First Boot on SD card

Plug the SD card into the Pi, and boot it up.  Default user/pass is pi/raspberry.  Once logged in, run the first SD script.

    pi@raspberry:~ $ sudo /boot/provision/manual/sd-01-raspi-config.sh

Use raspi-config to attach to the wifi.  It will claim "sudo: unable to resolve host..."  Just ignore that.  The command still works.  Check the wpa_supplicant file if you don't believe me.  The wifi setup is in the network menu.

    pi@raspberry:~ $ sudo raspi-config

Reboot to make all changes take effect.

    pi@raspberry:~ $ sudo reboot

Once the reboot is complete and a login prompt appears, you should see a line near the prompt looking similar to:

    My IP address is 192.168.1.37

This is a really good indication that the wifi is working properly.  This means you likely won't have to log into the pi directly anymore.

The hostname at the prompt should now be "pi-sd-card".

## SSH into the pi

So we don't have to deal with transcribing commands to the pi, ssh into it so we can just copy/paste.  Try using the hostname so you don't have to worry about IP addresses.  If that doesn't work, the IP should be displayed near the login prompt as part of the statement "My IP address is ..."  Or, you can log into the pi directly and run `ip a show wlan0`.

    adam@Adams-MacBook-Air: ssh pi@pi-sd-card.local

The first time you connect, you might get the message below.  If so, all is good.

    The authenticity of host '192.168.1.35 (192.168.1.35)' can't be established.
    ECDSA key fingerprint is SHA256:DbfOyQaGobbLDEgoOkWk1IK3W6wf1zPbNPlAA.
    Are you sure you want to continue connecting (yes/no/[fingerprint])? yes

If you get an error like the following, you probably previously connected to a different system using the same ip address.  Or possibly the same pi but a different OS install.

    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    @    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    IT IS POSSIBLE THAT SOMEONE IS DOING SOMETHING NASTY!
    Someone could be eavesdropping on you right now (man-in-the-middle attack)!
    It is also possible that a host key has just been changed.
    The fingerprint for the ECDSA key sent by the remote host is
    SHA256:DbfOyGobbLDEgoOkbNPlAA.
    Please contact your system administrator.
    Add correct host key in /Users/adam/.ssh/known_hosts to get rid of this message.
    Offending ECDSA key in /Users/adam/.ssh/known_hosts:227
    ECDSA host key for 192.168.1.35 has changed and you have requested strict checking.
    Host key verification failed.

The important line is the third from the bottom ending with `/.ssh/known_hosts:227`.  This tells us that line 227 of the known_hosts file on the local system is the one we want to remove.  Use your favorite text editor to remove the line.  The line should look similar to the following - it will either be the IP address or the hostname depending on which you've used.

    192.168.1.35 ecdsa-sha2-nistp256 AAAAE2VjZH... snip ...

When you next try to ssh into the pi, it should give you the "The authenticity of host..." message and all will be good.

Copy your ssh public key to the pi so you don't have to type the password each time.

    adam@Adams-MacBook-Air: ssh-copy-id -i ~/.ssh/macbookair_id_rsa pi@192.168.1.35

## Security third

Change the pi user password to something other than the default.

    pi@pi-sd-card:~ $ passwd pi

## Firmware

The second stage script sets up the apt proxy, runs update/full-upgrade, updates up raspberry boot order and firmware branch.

    pi@pi-sd-card:~ $ sudo /boot/provision/manual/sd-02-second-stage.sh

Reboot to make any changes take effect.

    pi@pi-sd-card:~ $ sudo reboot

Verify the bootloader is up-to-date.

    pi@pi-sd-card:~ $ sudo rpi-eeprom-update

    BCM2711 detected
    VL805 firmware in bootloader EEPROM
    BOOTLOADER: up-to-date
    CURRENT: Fri 31 Jul 2020 01:43:39 PM UTC (1596203019)
     LATEST: Fri 31 Jul 2020 01:43:39 PM UTC (1596203019)
     FW DIR: /lib/firmware/raspberrypi/bootloader/stable
    VL805: up-to-date
    CURRENT: 000138a1
     LATEST: 000138a1

Verify the bootloader config has the BOOT_ORDER set to `0xf41`.

    pi@pi-sd-card:~ $ vcgencmd bootloader_config
    
    [all]
    BOOT_UART=0
    WAKE_ON_GPIO=1
    POWER_OFF_ON_HALT=0
    DHCP_TIMEOUT=45000
    DHCP_REQ_TIMEOUT=4000
    TFTP_FILE_TIMEOUT=30000
    TFTP_IP=
    TFTP_PREFIX=0
    BOOT_ORDER=0xf41

### Updating the Bootloader With No Changes

To update the bootloader without making changes to the config, you can use raspi-config.  The `E1` is for picking the latest stable version.  The `0` is to apply the latest version if needed.

    pi@pi-sd-card:~ $ sudo raspi-config nonint do_boot_rom E1 0

### Changing Bootloader Config

Changing the bootloader config is done by merging a new config file with a bin file and then applying it to the hardware.

The first step is to get the current config into a text file.

    pi@pi-sd-card:~ $ vcgencmd bootloader_config > boot_config.txt

Make any necessary changes to the file.  Then, find the desired bin file.  Look for the one that matches the current date from the `vcgencmd bootloader_version` command.

    pi@pi-sd-card:~ $ ls -alph /lib/firmware/raspberrypi/bootloader/stable/pieeprom-*

Merge the desired config to the firmware.

    pi@pi-sd-card:~ $ rpi-eeprom-config --out output-eeprom.bin --config boot_config.txt /lib/firmware/raspberrypi/bootloader/stable/pieeprom-2020-07-16.bin

Apply the updated config to the hardware.

    pi@pi-sd-card:~ $ sudo rpi-eeprom-update -d -f output-eeprom.bin

    BCM2711 detected
    VL805 firmware in bootloader EEPROM
    BOOTFS /boot
    *** INSTALLING output-eeprom.bin  ***
    BOOTFS /boot
    EEPROM update pending. Please reboot to apply the update.

Reboot.

    pi@pi-sd-card:~ $ sudo reboot

## Copy OS image file

Get the OS image onto the SD card in any manner you want.  Download with curl or wget (apt-get install needed) or copy via USB drive.

Create a folder for the image.  I named it `ISOs` out of habit even though the file is `.img`.

    pi@pi-sd-card:~ $ mkdir ~/ISOs

Create a folder to mount the usb drive and then mount it.

    pi@pi-sd-card:~ $ sudo mkdir /mnt/usb
    pi@pi-sd-card:~ $ sudo mount /dev/sda1 /mnt/usb

Copy the image and the shasum check file to the `ISOs` folder.

    pi@pi-sd-card:~ $ cp /mnt/usb/2020-05-27-raspios-buster-lite-armhf.img ~/ISOs/
    pi@pi-sd-card:~ $ cp /mnt/usb/SHASUM ~/ISOs/

Verify the file copied correctly.  You need to be in the `ISOs` folder for this.

    pi@pi-sd-card:~ $ cd ~/ISOs
    pi@pi-sd-card:~/ISOs $ shasum -c SHASUM

    2020-05-27-raspios-buster-lite-armhf.img: OK

Unmount the USB drive.

    pi@pi-sd-card:~ $ sudo umount /dev/sda1

## Download Updated Boot Files

Currently (Mid August 2020), the pi4 doesn't like to usb boot using the 2020-05-27-raspios-buster-lite-armhf.img image.  We need to replace some files in the boot partition to make it work.  These files are available on the github repo but it is too wasteful in time/bandwidth to clone the whole thing.  Rather than hardcode a list of files which might change, this gets a file listing from the repo and then selectively downloads only the ones we want.
No need to use sudo for this one as it is downloading files to the current user's home folder.

    pi@pi-sd-card:~ $ /boot/provision/manual/sd-03-download-boot-files.sh

## Prepare the SSD

These are steps that would be repeated for each SSD.  You should be able to prepare all SSDs using one Pi and then attach those SSDs to other Pis.  So long as the other Pis get firmware updates to be able to boot from USB.

### Gather Info

Plug in the USB/SATA dongle with the 500GB SSD attached.  If there is one, the only other attached USB device should be the keyboard wireless receiver.

Check what is currently on the drive as it will be completely formatted in a moment.  Mount the drive to check contents if needed.  Don't forget to unmount the drive before proceeding.

    pi@pi-sd-card:~ $ lsblk -f

    NAME        FSTYPE LABEL  UUID                                 FSAVAIL FSUSE% MOUNTPOINT
    sda
    ├─sda1      vfat   boot   592B-C92C
    ├─sda2      ext4   rootfs 706944a6-7d0f-4a45-9f8c-7fb07375e9f7
    └─sda3
    mmcblk0
    ├─mmcblk0p1 vfat   boot   592B-C92C                             200.2M    21% /boot
    └─mmcblk0p2 ext4   rootfs 706944a6-7d0f-4a45-9f8c-7fb07375e9f7   26.7G     4% /

### Write Image

Write the image copied to the sd card to the ssd.  You can use your favorite way of doing so or use the provided script.  It will make sure the destination device is not mounted and that the image file exists.  Might eventually make sure the device is large enough as well.  Writing the image should take less than a minute.

    pi@pi-sd-card:~ $ sudo /boot/provision/manual/sd-04-write-image.sh sda ~/ISOs/2020-05-27-raspios-buster-lite-armhf.img

    # Run one
    1837105152 bytes (1.8 GB, 1.7 GiB) copied, 41 s, 44.7 MB/s
    442+0 records in
    442+0 records out
    1853882368 bytes (1.9 GB, 1.7 GiB) copied, 41.8977 s, 44.2 MB/s
    
    # Run two - different pi and ssd
    1795162112 bytes (1.8 GB, 1.7 GiB) copied, 7 s, 256 MB/s
    442+0 records in
    442+0 records out
    1853882368 bytes (1.9 GB, 1.7 GiB) copied, 7.60404 s, 244 MB/s

### PreBoot Customizations

Once the image is written, the drive should contain two partitions - FAT32 and ext4.  Use the folders, '/mnt/ssd_boot' and '/mnt/ssd_root', to mount these partitions for customization.

    pi@pi-sd-card:~ $ sudo /boot/provision/manual/mount-ssd.sh sda
    pi@pi-sd-card:~ $ mounted

    /dev/mmcblk0p2 on / type ext4 (rw,noatime)
    /dev/mmcblk0p1 on /boot type vfat (rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=ascii,shortname=mixed,errors=remount-ro)
    /dev/sda1 on /mnt/ssd_boot type vfat (rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=ascii,shortname=mixed,errors=remount-ro)
    /dev/sda2 on /mnt/ssd_root type ext4 (rw,relatime)

Run the next script to resize the root partition and create a swap partition.  It depends on the ssd being mounted so it can automagically determine the device to work with.  Probably should just pass in 'sda' so there isn't any guesswork.  Also for consistency with the `mount-ssd.sh` script.

    pi@pi-sd-card:~ $ sudo /boot/provision/manual/sd-05-resize_root_and_make_swap.sh

The last bit of output should show three partitions and some detail.

    /dev/sda1: LABEL_FATBOOT="boot" LABEL="boot" UUID="592B-C92C" TYPE="vfat" PARTUUID="b44f6031-01"
    /dev/sda2: LABEL="rootfs" UUID="706944a6-7d0f-4a45-9f8c-7fb07375e9f7" TYPE="ext4" PARTUUID="b44f6031-02"
    /dev/sda3: PARTUUID="b44f6031-03"

The resizing script will leave the SSD unmounted.  We need to mount it again.

    pi@pi-sd-card:~ $ sudo /boot/provision/manual/mount-ssd.sh sda

Create the boot/provision folder and clone the rpi-cluster repo there.

    pi@pi-sd-card:~ $ sudo mkdir /mnt/ssd_boot/provision/
    pi@pi-sd-card:~ $ sudo git clone https://github.com/adamtorres/rpi-cluster/ /mnt/ssd_boot/provision/

Run the next preboot customization script.

    pi@pi-sd-card:~ $ sudo mkdir /mnt/ssd_boot/provision/manual/ssd-01-preboot-customizations.sh

This script will:

* Remove the boot command line option that resizes the root partition.
* Add usb quirk option to cmdline.txt if it isn't there already.
* Copy the current wpa_supplicant.conf to the new boot folder.
* Copy elf and dat files to the ssd's boot partition.
* Remove the startup script that resizes the filesystem within the larger partition.
* Create the ssh file to tell pi ssh should be enabled.

## Give it a go

Shut down the Pi and remove the SD card.

    pi@pi-sd-card:~ $ sudo shutdown -h now

If everything worked correctly, when you power on the Pi, it should boot as normal.

### Pitfall - boot hangs up

If you see the following message, it likely means your USB dongle doesn't support UAP.

    Timed out waiting for device /dev/disk/by-partuuid/2fed7fee-01

Check the info for the dongle being used.

    lsusb
    
    Bus 002 Device 002: ID 174c:55aa ASMedia Technology Inc. Name: ASM1051E SATA 6Gb/s bridge, ASM1053E SATA 6Gb/s bridge, ASM1153 SATA 3Gb/s bridge, ASM1153E SATA 6Gb/s bridge

Google for the manufacturer/device id (174c:55aa ASMedia) for any issues.

Add the following to the start of /mnt/ssd_boot/cmdline.txt

    sudo mount /dev/sda1 /mnt/ssd_boot
    sudo vi /mnt/ssd_boot/cmdline.txt
    usb-storage.quirks=174c:55aa:u

Shutdown and try again.

### First boot

You should see a line in the boot up output showing the IP address.

    My IP address is 192.168.1.37

Feel free to ssh into the Pi at this point.  You will have to remove a line from your local known_hosts file as described in the earlier section, "SSH into the pi".

Use the default credentials to log in - pi/raspberry.  Run the next SSD script.  This will configure various settings including the hostname.  It will take a while as one of the first steps is to update the apt cache and do a full-upgrade.

    pi@raspberry:~ $ sudo mkdir /mnt/ssd_boot/provision/manual/ssd-02-raspi-config.sh

Reboot afterwards as it will complain about the hostname when doing sudo commands.

    pi@raspberry:~ $ sudo reboot

### Second boot

Run the next SSD script to turn off the file-based swap that Pi uses by default.  The swap partition is defined in fstab already so it should already be active.

    pi@pi-ABCDEF:~ $ sudo mkdir /mnt/ssd_boot/provision/manual/ssd-03-swap_swaps.sh

### Security Third, Again

Change the default password.

    pi@pi-ABCDEF:~ $ passwd pi

## Done

At this point, the Pi should be good to go.  It'd be nice to have a way to snapshot the drive.  Just a command if it were a virtual machine.

# Annoyances

## USB/SATA Adapter not UASP

UASP is some sort of fancy protocol (USB Attached SCSI Protocol) that makes data transfers faster.  Finding an adapter that works with the pi using UASP would be beneficial.  Unfortunately, even if a product claims to support UASP, it might not do so on the pi.  The ones I bought (Eluteng) did not.  I had to add the quirks line to cmdline.txt.  Scanning through `dmesg` shows that UAS is not being used for the device.

    [    1.552154] usb 2-1: new SuperSpeed Gen 1 USB device number 2 using xhci_hcd
    [    1.583195] usb 2-1: New USB device found, idVendor=174c, idProduct=55aa, bcdDevice= 1.00
    [    1.583212] usb 2-1: New USB device strings: Mfr=2, Product=3, SerialNumber=1
    [    1.583227] usb 2-1: Product: Best USB Device
    [    1.583242] usb 2-1: Manufacturer: ULT-Best
    [    1.583256] usb 2-1: SerialNumber: 042004071A43
    [    1.586574] usb 2-1: UAS is blacklisted for this device, using usb-storage instead
    [    1.586686] usb 2-1: UAS is blacklisted for this device, using usb-storage instead
    [    1.586703] usb-storage 2-1:1.0: USB Mass Storage device detected
    [    1.587187] usb-storage 2-1:1.0: Quirks match for vid 174c pid 55aa: c00000
