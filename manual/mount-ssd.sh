#! /usr/bin/env bash

mount_device() {
    echo "mounting $1 to $2"
    if [ ! -d "$2" ]; then
      sudo mkdir "$2"
    fi
    findmnt "$2" -n > /dev/null
    if [ "$?" -eq 1 ]; then
      sudo mount "$1" "$2"
    fi
}
mount_device /dev/${1}1 /mnt/ssd_boot
mount_device /dev/${1}2 /mnt/ssd_root
