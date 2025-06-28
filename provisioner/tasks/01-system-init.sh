#!/bin/bash
# Task: 01-system-init.sh (v1.1)
# Updates the system and is resilient to interruptions.

set -e

echo "  -> Checking for and fixing any interrupted package operations..."
# This is critical for recovering from a reboot that interrupted a previous apt run.
dpkg --configure -a

echo "  -> Updating package lists..."
apt-get update

echo "  -> Upgrading existing packages..."
# The --fix-broken flag is another safety measure
apt-get install --fix-broken -y
apt-get upgrade -y

echo "  -> Update and Upgrade complete."