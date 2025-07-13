#!/bin/bash
#
# input-git.sh 
# Separating the Git Login logic for future


set -e


echo "  ---------> Please provide your GitHub credentials to clone your private config repository."
read -p "Enter your GitHub Username: " GITHUB_USER
read -s -p "Enter your GitHub Personal Access Token (PAT): " GITHUB_PAT
echo

echo "  ---------> Cloning repositories <---------  "
rm -rf /etc/hyperion
mkdir -p /etc/hyperion
git clone "https://_:${GITHUB_PAT}@github.com/${GITHUB_USER}/Hyperion-config.git" /etc/hyperion/config

echo "  ---------> Git Connection Made Installing Custom Deployment <---------  "


export GITHUB_USER
export GITHUB_TOKEN=$GITHUB_PAT
sudo -E bash /opt/Hyperion/provisioner/hyperion-engine.sh