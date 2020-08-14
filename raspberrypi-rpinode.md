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

Use raspi-config to attach to the wifi.  It might claim "sudo: unable to resolve host..."  Just ignore that.  The command still works.  Check the wpa_supplicant file if you don't believe me.  The wifi setup is in the network menu.

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

    The authenticity of host 'pi-sd-card.local (192.168.1.35)' can't be established.
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

    pi-sd-card.local ecdsa-sha2-nistp256 AAAAE2VjZH... snip ...

If you feel like it, you can use `sed` to remove the line.

    adam@Adams-MacBook-Air: sed -i.bak "/pi-sd-card.local/d" ~/.ssh/known_hosts

When you next try to ssh into the pi, it should give you the "The authenticity of host..." message and all will be good.

Copy your ssh public key to the pi so you don't have to type the password each time.

    adam@Adams-MacBook-Air: ssh-copy-id -i ~/.ssh/macbookair_id_rsa pi@pi-sd-card.local

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

Skip to "Copy OS image file" if all went well.  The next sections deal with updating the bootloader manually.

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

Verify which device the USB drive has been assigned.  Look for the only "sd?" device assuming you have only the USB drive plugged in.

    pi@pi-sd-card:~ $ sudo blkid

    /dev/mmcblk0p1: LABEL_FATBOOT="boot" LABEL="boot" UUID="592B-C92C" TYPE="vfat" PARTUUID="16370ba1-01"
    /dev/mmcblk0p2: LABEL="rootfs" UUID="706944a6-7d0f-4a45-9f8c-7fb07375e9f7" TYPE="ext4" PARTUUID="16370ba1-02"
    /dev/mmcblk0: PTUUID="16370ba1" PTTYPE="dos"
    /dev/sda1: LABEL_FATBOOT="SNEAKER" LABEL="SNEAKER" UUID="3B62-17E5" TYPE="vfat"

Create a folder to mount the usb drive and then mount it.

    pi@pi-sd-card:~ $ sudo mkdir /mnt/usb
    pi@pi-sd-card:~ $ sudo mount /dev/sda1 /mnt/usb

Copy the image and the shasum check file to the `ISOs` folder.  The squiggly bracket thing is just to save a step in copying the two files.

    pi@pi-sd-card:~ $ cp /mnt/usb/{SHASUM,2020-05-27-raspios-buster-lite-armhf.img} ~/ISOs/

Verify the file copied correctly.  You need to be in the `ISOs` folder for this as the path in the SHASUM file is relative.

    pi@pi-sd-card:~ $ cd ~/ISOs
    pi@pi-sd-card:~/ISOs $ shasum -c SHASUM

    2020-05-27-raspios-buster-lite-armhf.img: OK

Unmount the USB drive and unplug it.

    pi@pi-sd-card:~ $ sudo umount /dev/sda1

## Download Updated Boot Files

Currently (Mid August 2020), the pi4 doesn't like to usb boot using the 2020-05-27-raspios-buster-lite-armhf.img image.  We need to replace some files in the boot partition to make it work.  These files are available on the github repo but it is too wasteful in time/bandwidth to clone the whole thing.  Rather than hardcode a list of files which might change, this gets a file listing from the repo and then selectively downloads only the ones we want.
Do not use sudo for this one as it is downloading files to the current user's home folder.  It creates a folder using the "~" shortcut.  If sudo is used, that folder will be in "/root" and will not be where later scripts expect.

A lot of output is generated by this script.  Only one file's output and the final total lines are shown.

    pi@pi-sd-card:~ $ /boot/provision/manual/sd-03-download-boot-files.sh

    --2020-08-14 10:19:43--  https://github.com/raspberrypi/firmware/raw/stable/boot/start4.elf
    Connecting to github.com (github.com)|140.82.114.4|:443... connected.
    HTTP request sent, awaiting response... 302 Found
    Location: https://raw.githubusercontent.com/raspberrypi/firmware/stable/boot/start4.elf [following]
    --2020-08-14 10:19:43--  https://raw.githubusercontent.com/raspberrypi/firmware/stable/boot/start4.elf
    Connecting to raw.githubusercontent.com (raw.githubusercontent.com)|151.101.68.133|:443... connected.
    HTTP request sent, awaiting response... 200 OK
    Length: 2277856 (2.2M) [application/octet-stream]
    Saving to: ‘start4.elf’
    
    start4.elf                                 100%[======================================================================================>]   2.17M  6.42MB/s    in 0.3s
    
    2020-08-14 10:19:44 (6.42 MB/s) - ‘start4.elf’ saved [2277856/2277856]
    FINISHED --2020-08-14 10:19:54--
    Total wall clock time: 19s
    Downloaded: 16 files, 21M in 3.0s (7.01 MB/s)

## Prepare the SSD

These are steps that would be repeated for each SSD.  You should be able to prepare all SSDs using one Pi and then attach those SSDs to other Pis.  So long as the other Pis get firmware updates to be able to boot from USB.

### Gather Info

Plug in the USB/SATA dongle with the 500GB SSD attached.  If there is one, the only other attached USB device should be the keyboard wireless receiver.

Check what is currently on the drive as it will be completely formatted in a moment.  Mount the drive to check contents if needed.  Don't forget to unmount the drive before proceeding.  It doesn't matter what "sda" currently has as it will be completely removed in a moment.  In other words, be certain this is the drive you want to use.

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

    writing /home/pi/ISOs/2020-05-27-raspios-buster-lite-armhf.img to sda...
    dest size = 500107862016
    1795162112 bytes (1.8 GB, 1.7 GiB) copied, 7 s, 256 MB/s
    442+0 records in
    442+0 records out
    1853882368 bytes (1.9 GB, 1.7 GiB) copied, 8.00288 s, 232 MB/s

    # Times for another run
    1837105152 bytes (1.8 GB, 1.7 GiB) copied, 41 s, 44.7 MB/s
    1853882368 bytes (1.9 GB, 1.7 GiB) copied, 41.8977 s, 44.2 MB/s
    
    # Times for yet another run - different pi and ssd
    1795162112 bytes (1.8 GB, 1.7 GiB) copied, 7 s, 256 MB/s
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
    /dev/sda3: UUID="f6743640-305d-43d5-922a-74e1348761b3" TYPE="swap" PARTUUID="b44f6031-03"

The resizing script will leave the SSD unmounted.  We need to mount it again.

    pi@pi-sd-card:~ $ sudo /boot/provision/manual/mount-ssd.sh sda

Create the boot/provision folder and clone the rpi-cluster repo there.

    pi@pi-sd-card:~ $ sudo mkdir /mnt/ssd_boot/provision/
    pi@pi-sd-card:~ $ sudo git clone https://github.com/adamtorres/rpi-cluster /mnt/ssd_boot/provision/

Run the next preboot customization script.

    pi@pi-sd-card:~ $ sudo /mnt/ssd_boot/provision/manual/ssd-01-preboot-customizations.sh

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

If everything worked correctly, when you power on the Pi, it should boot as normal.  For some reason as yet unexplored, it might take a long time to boot.  If you get to around three minutes, I'm guessing something is wrong.

### Pitfall - boot hangs up with timeout warnings

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

### Pitfall - boot hangs up with just 4 raspberries

The fstab and cmdline.txt files did not get the new PARTUUID for some reason.  Had to manually make the changes.

Insert and boot to the SD card.

Mount the SSD.

    pi@pi-sd-card:~ $ sudo /boot/provision/manual/mount-ssd.sh sda

Verify this is the problem.  The default PARTUUID from the image file is "2fed7fee".

    pi@pi-sd-card:~ $ cat /mnt/ssd_root/etc/fstab

    proc            /proc           proc    defaults          0       0
    PARTUUID=2fed7fee-01  /boot           vfat    defaults          0       2
    PARTUUID=2fed7fee-02  /               ext4    defaults,noatime  0       1
    UUID=f6743640-305d-43d5-922a-74e1348761b3 none            swap    sw              0       0

Get the new PARTUUID of the SSD.

    pi@pi-sd-card:~ $ sudo blkid /dev/sda?
    /dev/sda1: LABEL_FATBOOT="boot" LABEL="boot" UUID="592B-C92C" TYPE="vfat" PARTUUID="e1c1787c-01"
    /dev/sda2: LABEL="rootfs" UUID="706944a6-7d0f-4a45-9f8c-7fb07375e9f7" TYPE="ext4" PARTUUID="e1c1787c-02"
    /dev/sda3: UUID="f6743640-305d-43d5-922a-74e1348761b3" TYPE="swap" PARTUUID="e1c1787c-03"

Make the changes.

    pi@pi-sd-card:~ $ sudo sed -i "s/2fed7fee/e1c1787c/g" /mnt/ssd_root/etc/fstab
    pi@pi-sd-card:~ $ sudo sed -i "s/2fed7fee/e1c1787c/g" /mnt/ssd_boot/cmdline.txt

Verify the changes worked.

    pi@pi-sd-card:~ $ cat /mnt/ssd_root/etc/fstab
    
    proc            /proc           proc    defaults          0       0
    PARTUUID=e1c1787c-01  /boot           vfat    defaults          0       2
    PARTUUID=e1c1787c-02  /               ext4    defaults,noatime  0       1
    UUID=f6743640-305d-43d5-922a-74e1348761b3 none            swap    sw              0       0

    pi@pi-sd-card:~ $ cat /mnt/ssd_boot/cmdline.txt
    
    console=serial0,115200 console=tty1 root=PARTUUID=e1c1787c-02 rootfstype=ext4 elevator=deadline fsck.repair=yes rootwait quiet

### First boot

You should see a line in the boot up output showing the IP address.

    My IP address is 192.168.1.37

!!! ssh is not active.

Feel free to ssh into the Pi at this point.  You will have to remove a line from your local known_hosts file as described in the earlier section, "SSH into the pi".

Use the default credentials to log in - pi/raspberry.  Run the next SSD script.  This will configure various settings including the hostname.  It will take a while as one of the first steps is to update the apt cache and do a full-upgrade.

    pi@raspberry:~ $ sudo /boot/provision/manual/ssd-02-raspi-config.sh

Reboot afterwards as it will complain about the hostname when doing sudo commands.

    pi@raspberry:~ $ sudo reboot

### Second boot

Run the next SSD script to turn off the file-based swap that Pi uses by default.  The swap partition is defined in fstab already so it should already be active.

    pi@pi-ABCDEF:~ $ sudo /boot/provision/manual/ssd-03-swap_swaps.sh

    Before:
                  total        used        free      shared  buff/cache   available
    Mem:           8015          95        7837           8          81        7735
    Swap:          8279           0        8279
    
    After:
                  total        used        free      shared  buff/cache   available
    Mem:           8015         101        7832           8          81        7730
    Swap:          8179           0        8179

### Security Third, Again

Change the default password.

    pi@pi-ABCDEF:~ $ passwd pi

## Done

At this point, the Pi should be good to go.  It'd be nice to have a way to snapshot the drive.  Just a command if it were a virtual machine.
If you want to provision another Pi/SSD, plug the SD card in, boot it up, and start from the "Firmware" step.  You will likely have to remove the line from your known_hosts file again.

# Annoyances

## USB/SATA Adapter not UASP

UASP is some sort of fancy protocol (USB Attached SCSI Protocol) that makes data transfers faster.  Finding an adapter that works with the pi using UASP would be beneficial.  Unfortunately, even if a product claims to support UASP, it might not do so on the pi.  The ones I bought (Eluteng) did not.  I had to add the quirks line to cmdline.txt.  Scanning through `dmesg` shows that UAS is not being used for the device.  To clarify, the dongle appeared to use UAS while booted from the SD card but would refuse to boot from the SSD without the quirks line.

    pi@pi-ABCDEF:~ $ sudo dmesg | grep usb

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

Booted from SD card.  The quirks bit is not in the cmdline.txt on the SD card.

    pi@pi-sd-card:~ $ lsusb -t

    /:  Bus 02.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/4p, 5000M
        |__ Port 1: Dev 2, If 0, Class=Mass Storage, Driver=uas, 5000M
    /:  Bus 01.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/1p, 480M
        |__ Port 1: Dev 2, If 0, Class=Hub, Driver=hub/4p, 480M
            |__ Port 3: Dev 3, If 0, Class=Human Interface Device, Driver=usbhid, 12M
            |__ Port 3: Dev 3, If 1, Class=Human Interface Device, Driver=usbhid, 12M
            |__ Port 3: Dev 3, If 2, Class=Human Interface Device, Driver=usbhid, 12M

And then from SSD.  It seems I need to learn more about this as this shows the SSD is using the UAS driver.

    pi@pi-ABCDEF:~ $ lsusb -t

    /:  Bus 02.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/4p, 5000M
        |__ Port 1: Dev 2, If 0, Class=Mass Storage, Driver=uas, 5000M
    /:  Bus 01.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/1p, 480M
        |__ Port 1: Dev 2, If 0, Class=Hub, Driver=hub/4p, 480M
            |__ Port 3: Dev 3, If 0, Class=Human Interface Device, Driver=usbhid, 12M
            |__ Port 3: Dev 3, If 1, Class=Human Interface Device, Driver=usbhid, 12M
            |__ Port 3: Dev 3, If 2, Class=Human Interface Device, Driver=usbhid, 12M

Showing without the `-t` to show bus 2, device 2 is the SSD.  The other devices are hubs or Logitech keyboard/mouse combo (K400r, for the curious).

    pi@pi-BB12D7:~ $ lsusb

    Bus 002 Device 002: ID 174c:55aa ASMedia Technology Inc. Name: ASM1051E SATA 6Gb/s bridge, ASM1053E SATA 6Gb/s bridge, ASM1153 SATA 3Gb/s bridge, ASM1153E SATA 6Gb/s bridge
    Bus 002 Device 001: ID 1d6b:0003 Linux Foundation 3.0 root hub
    Bus 001 Device 003: ID 046d:c52b Logitech, Inc. Unifying Receiver
    Bus 001 Device 002: ID 2109:3431 VIA Labs, Inc. Hub
    Bus 001 Device 001: ID 1d6b:0002 Linux Foundation 2.0 root hub
