#! /usr/bin/env bash

# Currently (Mid August 2020), the pi4 doesn't like to usb boot using the
# 2020-05-27-raspios-buster-lite-armhf.img image.  Need to replace some
# files in the boot partition to make it work.  These files are available
# on the github repo but it is too wasteful in time/bandwidth to clone the
# whole thing.  Rather than hardcode a list of files which might change,
# this gets a file listing from the repo and then selectively downloads
# only the ones we want.

mkdir -p ~/boot_files/stable/ > /dev/null 2>&1
pushd ~/boot_files/stable/ > /dev/null

# oneliner from https://gist.github.com/atomicstack/9c43e452c4b7cefb37c1e78f65b0b1fa.
# Inner wget returns a list of urls for the wanted .dat and .elf files.  Outter wget downloads those files.
wget $( wget -qO - https://github.com/raspberrypi/firmware/tree/stable/boot | perl -nE 'chomp; next unless /[.](elf|dat)/; s/.*href="([^"]+)".*/$1/; s/blob/raw/; say qq{https://github.com$_}' )

popd > /dev/null
