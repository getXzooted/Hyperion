#!/bin/bash
#
# hyperion.sh 
# Prepares a fresh RPi OS and monitors the first run of the provisioner.


set -e


# --- Configuration & Constants ---
REPO_URL="https://github.com/getXzooted/Hyperion.git"
REPO_DIR="/opt/Hyperion"
BASE_PATH="/opt/Hyperion/configs/hyperion.json"
COMMAND_PATH="/usr/local/bin/hyperion"
ENGINE_PATH="/usr/local/bin/hyperion-engine.sh"
SERVICE_PATH="/etc/systemd/system/hyperion.service"
CONFIG_FILE="/etc/hyperion/config/config-$(hostname).json"


echo "  ---------> Starting Hyperion Bootstrap <---------  "
if [[ $EUID -ne 0 ]]; then echo "ERROR: This script must be run as root."; exit 1; fi


echo "  ---------> Performing pre-flight cleanup <---------  "
rm -rf /opt/Hyperion /etc/hyperion
mkdir -p /etc/hyperion/config


echo "  ---------> Installing prerequisites (git, jq) <---------  "
apt-get update && dpkg --configure -a && apt-get install -y --fix-broken git jq


echo "  ---------> Cloning repositories <---------  "
git clone "$REPO_URL" "$REPO_DIR"


echo "  ---------> Setting up the Hyperion provisioning service <---------  "
cp "${REPO_DIR}/provisioner/hyperion-engine.sh" "$ENGINE_PATH"
cp "${REPO_DIR}/provisioner/hyperion.service" "$SERVICE_PATH"
cp "${REPO_DIR}/provisioner/hyperion" "$COMMAND_PATH"
cp "$BASE_PATH" "$CONFIG_FILE"
chmod +x "$ENGINE_PATH"
chmod +x "$COMMAND_PATH"


echo "  ---------> Enabling the service <---------  "
systemctl daemon-reload
systemctl enable hyperion.service

echo "----------------------------------------------------------------"
echo " SUCCESS: Bootstrap complete!"
echo " After Restart Hyperion Provisioning Service runs in background."
echo " The system may reboot automatically as part of the process."
echo " You can monitor progress with the command: sudo hyperion or"
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

echo "  ---------> Running the Engine <---------  "
sudo bash /usr/local/bin/hyperion-engine.sh $BASE_PATH