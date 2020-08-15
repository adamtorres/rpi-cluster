#! /usr/bin/env bash

# Generates a hostname that is "pi-" followed by the last 6 characters of the wifi MAC addres.
NEW_HOSTNAME="pi-$(ip a show wlan0 | grep 'link/ether' | grep -o '..:..:.. ' | tr '[:lower:]' '[:upper:]' | tr -d '[:punct:]' | tr -d '[:blank:]')"
echo "Renaming pi from '$(hostname)' to '$NEW_HOSTNAME'"
sudo sed -i.bak -e "s/.*/$NEW_HOSTNAME/" /etc/hostname
sudo sed -i.bak -e "s/127\.0\.1\.1.*/127.0.1.1\t\t$NEW_HOSTNAME $NEW_HOSTNAME.local/" /etc/hosts
