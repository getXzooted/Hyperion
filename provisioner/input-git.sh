#!/bin/bash
#
# input-git.sh 
# Separating the Git Login logic for future


set -e


# --- Configuration ---
PRIVATE_CONFIG_DIR="/etc/hyperion/config"
PUBLIC_REPO_URL="https://github.com/getXzooted/Hyperion"
COMPONENTS_DIR="/opt/Hyperion/components"
KUSTOMIZATION_ENGINE_PATH="/opt/Hyperion/provisioner/kustomization-engine.sh"


# --- Main Logic ---
echo "--- Hyperion Custom Deployment Engine ---"


# 1. Get Credentials
echo "  ---------> Please provide your GitHub credentials to clone your private config repository."
read -p "Enter your GitHub Username: " GITHUB_USER
read -s -p "Enter your GitHub Personal Access Token (PAT): " GITHUB_PAT
echo


# 2. Clone Private Repo
echo "  ---------> Cloning repositories <---------  "
rm -rf /etc/hyperion
mkdir -p /etc/hyperion
git clone "https://_:${GITHUB_PAT}@github.com/${GITHUB_USER}/Hyperion-config.git" /etc/hyperion/config

echo "  ---------> Git Connection Made Installing Custom Deployment <---------  "

# 3. Read User's Config
CONFIG_FILE="${PRIVATE_CONFIG_DIR}/config-$(hostname).json"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "--> ERROR: Could not find config file: $CONFIG_FILE"
    exit 1
fi
PROVISION_LIST=$(jq -r '.provision_list[]' "$CONFIG_FILE")

# 4. Run Main Engine
export GITHUB_USER
export GITHUB_TOKEN=$GITHUB_PAT
sudo -E bash /opt/Hyperion/provisioner/hyperion-engine.sh $CONFIG_FILE

# 5. Run Kustomization Engine
sudo -E bash "$KUSTOMIZATION_ENGINE_PATH" "${PRIVATE_CONFIG_DIR}/config-$(hostname).json"

# 7. Custom Configurations
echo "  ---------> Applying User Component Configurations <---------  "
sudo -E bash /usr/local/bin/component-configs.sh

# 8. Bootstrap Flux
echo "--> Handing off control to FluxCD..."
export GITHUB_TOKEN=$GITHUB_PAT
flux bootstrap github \
  --owner="$GITHUB_USER" \
  --repository=Hyperion-Config \
  --branch=main \
  --path=./clusters/$(hostname) \
  --personal

echo "--> GitOps engine is now online and managing your cluster."