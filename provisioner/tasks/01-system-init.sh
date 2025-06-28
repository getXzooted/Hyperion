#!/bin/bash
#Task: 01-system-init.sh
#Prepares the System for Hyperion

set -e
echo "  -> Updating package lists..."
apt-get update
echo "  -> Upgrading existing packages..."
apt-get upgrade -y
echo "  -> Update and Upgrade complete."