#! /usr/bin/env bash

echo "======= starting partition copy"
echo "Should be quick"
time sudo dd if=/dev/mmcblk0p1 of=/dev/sda1 bs=4M iflag=fullblock oflag=direct,dsync status=progress

echo "Takes 10 or so minutes.  Counts up to 32GB"
time sudo dd if=/dev/mmcblk0p2 of=/dev/sda2 bs=4M iflag=fullblock oflag=direct,dsync status=progress
sync
echo "======= done partition copy"
