#!/bin/bash

# Setup for LinuxContainer project

DATA_DIR=~/linux_container_data
mkdir -p $DATA_DIR

# Download proot
echo "Downloading proot..."
curl -L https://github.com/ochen789/proot/releases/download/v0.1.0/proot -o $DATA_DIR/proot
chmod +x $DATA_DIR/proot

# Download Debian Bookworm rootfs
echo "Downloading Debian Bookworm rootfs..."
# Using a small rootfs for testing
curl -L https://github.com/misha10gr/debian-bookworm-rootfs/archive/refs/heads/main.zip -o $DATA_DIR/debian.zip
unzip $DATA_DIR/debian.zip -d $DATA_DIR/
# The unzip might create a directory, we want to move it to a standard name
# Let's check the result
ls -F $DATA_DIR
