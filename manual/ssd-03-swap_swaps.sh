#! /usr/bin/env bash
# Should this use "set -e"?

echo "Before:"
free -m
echo ""
dphys-swapfile swapoff
dphys-swapfile uninstall
update-rc.d dphys-swapfile remove
echo ""
echo "After:"
free -m