#!/bin/bash
# bootstrap.sh (v1.3 - Tripwire Logic)
# Prepares a fresh RPi OS and monitors the first run of the provisioner.

set -e

echo "--- Starting Hyperion Bootstrap ---"
if [[ $EUID -ne 0 ]]; then echo "ERROR: This script must be run as root."; exit 1; fi

echo "--> Performing pre-flight cleanup..."
rm -rf /opt/Hyperion /etc/hyperion
echo "--> Installing prerequisites (git, jq)..."
apt-get update && dpkg --configure -a && apt-get install -y --fix-broken git jq

echo "--> Please provide your GitHub credentials to clone your private config repository."
read -p "Enter your GitHub Username: " GITHUB_USER
read -s -p "Enter your GitHub Personal Access Token (PAT): " GITHUB_PAT
echo

echo "--> Cloning repositories..."
git clone https://github.com/getXzooted/Hyperion.git /opt/Hyperion
# Fix ownership of the cloned repository
#
echo "--> Taking ownership of the /opt/Hyperion directory..."
if [ -n "$SUDO_USER" ]; then
    sudo chown -R "$SUDO_USER":"$SUDO_USER" /opt/Hyperion
else
    # Fallback for running as root directly
    sudo chown -R "$(logname)":"$(logname)" /opt/Hyperion
fi

mkdir -p /etc/hyperion
git clone "https://_:${GITHUB_PAT}@github.com/${GITHUB_USER}/Hyperion-config.git" /etc/hyperion/config

echo "--> Setting up the Hyperion provisioning service..."
cp /opt/Hyperion/provisioner/master-provisioner.sh /usr/local/bin/master-provisioner.sh
cp /opt/Hyperion/provisioner/pi-provisioner.service /etc/systemd/system/pi-provisioner.service
chmod +x /usr/local/bin/master-provisioner.sh

echo "--> Enabling the service"
systemctl daemon-reload
systemctl enable pi-provisioner.service

echo "--> Running the master the first time"
sudo bash /usr/local/bin/master-provisioner.sh

echo "--> Initial run finished. Checking for reboot request..."

if [ -f "/etc/hyperion/state/REBOOT_REQUIRED" ]; then
    echo "--> Provisioner has requested a reboot. REBOOTING NOW..."
    rm -f /etc/hyperion/state/REBOOT_REQUIRED
    sleep 5
    reboot
    exit 0
else
    echo "--> No reboot was requested. Bootstrap complete."
fi

echo "----------------------------------------------------------------"
echo " SUCCESS: Bootstrap complete!"
echo " After Restart Hyperion Provisioning Service runs in background."
echo " The system may reboot automatically as part of the process."
echo " You can monitor progress with the command:"
echo " journalctl -fu pi-provisioner.service"
echo "----------------------------------------------------------------"