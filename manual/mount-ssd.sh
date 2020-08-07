#! /usr/bin/env bash

if [ ! -d "/mnt/ssd1" ]; then
  sudo mkdir /mnt/ssd1
fi
if [ ! -d "/mnt/ssd2" ]; then
  sudo mkdir /mnt/ssd2
fi
sudo mount /dev/sda1 /mnt/ssd1
sudo mount /dev/sda2 /mnt/ssd2

