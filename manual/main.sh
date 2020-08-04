#! /usr/bin/env bash

./create-partitions.sh
./copy-partitions.sh
./usb-boot-setup.sh
./change-boot-order.sh
./rename-pi.sh
