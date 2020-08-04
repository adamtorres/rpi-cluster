#! /usr/bin/env bash

sudo sfdisk /dev/sda < partitions.txt
sudo sfdisk -A /dev/sda1
sudo sfdisk -l /dev/sda
