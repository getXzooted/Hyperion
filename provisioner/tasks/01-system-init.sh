#!/bin/bash

set -e
echo "  -> Updating package lists..."
apt-get update
echo "  -> Upgrading existing packages..."
apt-get upgrade -y
echo "  -> Update and Upgrade complete."