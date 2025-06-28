#!/bin/bash
# Task: 01-system-init.sh
# Updates the system and is resilient to interruptions.
# Sets iptables to legacy mode, then updates the system.

set -e

echo "  -> Forcing iptables to legacy mode for K3s/CNI compatibility..."
update-alternatives --set iptables /usr/sbin/iptables-legacy
update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

echo "  -> Checking for and fixing any interrupted package operations..."
dpkg --configure -a

echo "  -> Updating package lists..."
apt-get update

echo "  -> Upgrading existing packages..."
apt-get install --fix-broken -y
apt-get upgrade -y

echo "  -> Update and Upgrade complete."