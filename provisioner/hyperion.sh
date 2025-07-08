#!/bin/bash
#
# hyperion.sh 
# Prepares a fresh RPi OS and monitors the first run of the provisioner.


set -e


echo "  ---------> Starting Hyperion Bootstrap <---------  "
if [[ $EUID -ne 0 ]]; then echo "ERROR: This script must be run as root."; exit 1; fi


echo "  ---------> Performing pre-flight cleanup <---------  "
rm -rf /opt/Hyperion /etc/hyperion


echo "  ---------> Installing prerequisites (git, jq) <---------  "
apt-get update && dpkg --configure -a && apt-get install -y --fix-broken git jq


echo "  ---------> Please provide your GitHub credentials to clone your private config repository."
read -p "Enter your GitHub Username: " GITHUB_USER
read -s -p "Enter your GitHub Personal Access Token (PAT): " GITHUB_PAT
echo


sudo rm -rf /opt/Hyperion /etc/hyperion

echo "  ---------> Cloning repositories <---------  "
git clone https://github.com/getXzooted/Hyperion.git /opt/Hyperion

mkdir -p /etc/hyperion
git clone "https://_:${GITHUB_PAT}@github.com/${GITHUB_USER}/Hyperion-config.git" /etc/hyperion/config


echo "  ---------> Setting up the Hyperion provisioning service <---------  "
cp /opt/Hyperion/provisioner/hyperion-engine.sh /usr/local/bin/hyperon-engine.sh
cp /opt/Hyperion/provisioner/hyperion.service /etc/systemd/system/hyperion.service
chmod +x /usr/local/bin/hyperion-engine.sh

echo "  ---------> Enabling the service <---------  "
systemctl daemon-reload
systemctl enable hyperion.service

echo "----------------------------------------------------------------"
echo " SUCCESS: Bootstrap complete!"
echo " After Restart Hyperion Provisioning Service runs in background."
echo " The system may reboot automatically as part of the process."
echo " You can monitor progress with the command:"
echo " journalctl -fu hyperion.service"
echo "----------------------------------------------------------------"

echo "Starting in 10"
sleep 1
echo "Starting in 9"
sleep 1
echo "Starting in 8"
sleep 1
echo "Starting in 7"
sleep 1
echo "Starting in 6"
sleep 1
echo "Starting in 5"
sleep 1
echo "Starting in 4"
sleep 1
echo "Starting in 3"
sleep 1
echo "Starting in 2"
sleep 1
echo "Starting in 1"
sleep 1 

echo "  ---------> Running the master the first time <---------  "
sudo bash /usr/local/bin/hyperion-engine.sh