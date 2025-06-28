#!/bin/bash
#
# bootstrap.sh
# This script prepares a fresh Raspberry Pi OS for the Hyperion provisioning engine.
# It should be run as root.

set -e # Exit immediately if a command exits with a non-zero status.

echo "--- Starting Hyperion Bootstrap ---"

# 1. Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "ERROR: This script must be run as root. Please use 'sudo'." 
   exit 1
fi

# 2. Install prerequisites
echo "--> Installing prerequisites (git)..."
apt-get update && apt-get install -y git

# 3. Get GitHub credentials to clone private repository
echo "--> Please provide your GitHub credentials to clone your private config repository."
read -p "Enter your GitHub Username: " GITHUB_USER
read -s -p "Enter your GitHub Personal Access Token (PAT): " GITHUB_PAT
echo

# 4. Clone the repositories
# The public engine is cloned to /opt/Hyperion
echo "--> Cloning public Hyperion engine..."
git clone https://github.com/getXzooted/Hyperion.git /opt/Hyperion

# The private config is cloned to /etc/hyperion (a system-wide config location)
echo "--> Cloning private Hyperion-config..."
mkdir -p /etc/hyperion
git clone "https://_:${GITHUB_PAT}@github.com/${GITHUB_USER}/Hyperion-config.git" /etc/hyperion/config

# 5. Set up the provisioning engine
echo "--> Setting up the Hyperion provisioning service..."

# We will create the master script file now, even though it's empty.
# In the next phase, we will add the logic to it.
touch /opt/Hyperion/provisioner/master-provisioner.sh

# Copy the engine and service files to their final destinations
cp /opt/Hyperion/provisioner/master-provisioner.sh /usr/local/bin/master-provisioner.sh
cp /opt/Hyperion/provisioner/pi-provisioner.service /etc/systemd/system/pi-provisioner.service

# Make the master script executable
chmod +x /usr/local/bin/master-provisioner.sh

# 6. Enable and start the service
echo "--> Enabling and starting the service for the first time..."
systemctl daemon-reload
systemctl enable --now pi-provisioner.service

echo "----------------------------------------------------------------"
echo " SUCCESS: Bootstrap complete!"
echo " The Hyperion provisioning service is now running in the background."
echo " The system may reboot automatically as part of the process."
echo " You can monitor progress with the command:"
echo " journalctl -fu pi-provisioner.service"
echo "----------------------------------------------------------------"