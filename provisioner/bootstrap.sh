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
mkdir -p /etc/hyperion
git clone "https://_:${GITHUB_PAT}@github.com/${GITHUB_USER}/Hyperion-config.git" /etc/hyperion/config

echo "--> Setting up the Hyperion provisioning service..."
cp /opt/Hyperion/provisioner/master-provisioner.sh /usr/local/bin/master-provisioner.sh
cp /opt/Hyperion/provisioner/pi-provisioner.service /etc/systemd/system/pi-provisioner.service
chmod +x /usr/local/bin/master-provisioner.sh

echo "--> Enabling and starting the service for the first time..."
systemctl daemon-reload
systemctl enable --now pi-provisioner.service

# --- NEW: Tripwire Monitoring Loop ---
echo "--> Monitoring initial provisioning run..."
TIMEOUT=300 # 5 minute timeout for the first run to complete
while systemctl is-active --quiet pi-provisioner.service; do
  sleep 5
  TIMEOUT=$((TIMEOUT-5))
  if [ $TIMEOUT -le 0 ]; then log_error "Timed out waiting for provisioner to finish."; exit 1; fi
done
echo "--> Initial run finished. Checking for reboot request..."

# Check if the engine left a reboot request file
if [ -f "/etc/hyperion/state/REBOOT_REQUIRED" ]; then
    echo "--> Provisioner has requested a reboot to apply critical changes."
    rm -f /etc/hyperion/state/REBOOT_REQUIRED
    echo "--> REBOOTING NOW..."
    sleep 5
    reboot
else
    echo "--> No reboot was requested. Bootstrap complete."
fi

echo "----------------------------------------------------------------"
echo " SUCCESS: Bootstrap complete!"
echo " The Hyperion provisioning service is now running in the background."
echo " The system may reboot automatically as part of the process."
echo " You can monitor progress with the command:"
echo " journalctl -fu pi-provisioner.service"
echo "----------------------------------------------------------------"
