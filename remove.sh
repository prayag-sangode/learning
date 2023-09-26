#!/bin/bash

# Prompt user for package name
read -p "Enter the name of the package you want to remove: " package_name

# Check if the package is installed
if dpkg -l | grep -q $package_name; then
    # If installed, remove and purge the package
    sudo apt remove $package_name -y
    sudo apt purge $package_name -y
    echo "Package $package_name has been removed and purged."
else
    echo "Package $package_name is not installed."
fi

# Clean up any leftover dependencies
sudo apt autoremove -y
